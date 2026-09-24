#!/usr/bin/env python3
r"""Push addon edits made in this project back to the addon's own repository.

The mirror of tools/pull_addons.py. For each addon it copies addons/<name>/ over a clone of that
addon's repository, and if anything changed, commits it there and pushes to the ref the manifest
names. addons/ is git-ignored here, so this project's own history only ever records the new commit
in tools/addons.lock.json.

    python tools/push_addons.py -m "add the sitting animations"          every addon that differs
    python tools/push_addons.py 3d_player_controller -m "..."            only this one
    python tools/push_addons.py --dry-run                                what differs, and how
    python tools/push_addons.py -m "..." --no-push                       commit upstream, do not push

Always run with --dry-run first. A push here publishes to a repository other projects consume, so
an addon is refused, and the exit code is 1, when its copy was pulled at an older commit than origin
holds now (pull first, or the push would revert what landed upstream since), when its clone under
C:\GitHub has uncommitted work or commits origin does not, or when anything fails. A dry run exits 1
on the same and also when a copy differs, which is what the pre-push hook stops on. It compares in
.addon_cache/ and only fetches in the clones under C:\GitHub, never checking out or merging there.
"""

from __future__ import annotations

import argparse
import sys

from addon_common import (
    EXCLUDED_TOP_LEVEL,
    ROOT,
    addon_source,
    local_checkout,
    load_lock,
    is_third_party,
    load_manifest,
    load_pulled,
    mirror,
    run,
    save_lock,
    save_pulled,
    sync_cache,
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Send addon edits upstream")
    parser.add_argument("names", nargs="*", help="Only these addons (default: all that differ)")
    parser.add_argument("-m", "--message", help="Commit message used in each addon repository")
    parser.add_argument("--dry-run", action="store_true", help="Report, change nothing")
    parser.add_argument("--no-push", action="store_true", help="Commit upstream but do not push")
    args = parser.parse_args(argv)

    if not args.dry_run and not args.message:
        sys.exit("A commit message is required: -m \"what changed\"  (or use --dry-run)")

    addons = load_manifest()
    if args.names:
        wanted = set(args.names)
        unknown = wanted - {a["name"] for a in addons}
        if unknown:
            sys.exit(f"Not in the manifest: {', '.join(sorted(unknown))}")
        addons = [a for a in addons if a["name"] in wanted]

    lock = load_lock()
    pulled_at = load_pulled()
    pushed = []
    failed = False  # something was refused or broke, so a push of this project has to wait for it
    differs = False

    print(f"Project:  {ROOT}")
    print(f"Addons:   {len(addons)}")
    print()

    for addon in addons:
        name = addon["name"]
        source = ROOT / "addons" / name

        if not source.exists():
            print(f"{name:<28} not vendored here, skipped")
            continue

        # Other people's work is pinned to a release and only ever pulled; an edit made here has
        # nowhere to go but upstream's issue tracker, so say so rather than trying to push it.
        if is_third_party(addon):
            print(f"{name:<28} third party, never pushed")
            continue

        branch = addon["ref"]

        # A push goes through the clone beside this project, so the change lands in the copy that is
        # worked in rather than only in a hidden cache that leaves it behind its own origin. Until the
        # push itself that clone is only read and fetched: a dry run compares in the cache, so the
        # pre-push hook never switches the branch of a clone somebody is working in.
        local = local_checkout(addon)
        try:
            ahead = 0
            if local:
                existing = run(["git", "status", "--porcelain", "--ignore-submodules=all"], cwd=local)
                if existing:
                    print(f"{name:<28} SKIPPED: {local} has {len(existing.splitlines())} uncommitted "
                          f"change(s) of its own")
                    print(f"{'':<28} commit or stash them there first, so nothing of yours is buried")
                    failed = True
                    continue
                run(["git", "fetch", "--quiet", "origin", branch], cwd=local)
                ahead = int(run(["git", "rev-list", "--count", f"origin/{branch}..refs/heads/{branch}"],
                                cwd=local, check=False) or 0)
            cache = local if local and not args.dry_run else sync_cache(addon)
            upstream = run(["git", "rev-parse", f"origin/{branch}"], cwd=cache)
        except RuntimeError as exc:
            print(f"{name:<28} FAILED  {exc}")
            failed = True
            continue
        where = "local clone" if cache == local else "cache"

        if ahead:
            print(f"{name:<28} AHEAD: {branch} in {local} has {ahead} commit(s) origin does not")
            print(f"{'':<28} push or drop them there first, so they do not go out under this message")
            failed = True
            continue

        # Copying this project's copy over a newer origin would revert whatever landed there since it
        # was pulled (gta or tcps pushing to controls, say) and publish the revert. So a push only
        # ever goes on top of the very commit this copy came from: the one this machine recorded
        # (load_pulled), since a `git pull` of this project moves the lock but not the copy.
        pulled = pulled_at.get(name) or lock.get(name, {}).get("commit", "")
        if pulled != upstream:
            print(f"{name:<28} BEHIND: origin/{branch} is at {upstream[:7]}, this copy was pulled at "
                  f"{pulled[:7] or 'no recorded commit'}")
            print(f"{'':<28} pull first: python tools/pull_addons.py {name}")
            failed = True
            continue

        try:
            if cache == local:
                run(["git", "checkout", "--quiet", branch], cwd=cache)
                run(["git", "merge", "--ff-only", "--quiet", f"origin/{branch}"], cwd=cache)
            else:
                run(["git", "checkout", "--quiet", "--force", "-B", branch, f"origin/{branch}"], cwd=cache)
        except RuntimeError as exc:
            print(f"{name:<28} FAILED  cannot bring {cache} up to date: {exc}")
            failed = True
            continue

        # Copy this project's copy over the clone, then let git say what actually differs. The
        # repository's own scaffolding is protected: it is not vendored here, so its absence from
        # the source must never be read as a deletion.
        mirror(source, addon_source(cache, name), dry_run=False, protect=set(EXCLUDED_TOP_LEVEL))

        status = run(["git", "status", "--porcelain"], cwd=cache)
        if not status:
            print(f"{name:<28} no local changes")
            continue

        lines = status.splitlines()
        print(f"{name:<28} {len(lines)} file(s) differ from {branch} ({where})")
        for line in lines[:10]:
            print(f"{'':<28}   {line}")
        if len(lines) > 10:
            print(f"{'':<28}   ... and {len(lines) - 10} more")

        if args.dry_run:
            differs = True
            # Leave the cache as upstream so a dry run has no lasting effect.
            run(["git", "reset", "--quiet", "--hard", "HEAD"], cwd=cache)
            # Not fatal: a directory held open by another process cannot be removed, and the reset
            # above has already put every tracked file back.
            run(["git", "clean", "-qfd"], cwd=cache, check=False)
            continue

        run(["git", "add", "-A"], cwd=cache)
        run(["git", "commit", "-q", "-m", args.message], cwd=cache)
        commit = run(["git", "rev-parse", "HEAD"], cwd=cache)

        if args.no_push:
            print(f"{'':<28} committed {commit[:7]}, not pushed")
        else:
            try:
                run(["git", "push", "--quiet", "origin", branch], cwd=cache)
            except RuntimeError as exc:
                print(f"{'':<28} commit made but PUSH FAILED: {exc}")
                failed = True
                continue
            print(f"{'':<28} pushed {commit[:7]} to {branch}")

        pushed.append(name)
        pulled_at[name] = commit  # addons/<name> here is exactly what was just committed
        lock[name] = {
            "repo": addon["repo"],
            "ref": branch,
            "commit": commit,
            "subject": args.message,
            "pulled": lock.get(name, {}).get("pulled", ""),
        }

    print()

    if args.dry_run:
        print("Dry run, nothing was committed or pushed.")
        return 1 if failed or differs else 0

    if pushed:
        save_lock(lock)
        save_pulled(pulled_at)
        print(f"{len(pushed)} addon(s) sent upstream: {', '.join(pushed)}")
        print("The lock file now records the new commits; commit tools/addons.lock.json with your changes.")
    else:
        print("Nothing to send upstream.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
