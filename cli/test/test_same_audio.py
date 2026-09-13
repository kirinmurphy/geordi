#!/usr/bin/env python3
"""Same-audio detection unit tests (wav_data_chunk + same_audio_groups).

Covers the stage-3 'same audio, different tags' classifier: WAV files
whose audio data chunk is byte-identical but whose container (metadata
chunks) differs are grouped for review; byte-identical files, different
audio, non-WAVs, and non-WAV-container files are not.
"""

import os
import struct
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


def make_wav(path, samples, list_info=b"INFOICRD\x05\x00\x00\x002010\x00"):
    """Write a minimal RIFF WAVE file: fmt + LIST + data.
    Odd-sized chunk payloads get the standard NUL pad byte (real files
    comply; the parser word-aligns accordingly)."""
    fmt = struct.pack("<HHIIHH", 1, 2, 44100, 176400, 4, 16)
    data = b"\x00\x00\x00\x00" * samples
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"LIST" + struct.pack("<I", len(list_info)) + list_info
    if len(list_info) & 1:
        chunks += b"\x00"
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE"
                + chunks)


class TestWavDataChunk(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-sameaudio-")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.td, ignore_errors=True)

    def _wav(self, name, samples=100, list_info=None):
        p = os.path.join(self.td, name)
        make_wav(p, samples, list_info or b"INFOICRD\x05\x00\x00\x002010\x00")
        return p

    def test_parses_and_hashes_payload(self):
        p = self._wav("a.wav")
        info = fdf.wav_data_chunk(p)
        self.assertIsNotNone(info)
        dsize, dhash = info
        self.assertEqual(dsize, 400)  # 100 samples x 4 bytes

    def test_same_audio_different_tags_same_hash(self):
        a = self._wav("a.wav", list_info=b"INFOICRD\x05\x00\x00\x002010\x00")
        b = self._wav("b.wav", list_info=b"INFOZ" + b"q" * 100)
        self.assertEqual(fdf.wav_data_chunk(a)[1],
                         fdf.wav_data_chunk(b)[1])

    def test_different_audio_different_hash(self):
        a = self._wav("a.wav", samples=100)
        b = self._wav("b.wav", samples=101)
        self.assertNotEqual(fdf.wav_data_chunk(a)[1],
                            fdf.wav_data_chunk(b)[1])

    def test_non_wav_returns_none(self):
        p = os.path.join(self.td, "x.txt")
        with open(p, "wb") as f:
            f.write(b"RIFFnot really")
        self.assertIsNone(fdf.wav_data_chunk(p))

    def test_truncated_returns_none(self):
        p = os.path.join(self.td, "t.wav")
        with open(p, "wb") as f:
            f.write(b"RIFF\x10\x00\x00\x00WAVE")
        self.assertIsNone(fdf.wav_data_chunk(p))


class TestSameAudioGroups(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-sameaudio-")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.td, ignore_errors=True)

    def _pair(self, d1, d2, name, samples, info1=None, info2=None):
        for d, info in ((d1, info1), (d2, info2)):
            os.makedirs(os.path.join(self.td, d), exist_ok=True)
            make_wav(os.path.join(self.td, d, name), samples,
                     info or b"INFOICRD\x05\x00\x00\x002010\x00")

    def test_same_audio_diff_tags_grouped(self):
        self._pair("a", "b", "track.wav", 100,
                   info1=b"INFOICRD\x05\x00\x00\x002010\x00",
                   info2=b"INFOZ" + b"q" * 100)
        groups = fdf.same_audio_groups(fdf.collect_files(self.td))
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0]), 2)

    def test_byte_identical_excluded(self):
        # identical full bytes -> byte-cluster territory, not this stage
        self._pair("a", "b", "track.wav", 100)
        groups = fdf.same_audio_groups(fdf.collect_files(self.td))
        self.assertEqual(groups, [])

    def test_different_audio_not_grouped(self):
        self._pair("a", "b", "track.wav", 100)
        self._pair("c", "d", "track.wav", 101)  # different names collide?
        # rebuild: same name, different lengths in different dirs
        make_wav(os.path.join(self.td, "a", "other.wav"), 100)
        make_wav(os.path.join(self.td, "b", "other.wav"), 101)
        groups = fdf.same_audio_groups(fdf.collect_files(self.td))
        self.assertEqual(groups, [])

    def test_non_wav_ignored(self):
        os.makedirs(os.path.join(self.td, "a"))
        os.makedirs(os.path.join(self.td, "b"))
        for d in ("a", "b"):
            with open(os.path.join(self.td, d, "song.mp3"), "wb") as f:
                f.write(b"z" * 500)
        self.assertEqual(
            fdf.same_audio_groups(fdf.collect_files(self.td)), [])

    def test_different_names_same_hash_separate_groups(self):
        # same audio under two names -> NOT a same-filename group
        make_wav(os.path.join(self.td, "x.wav"), 100,
                 b"INFOICRD\x05\x00\x00\x002010\x00")
        make_wav(os.path.join(self.td, "y.wav"), 100,
                 b"INFOZ" + b"q" * 100)
        groups = fdf.same_audio_groups(fdf.collect_files(self.td))
        self.assertEqual(groups, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
