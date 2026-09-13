#!/usr/bin/env python3
"""Trash-default deletion tests: mac_trash + delete_files modes.

Default deletion now MOVES to the Trash (~/.Trash, override with
FDF_TRASH_DIR) with collision-safe naming; --hard-delete unlinks.
"""

import os
import shutil
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


class TestMacTrash(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-trash-")
        self.trash = os.path.join(self.td, "Trash")
        os.makedirs(self.trash)

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def _file(self, name, content=b"x" * 100):
        p = os.path.join(self.td, name)
        with open(p, "wb") as f:
            f.write(content)
        return p

    def test_moves_into_trash(self):
        p = self._file("song.wav")
        dest = fdf.mac_trash(p, trash_dir=self.trash)
        self.assertFalse(os.path.exists(p))
        self.assertTrue(os.path.isfile(dest))
        self.assertTrue(dest.startswith(self.trash))

    def test_collision_never_overwrites(self):
        p1 = self._file("song.wav", b"first")
        shutil.move(p1, os.path.join(self.trash, "song.wav"))
        p2 = self._file("song.wav", b"second")
        dest = fdf.mac_trash(p2, trash_dir=self.trash)
        self.assertEqual(os.path.basename(dest), "song 2.wav")
        with open(dest, "rb") as f:
            self.assertEqual(f.read(), b"second")
        # original trash occupant untouched
        with open(os.path.join(self.trash, "song.wav"), "rb") as f:
            self.assertEqual(f.read(), b"first")

    def test_double_collision_increments(self):
        for n in ("a.wav", "a 2.wav", "a 3.wav"):
            open(os.path.join(self.trash, n), "wb").close()
        p = self._file("a.wav")
        dest = fdf.mac_trash(p, trash_dir=self.trash)
        self.assertEqual(os.path.basename(dest), "a 4.wav")


class TestDeleteFilesModes(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-trash2-")
        self.trash = os.path.join(self.td, "Trash")
        os.makedirs(self.trash)
        os.environ["FDF_TRASH_DIR"] = self.trash

    def tearDown(self):
        os.environ.pop("FDF_TRASH_DIR", None)
        shutil.rmtree(self.td, ignore_errors=True)

    def _file(self, name, content=b"x" * 100):
        p = os.path.join(self.td, name)
        with open(p, "wb") as f:
            f.write(content)
        return p

    def test_default_is_trash(self):
        p = self._file("f.wav")
        ok, failed = fdf.delete_files([p], self.td)
        self.assertEqual((ok, failed), (1, 0))
        self.assertFalse(os.path.exists(p))
        self.assertTrue(os.path.exists(os.path.join(self.trash, "f.wav")))

    def test_hard_delete_unlinks(self):
        p = self._file("g.wav")
        ok, failed = fdf.delete_files([p], self.td, hard=True)
        self.assertEqual((ok, failed), (1, 0))
        self.assertFalse(os.path.exists(p))
        self.assertFalse(os.path.exists(os.path.join(self.trash, "g.wav")))

    def test_missing_file_is_idempotent_skip(self):
        p = os.path.join(self.td, "never.wav")
        ok, failed = fdf.delete_files([p], self.td)
        self.assertEqual((ok, failed), (0, 0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
