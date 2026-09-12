#!/usr/bin/env python3
"""Stage 2 (copy-suffix) unit tests — pure logic, no pty needed.

Covers split_copy_suffix and the stage-2 classification rule:
a byte-identical sibling with the BARE stem name must exist for a
suffixed file to be proposed for deletion.
"""

import os
import sys
import unittest

# load the sidekick (no .py extension) as a module
import importlib.machinery
import importlib.util
_spec = importlib.util.spec_from_loader(
    "fdf", importlib.machinery.SourceFileLoader(
        "fdf", os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))),
            "bin", "sidekicks", "find-dupe-files")))
fdf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fdf)

split_copy_suffix = fdf.split_copy_suffix


class TestSplitCopySuffix(unittest.TestCase):

    def test_numeric_suffixes(self):
        self.assertEqual(split_copy_suffix("detroitything 2.wav"),
                         ("detroitything", ".wav"))
        self.assertEqual(split_copy_suffix("SundayMorning 3.wav"),
                         ("SundayMorning", ".wav"))
        self.assertEqual(split_copy_suffix("02 Track 02 2.wav"),
                         ("02 Track 02", ".wav"))

    def test_copy_suffixes(self):
        self.assertEqual(split_copy_suffix("song copy.wav"),
                         ("song", ".wav"))
        self.assertEqual(split_copy_suffix("song copy 2.wav"),
                         ("song", ".wav"))
        self.assertEqual(split_copy_suffix("Song COPY 3.wav"),
                         ("Song", ".wav"))

    def test_non_copies(self):
        self.assertIsNone(split_copy_suffix("1999.wav"))
        self.assertIsNone(split_copy_suffix("Blade Runner.wav"))
        self.assertIsNone(split_copy_suffix("01 Fade Away.wav"))


class TestStage2Classification(unittest.TestCase):
    """The rule: suffixed member is deletable only if a bare-named,
    byte-identical sibling exists. Built on fdf.byte_clusters."""

    def _cluster(self, td, names, content=b"x"):
        paths = []
        for d, fn in names:
            os.makedirs(os.path.join(td, d), exist_ok=True)
            p = os.path.join(td, d, fn)
            with open(p, "wb") as f:
                f.write(content)
            paths.append(p)
        return paths

    def test_suffixed_copy_flagged_only_with_bare_sibling(self):
        td = os.path.join(self.td, "case1")
        # bare original + ' 2' copy -> copy flagged
        self._cluster(td, [("a", "song.wav"), ("b", "song 2.wav")])
        # suffixed WITHOUT any bare sibling (all copies) -> NOT flagged
        self._cluster(td, [("a", "other 2.wav"), ("b", "other 3.wav")],
                      content=b"y")
        clusters = fdf.byte_clusters(fdf.collect_files(td))
        flagged = set()
        for c in clusters:
            by_stem = {}
            for p in c:
                s = split_copy_suffix(os.path.basename(p))
                if s:
                    by_stem.setdefault((s[0], s[1]), []).append(p)
            bare = {p for p in c
                    if not split_copy_suffix(os.path.basename(p))}
            for (stem, ext), ps in by_stem.items():
                if any(os.path.splitext(os.path.basename(p))[0] == stem
                       and fdf.ext_of(p) == ext for p in bare):
                    flagged.update(ps)
        self.assertIn(os.path.join(td, "b", "song 2.wav"), flagged)
        self.assertNotIn(os.path.join(td, "a", "other 2.wav"), flagged)
        self.assertNotIn(os.path.join(td, "b", "other 3.wav"), flagged)
        # bare originals never flagged
        self.assertNotIn(os.path.join(td, "a", "song.wav"), flagged)

    def setUp(self):
        import tempfile
        self.td = tempfile.mkdtemp(prefix="geordi-stage2-")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.td, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
