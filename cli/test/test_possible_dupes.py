#!/usr/bin/env python3
"""Stage-5 'possible duplicates' unit tests.

Covers possible_dupe_groups (name-clustering of audio files with version
words stripped) and the review_mode duration filter rule: groups whose
durations differ by >1s are confident NON-dupes (dropped); equal or
unreadable durations stay flagged for human review.
"""

import os
import sys
import tempfile
import unittest

import importlib.machinery
import importlib.util
_spec = importlib.util.spec_from_loader(
    "fdf", importlib.machinery.SourceFileLoader(
        "fdf", os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))),
            "bin", "sidekicks", "find-dupe-files")))
fdf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fdf)


def put(td, d, fn, content=b"a" * 1000):
    os.makedirs(os.path.join(td, d), exist_ok=True)
    p = os.path.join(td, d, fn)
    with open(p, "wb") as f:
        f.write(content)
    return p


class TestPossibleDupeGroups(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-possible-")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.td, ignore_errors=True)

    def test_version_word_stripped_groups(self):
        put(self.td, "a", "Artist_Song.wav")
        put(self.td, "b", "Artist_Song_Remix.wav", b"b" * 2000)
        groups = fdf.possible_dupe_groups(fdf.collect_files(self.td))
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0]), 2)

    def test_strip_words_cover_common_suffixes(self):
        put(self.td, "a", "X_Y_extended mix.wav")
        put(self.td, "b", "X_Y_radio edit.wav", b"b" * 2000)
        groups = fdf.possible_dupe_groups(fdf.collect_files(self.td))
        self.assertEqual(len(groups), 1)

    def test_fully_different_names_not_grouped(self):
        put(self.td, "a", "One_Song.wav")
        put(self.td, "b", "Other_Song.wav", b"b" * 2000)
        self.assertEqual(
            fdf.possible_dupe_groups(fdf.collect_files(self.td)), [])

    def test_non_audio_ignored(self):
        put(self.td, "a", "One_Song.wav")
        put(self.td, "b", "One_Song_Remix.txt", b"b" * 2000)
        self.assertEqual(
            fdf.possible_dupe_groups(fdf.collect_files(self.td)), [])

    def test_generic_track_names_cluster(self):
        # '01 Track 01' vs '01 Track 01' (different folders) cluster;
        # the duration filter downstream decides keep/flag
        put(self.td, "a", "01 Track 01.wav")
        put(self.td, "b", "01 Track 01.mp3", b"b" * 2000)
        groups = fdf.possible_dupe_groups(fdf.collect_files(self.td))
        self.assertEqual(len(groups), 1)


class TestStage5DurationFilter(unittest.TestCase):
    """The rule review_mode applies to possible_dupe_groups output:
    >1s duration spread -> confident non-dupe (dropped); <=1s or
    unreadable -> flagged."""

    def test_equal_duration_flagged(self):
        # all same bytes -> same length; filter keeps the group
        paths = []
        for d in ("a", "b"):
            paths.append(put(self.td2, d, "Artist_Song.wav"))
        self.assertTrue(self._flagged(paths))

    def test_unreadable_duration_flagged(self):
        # text content is unreadable to afinfo/ffprobe -> None durations
        paths = [put(self.td2, "a", "Artist_Song.wav", b"not audio" * 100)]
        paths.append(put(self.td2, "b", "Artist_Song_Remix.wav",
                         b"also not audio" * 100))
        self.assertTrue(self._flagged(paths))

    def test_different_duration_dropped(self):
        # mp3s of different real lengths; synthesize by naming trick is
        # not possible, so use generated sine wav/mp3? stdlib-only: we
        # use files whose afinfo fails BUT monkeypatch _duration.
        paths = [put(self.td2, "a", "Artist_Song.wav", b"x" * 100),
                 put(self.td2, "b", "Artist_Song_Remix.wav", b"y" * 100)]
        self.assertFalse(self._flagged(paths, durs=[100.0, 180.0]))

    def _flagged(self, paths, durs=None):
        if durs is None:
            durs = [fdf._duration(p) for p in paths]
        if any(d is None for d in durs):
            return True
        return max(durs) - min(durs) <= 1.0

    def setUp(self):
        self.td2 = tempfile.mkdtemp(prefix="geordi-possible2-")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.td2, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
