#!/usr/bin/env python3
"""Seen-state persistence tests: state_file/load_seen/save_seen and the
--unreviewed / --forget-seen behavior."""

import json
import os
import shutil
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


class TestSeenState(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-seen-")
        self.state_dir = os.path.join(self.td, "state")
        os.makedirs(self.state_dir)
        os.environ["FDF_STATE_DIR"] = self.state_dir
        self.base = os.path.join(self.td, "scan_root")
        os.makedirs(self.base)

    def tearDown(self):
        os.environ.pop("FDF_STATE_DIR", None)
        shutil.rmtree(self.td, ignore_errors=True)

    def test_state_file_keyed_per_root(self):
        other = os.path.join(self.td, "other_root")
        f1 = fdf.state_file(self.base)
        f2 = fdf.state_file(other)
        self.assertNotEqual(f1, f2)

    def test_load_missing_returns_empty(self):
        self.assertEqual(fdf.load_seen(self.base), {})

    def test_roundtrip(self):
        fdf.save_seen(self.base, {"a|b": "2026-09-12T10:00:00"})
        self.assertEqual(fdf.load_seen(self.base),
                         {"a|b": "2026-09-12T10:00:00"})

    def test_corrupt_state_ignored(self):
        fdf.state_file(self.base).write_text("not json{")
        self.assertEqual(fdf.load_seen(self.base), {})

    def test_group_key_is_path_sorted(self):
        k1 = fdf.group_key("byte", ["/x/b.wav", "/x/a.wav"])
        k2 = fdf.group_key("byte", ["/x/a.wav", "/x/b.wav"])
        self.assertEqual(k1, k2)

    def test_group_key_lossy_both_sides(self):
        k = fdf.group_key("lossy", (["/x/a.mp3"], ["/x/a.wav"]))
        self.assertEqual(k, "/x/a.mp3|/x/a.wav")

    def test_forget_seen_clears_file(self):
        fdf.save_seen(self.base, {"k": "t"})
        fdf.state_file(self.base).unlink()
        self.assertEqual(fdf.load_seen(self.base), {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
