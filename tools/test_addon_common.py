#!/usr/bin/env python3
"""Tests for the addon tooling: Windows replace fragments, the pull's edit guard, and the push and pull
exit codes and refusals, the last driven end to end against throwaway git repositories.

Run with:  python -m unittest tools/test_addon_common.py

When pull_addons.py overwrites a DLL that a running program has loaded, an open Godot editor holding
a GDExtension for instance, Windows cannot delete the old file. It swaps the new one in and parks the
old one beside it, hidden, as ~<name>~RF<hex>.TMP. That file used to be mirrored into the addon's
clone by push_addons.py, where git saw an untracked file and the pre-push hook refused the push,
every time, until someone deleted it by hand. These tests hold the fix: a fragment is recognised, the
mirror ignores it on both sides, and the sweep removes what it can and reports what is still held.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import addon_common  # noqa: E402
import pull_addons  # noqa: E402
import push_addons  # noqa: E402
from addon_common import (  # noqa: E402
    _rmtree,
    is_replace_fragment,
    local_edits,
    mirror,
    sweep_replace_fragments,
)

FRAGMENT = "~libpure_doom.windows.template_debug.x86_64.dll~RF1c6eaf04.TMP"


class ReplaceFragmentName(unittest.TestCase):
    def test_the_name_windows_leaves_behind_is_recognised(self) -> None:
        self.assertTrue(is_replace_fragment(FRAGMENT))
        self.assertTrue(is_replace_fragment("~thing.dll~rfABCD1234.tmp"), "case does not matter")

    def test_ordinary_files_are_not(self) -> None:
        for name in ["libpure_doom.windows.template_debug.x86_64.dll", "~backup.tmp", "notes.TMP",
                     "~$word.docx", "RF.TMP", "plugin.cfg"]:
            self.assertFalse(is_replace_fragment(name), name)


class MirrorIgnoresFragments(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.source = base / "source"
        self.dest = base / "dest"
        (self.source / "bin").mkdir(parents=True)
        (self.dest / "bin").mkdir(parents=True)
        (self.source / "plugin.cfg").write_text("[plugin]\n")
        (self.source / "bin" / "lib.dll").write_bytes(b"new")
        (self.dest / "plugin.cfg").write_text("[plugin]\n")
        (self.dest / "bin" / "lib.dll").write_bytes(b"old")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_a_fragment_in_dest_is_neither_a_local_change_nor_deleted_work(self) -> None:
        fragment = self.dest / "bin" / FRAGMENT
        fragment.write_bytes(b"old copy windows could not delete")
        copied, removed = mirror(self.source, self.dest, dry_run=True)
        self.assertEqual(copied, 1, "only lib.dll differs")
        self.assertEqual(removed, [], "the fragment is not reported as work that would be lost")
        mirror(self.source, self.dest, dry_run=False)
        self.assertTrue(fragment.exists(), "and the mirror leaves it alone; the sweep is what clears it")
        self.assertEqual((self.dest / "bin" / "lib.dll").read_bytes(), b"new")

    def test_a_fragment_in_source_is_never_copied_into_a_repository(self) -> None:
        # this is the push direction: the project's vendored copy is the source, the clone the dest
        (self.source / "bin" / FRAGMENT).write_bytes(b"parked")
        copied, _removed = mirror(self.source, self.dest, dry_run=False)
        self.assertEqual(copied, 1)
        self.assertFalse((self.dest / "bin" / FRAGMENT).exists(), "nothing for git status to flag")


class SweepFragments(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "addon"
        (self.root / "bin").mkdir(parents=True)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_a_free_fragment_is_removed_and_a_held_one_is_reported(self) -> None:
        free = self.root / "bin" / FRAGMENT
        free.write_bytes(b"free")
        held_path = self.root / "bin" / "~other.dll~RFbeef0000.TMP"
        held_path.write_bytes(b"held")
        # holding a handle without delete sharing is what a loaded DLL amounts to on Windows
        handle = open(held_path, "rb")
        try:
            removed, held = sweep_replace_fragments(self.root)
        finally:
            handle.close()
        if os.name == "nt":
            self.assertEqual(removed, [free])
            self.assertEqual(held, [held_path], "the one still open is named, not failed on")
            self.assertTrue(held_path.exists())
        else:
            # A POSIX unlink of an open file succeeds, so both go and nothing is held. The held
            # assertion already said this; the removed one did not, and failed here every run.
            self.assertEqual(removed, sorted([free, held_path]))
            self.assertEqual(held, [])

    def test_ordinary_files_are_untouched(self) -> None:
        keep = self.root / "bin" / "lib.dll"
        keep.write_bytes(b"keep")
        removed, held = sweep_replace_fragments(self.root)
        self.assertEqual((removed, held), ([], []))
        self.assertTrue(keep.exists())


class LocalEdits(unittest.TestCase):
    """The check that stops a pull writing over work that was never pushed.

    mirror() copies whenever a file differs, which is how hand-tuned animation .tres files were lost
    twice: the pull counted them as "file(s) in" and said nothing about what it wrote over. Telling
    an edit made here from a change made upstream needs the commit the lock recorded to compare
    against, and local_edits is that comparison.
    """

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.root = Path(self._temp.name)
        self.source = self.root / "source"
        self.dest = self.root / "dest"

    def tearDown(self) -> None:
        self._temp.cleanup()

    def write(self, base: Path, relative: str, text: str) -> Path:
        path = base / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_an_untouched_copy_reports_nothing(self) -> None:
        self.write(self.source, "scripts/player.gd", "extends Node\n")
        self.write(self.dest, "scripts/player.gd", "extends Node\n")

        self.assertEqual(local_edits(self.source, self.dest), [])

    def test_a_file_changed_here_is_reported(self) -> None:
        self.write(self.source, "animations/Swimming.tres", "hips = 0.699\n")
        edited = self.write(self.dest, "animations/Swimming.tres", "hips = 1.099\n")

        self.assertEqual(local_edits(self.source, self.dest), [edited])

    def test_a_file_only_upstream_is_not_an_edit(self) -> None:
        # It is simply new, and mirror() brings it in; there is nothing here to lose.
        self.write(self.source, "scripts/new_feature.gd", "extends Node\n")

        self.assertEqual(local_edits(self.source, self.dest), [])

    def test_a_file_only_here_is_left_to_the_removal_guard(self) -> None:
        # mirror() already reports this one as a removal, so counting it twice would say it wrong.
        self.write(self.source, "scripts/player.gd", "extends Node\n")
        self.write(self.dest, "scripts/player.gd", "extends Node\n")
        self.write(self.dest, "scripts/mine.gd", "extends Node\n")

        self.assertEqual(local_edits(self.source, self.dest), [])

    def test_a_same_length_edit_is_still_caught(self) -> None:
        # A re-saved .tres often keeps its length exactly, which a size check alone would miss.
        self.write(self.source, "animations/Running.tres", "hips = 0.921\n")
        edited = self.write(self.dest, "animations/Running.tres", "hips = 0.821\n")

        self.assertEqual(local_edits(self.source, self.dest), [edited])

    def test_every_edit_under_a_directory_is_listed(self) -> None:
        for name in ["Swimming", "Running", "Sprint"]:
            self.write(self.source, f"animations/{name}.tres", "raw\n")
        first = self.write(self.dest, "animations/Swimming.tres", "tuned\n")
        self.write(self.dest, "animations/Running.tres", "raw\n")
        second = self.write(self.dest, "animations/Sprint.tres", "tuned\n")

        self.assertEqual(local_edits(self.source, self.dest), sorted([first, second]))


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class AddonRepositories(unittest.TestCase):
    """push_addons.py and pull_addons.py run for real against repositories made in a temporary folder.

    `remotes/widget.git` is the addon's origin, `other` is somebody else's clone of it (gta or tcps
    pushing to the same addon), and `project` vendors the addon under addons/widget/ the way this
    project does. A clone at `widget`, beside the project, is the one a push goes through when present.
    """

    NAME = "widget"

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.base = Path(self._temp.name)
        self.addCleanup(self._temp.cleanup)
        self.addCleanup(_rmtree, self.base)  # git leaves read-only objects that Windows will not delete

        # Git with an identity for the commits and nothing of this machine's own configuration.
        config = self.base / "gitconfig"
        config.write_text("[user]\n\tname = Test\n\temail = test@example.com\n")
        environment = mock.patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": str(config), "GIT_CONFIG_NOSYSTEM": "1"})
        environment.start()
        self.addCleanup(environment.stop)

        self.origin = self.base / "remotes" / "widget.git"
        self.origin.mkdir(parents=True)
        git(self.origin, "init", "--quiet", "--bare", "--initial-branch=main")
        self.other = self.base / "other"
        git(self.base, "clone", "--quiet", self.origin.as_uri(), str(self.other))
        git(self.other, "symbolic-ref", "HEAD", "refs/heads/main")
        self.commit_upstream("addons/widget/plugin.cfg", "[plugin]\n")

        self.project = self.base / "project"
        (self.project / "tools").mkdir(parents=True)
        self.addons = [{"name": self.NAME, "repo": self.origin.as_uri(), "ref": "main"}]
        self.write_manifest()
        for module, name, value in [
            (addon_common, "ROOT", self.project),
            (addon_common, "MANIFEST", self.project / "tools" / "addons.json"),
            (addon_common, "LOCKFILE", self.project / "tools" / "addons.lock.json"),
            (addon_common, "CACHE", self.project / ".addon_cache"),
            (pull_addons, "ROOT", self.project),
            (push_addons, "ROOT", self.project),
        ]:
            patch = mock.patch.object(module, name, value)
            patch.start()
            self.addCleanup(patch.stop)

        code, out = self.call(pull_addons.main)
        self.assertEqual(code, 0, out)
        self.vendored = self.project / "addons" / self.NAME
        self.assertTrue((self.vendored / "plugin.cfg").exists(), out)

    def write_manifest(self) -> None:
        (self.project / "tools" / "addons.json").write_text(json.dumps({"addons": self.addons}))

    def commit_upstream(self, relative: str, text: str) -> str:
        """Somebody else commits to the addon and pushes it."""
        path = self.other / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        git(self.other, "add", "-A")
        git(self.other, "commit", "--quiet", "-m", f"change {relative}")
        git(self.other, "push", "--quiet", "origin", "main")
        return git(self.other, "rev-parse", "HEAD")

    def origin_head(self) -> str:
        return git(self.origin, "rev-parse", "main")

    def origin_file(self, relative: str) -> str:
        return git(self.origin, "show", f"main:{relative}")

    def edit_here(self) -> None:
        (self.vendored / "plugin.cfg").write_text("[plugin]\nname=\"edited here\"\n")

    def call(self, main, *argv: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main(list(argv))
        return code, out.getvalue()

    def test_a_pull_that_changes_nothing_leaves_the_lock_alone(self) -> None:
        # Every pull used to stamp a fresh "pulled" time into the lock, leaving a clone dirty with nothing
        # worth committing; a pull that takes the same commit must not touch the file at all.
        lock = addon_common.load_lock()
        lock[self.NAME]["pulled"] = "2000-01-01T00:00:00Z"
        addon_common.save_lock(lock)
        before = (self.project / "tools" / "addons.lock.json").read_bytes()

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 0, out)
        self.assertIn("up to date", out)
        self.assertEqual((self.project / "tools" / "addons.lock.json").read_bytes(), before)

    def test_a_push_in_step_with_origin_goes_through(self) -> None:
        self.edit_here()

        code, out = self.call(push_addons.main, "-m", "edited here")

        self.assertEqual(code, 0, out)
        self.assertIn("edited here", self.origin_file("addons/widget/plugin.cfg"))
        lock = json.loads((self.project / "tools" / "addons.lock.json").read_text())
        self.assertEqual(lock[self.NAME]["commit"], self.origin_head(), "the lock records what was pushed")

    def test_a_push_from_a_copy_older_than_origin_is_refused(self) -> None:
        # H18: gta or tcps pushed since this project pulled. Copying the older copy over origin would
        # delete their file and publish the deletion; the push has to stop and ask for a pull.
        self.edit_here()
        theirs = self.commit_upstream("addons/widget/theirs.gd", "extends Node\n")

        code, out = self.call(push_addons.main, "-m", "edited here")

        self.assertEqual(code, 1, out)
        self.assertIn("BEHIND", out)
        self.assertIn("pull first", out)
        self.assertEqual(self.origin_head(), theirs, "nothing was pushed")
        self.assertEqual(self.origin_file("addons/widget/theirs.gd"), "extends Node", "their work stands")

    def test_a_dry_run_behind_origin_fails_too(self) -> None:
        self.commit_upstream("addons/widget/theirs.gd", "extends Node\n")

        code, out = self.call(push_addons.main, "--dry-run")

        self.assertEqual(code, 1, out)
        self.assertIn("BEHIND", out)

    def test_a_dry_run_exits_non_zero_when_a_copy_differs_and_zero_when_none_does(self) -> None:
        code, out = self.call(push_addons.main, "--dry-run")
        self.assertEqual(code, 0, out)

        self.edit_here()
        code, out = self.call(push_addons.main, "--dry-run")
        self.assertEqual(code, 1, out)
        self.assertIn("file(s) differ", out)

    def test_a_dry_run_never_checks_out_or_merges_in_the_clone_beside_the_project(self) -> None:
        # M35: the pre-push hook runs the dry run, and it used to check out main in the clones under
        # C:\GitHub, switching a branch somebody was working on.
        clone = self.base / self.NAME
        git(self.base, "clone", "--quiet", self.origin.as_uri(), str(clone))
        git(clone, "checkout", "--quiet", "-b", "feature")
        (clone / "addons" / "widget" / "feature.gd").write_text("extends Node\n")
        git(clone, "add", "-A")
        git(clone, "commit", "--quiet", "-m", "feature work")
        before = git(clone, "rev-parse", "HEAD")
        self.commit_upstream("addons/widget/theirs.gd", "extends Node\n")  # something a merge would take
        self.call(pull_addons.main)
        self.edit_here()

        code, out = self.call(push_addons.main, "--dry-run")

        self.assertEqual(code, 1, out)
        self.assertIn("file(s) differ", out)
        self.assertEqual(git(clone, "rev-parse", "--abbrev-ref", "HEAD"), "feature", "still on its own branch")
        self.assertEqual(git(clone, "rev-parse", "HEAD"), before, "and at its own commit")
        self.assertEqual(git(clone, "status", "--porcelain"), "", "with nothing written into it")
        self.assertNotEqual(git(clone, "rev-parse", "main"), self.origin_head(), "its main was not merged")

    def test_a_clone_beside_the_project_with_unpushed_commits_is_refused(self) -> None:
        clone = self.base / self.NAME
        git(self.base, "clone", "--quiet", self.origin.as_uri(), str(clone))
        (clone / "addons" / "widget" / "mine.gd").write_text("extends Node\n")
        git(clone, "add", "-A")
        git(clone, "commit", "--quiet", "-m", "not pushed yet")
        before = self.origin_head()
        self.edit_here()

        code, out = self.call(push_addons.main, "-m", "edited here")

        self.assertEqual(code, 1, out)
        self.assertIn("AHEAD", out)
        self.assertEqual(self.origin_head(), before, "neither commit went out")

    def test_a_clone_beside_the_project_is_where_a_push_lands(self) -> None:
        clone = self.base / self.NAME
        git(self.base, "clone", "--quiet", self.origin.as_uri(), str(clone))
        self.edit_here()

        code, out = self.call(push_addons.main, "-m", "edited here")

        self.assertEqual(code, 0, out)
        self.assertIn("local clone", out)
        self.assertEqual(git(clone, "rev-parse", "HEAD"), self.origin_head())

    def test_an_addon_that_cannot_be_fetched_fails_the_pull_and_the_push(self) -> None:
        # M34 and M35: a FAILED addon used to leave both scripts exiting 0, so CI carried on with a
        # partial addons/ and the hook let the push through.
        self.addons.append({"name": "missing", "repo": (self.base / "remotes" / "missing.git").as_uri(), "ref": "main"})
        self.write_manifest()

        code, out = self.call(pull_addons.main)
        self.assertEqual(code, 1, out)
        self.assertIn("FAILED", out)
        self.assertTrue((self.vendored / "plugin.cfg").exists(), "the addon that could be fetched still is")

        (self.project / "addons" / "missing").mkdir(parents=True)
        (self.project / "addons" / "missing" / "plugin.cfg").write_text("[plugin]\n")
        code, out = self.call(push_addons.main, "--dry-run")
        self.assertEqual(code, 1, out)
        self.assertIn("FAILED", out)

    def move_the_lock(self, commit: str) -> None:
        """What `git pull` of this project does once another machine has pulled the addon and pushed."""
        path = self.project / "tools" / "addons.lock.json"
        lock = json.loads(path.read_text())
        lock[self.NAME]["commit"] = commit
        path.write_text(json.dumps(lock))

    def pulled_record(self) -> str:
        """The commit this machine recorded mirroring addons/widget from."""
        return json.loads((self.project / ".addon_cache" / "pulled.json").read_text())[self.NAME]

    def test_a_lock_moved_by_a_project_pull_is_not_an_edit_here(self) -> None:
        # The lock is committed, so a `git pull` here moves it on while addons/ keeps the older copy.
        # The guard used to diff that copy against the lock, call the upstream change an edit made
        # here and stop, and only --force got past it, which would also have destroyed a real edit.
        pulled = self.origin_head()
        newer = self.commit_upstream("addons/widget/plugin.cfg", "[plugin]\nname=\"newer\"\n")
        self.move_the_lock(newer)
        self.assertEqual(self.pulled_record(), pulled, "this machine knows its copy is the older one")

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 0, out)
        self.assertNotIn("STOPPED", out)
        self.assertIn("newer", (self.vendored / "plugin.cfg").read_text())
        self.assertEqual(self.pulled_record(), newer)

    def test_an_edit_here_still_stops_a_pull_after_the_lock_moved(self) -> None:
        self.edit_here()
        self.move_the_lock(self.commit_upstream("addons/widget/theirs.gd", "extends Node\n"))

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 1, out)
        self.assertIn("STOPPED: 1 file(s) edited here", out)
        self.assertIn("edited here", (self.vendored / "plugin.cfg").read_text(), "the edit survives")

    def test_a_recorded_commit_missing_from_the_cache_falls_back_to_the_lock(self) -> None:
        (self.project / ".addon_cache" / "pulled.json").write_text(json.dumps({self.NAME: "0" * 40}))
        self.commit_upstream("addons/widget/plugin.cfg", "[plugin]\nname=\"newer\"\n")

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 0, out)
        self.assertIn("is not in .addon_cache/widget; comparing against the lock's", out)
        self.assertIn("newer", (self.vendored / "plugin.cfg").read_text())

    def test_a_push_records_its_commit_so_the_next_pull_diffs_against_it(self) -> None:
        # Otherwise the next pull diffs against the older pull, and a later upstream change to the
        # file pushed from here looks like an edit made here.
        self.edit_here()
        code, out = self.call(push_addons.main, "-m", "edited here")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.pulled_record(), self.origin_head())
        git(self.other, "pull", "--quiet", "origin", "main")
        self.commit_upstream("addons/widget/plugin.cfg", "[plugin]\nname=\"theirs\"\n")

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 0, out)
        self.assertNotIn("STOPPED", out)
        self.assertIn("theirs", (self.vendored / "plugin.cfg").read_text())

    def delete_upstream(self, relative: str) -> str:
        """Somebody else deletes a file from the addon and pushes it."""
        git(self.other, "rm", "--quiet", relative)
        git(self.other, "commit", "--quiet", "-m", f"delete {relative}")
        git(self.other, "push", "--quiet", "origin", "main")
        return git(self.other, "rev-parse", "HEAD")

    def pull_with_save_game_data(self) -> Path:
        """Pull a commit that has scripts/save_game_data.gd, so the copy here holds it."""
        self.commit_upstream("addons/widget/scripts/save_game_data.gd", "extends Node\n")
        code, out = self.call(pull_addons.main)
        self.assertEqual(code, 0, out)
        return self.vendored / "scripts" / "save_game_data.gd"

    def test_a_file_deleted_upstream_goes_quietly_after_the_lock_moved(self) -> None:
        # The live case: the copy came from a commit with save_game_data.gd, the next commit deleted
        # it, and a `git pull` moved the lock on. The removal guard called it local work and stopped.
        script = self.pull_with_save_game_data()
        self.move_the_lock(self.delete_upstream("addons/widget/scripts/save_game_data.gd"))

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 0, out)
        self.assertNotIn("STOPPED", out)
        self.assertFalse(script.exists(), "deleted here too, without --force")

    def test_a_file_that_was_never_upstream_still_stops_the_pull(self) -> None:
        # A .uid or .import Godot wrote beside the addon is in neither commit; it stays protected.
        script = self.pull_with_save_game_data()
        generated = script.with_name("save_game_data.gd.uid")
        generated.write_text("uid://b1234567890\n")
        self.move_the_lock(self.delete_upstream("addons/widget/scripts/save_game_data.gd"))

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 1, out)
        self.assertIn("STOPPED: 1 local file(s) are not upstream", out)
        self.assertTrue(generated.exists())

    def test_a_file_edited_here_and_deleted_upstream_still_stops_the_pull(self) -> None:
        script = self.pull_with_save_game_data()
        script.write_text("extends Node\n# tuned here\n")
        self.move_the_lock(self.delete_upstream("addons/widget/scripts/save_game_data.gd"))

        code, out = self.call(pull_addons.main)

        self.assertEqual(code, 1, out)
        self.assertIn("STOPPED: 1 file(s) edited here", out)
        self.assertIn("tuned here", script.read_text())

    def test_a_push_from_a_copy_older_than_a_moved_lock_is_refused(self) -> None:
        # The lock names origin's head only because `git pull` brought it in; the copy here is older,
        # and copying it over origin would delete their file and publish the deletion.
        self.edit_here()
        theirs = self.commit_upstream("addons/widget/theirs.gd", "extends Node\n")
        self.move_the_lock(theirs)

        code, out = self.call(push_addons.main, "-m", "edited here")

        self.assertEqual(code, 1, out)
        self.assertIn("BEHIND", out)
        self.assertEqual(self.origin_head(), theirs, "nothing was pushed")
        self.assertEqual(self.origin_file("addons/widget/theirs.gd"), "extends Node", "their work stands")


if __name__ == "__main__":
    unittest.main()
