#!/usr/bin/env python3
"""Tests for the check that stops a pull writing over addon work that was never pushed.

Run with:  python -m unittest tools/test_addon_common.py

mirror() copies whenever a file differs, which includes a file edited here and not yet sent
upstream. That is how hand-tuned animation .tres files were lost twice in the consuming project: the
pull counted them as "file(s) in" and said nothing about what it wrote over. Telling an edit made
here from a change made upstream needs the commit tools/addons.lock.json recorded to compare
against, and local_edits is that comparison.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from addon_common import local_edits  # noqa: E402


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


if __name__ == "__main__":
    unittest.main()
