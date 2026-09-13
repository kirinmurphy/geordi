#!/usr/bin/env python3
"""Tests for display helpers (fmt_dur, trunc_mid) and audio payload
extraction for mp3/flac (mp3_audio_payload, flac_audio_payload)."""

import os
import shutil
import struct
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


class TestFmtDur(unittest.TestCase):

    def test_seconds_only(self):
        self.assertEqual(fdf.fmt_dur(42.3), "42.3s")

    def test_minutes(self):
        self.assertEqual(fdf.fmt_dur(444), "7m24s")
        self.assertEqual(fdf.fmt_dur(709.13), "11m49s")

    def test_hours(self):
        self.assertEqual(fdf.fmt_dur(3700.5), "1h01m40.5s")
        self.assertEqual(fdf.fmt_dur(3600), "1h00m00.0s")

    def test_none(self):
        self.assertEqual(fdf.fmt_dur(None), "unknown")


class TestTruncMid(unittest.TestCase):

    def test_short_untouched(self):
        self.assertEqual(fdf.trunc_mid("short.wav"), "short.wav")

    def test_max_30(self):
        s = "a" * 100
        self.assertEqual(len(fdf.trunc_mid(s)), 30)

    def test_keeps_head_and_tail(self):
        s = "03 - Shriekback - My Spine Is The Bassline (12'' Edit).flac"
        t = fdf.trunc_mid(s)
        self.assertTrue(t.startswith("03 - Shriekback") or
                        t.startswith("03 - Sh"))
        self.assertTrue(t.endswith(".flac"))
        self.assertIn("...", t)

    def test_custom_maxlen(self):
        self.assertEqual(len(fdf.trunc_mid("x" * 100, 20)), 20)


def _make_mp3(path, frames=b"\xff\xfb\x90\x64" + b"\x00" * 400,
              id3v2=None, id3v1=False):
    with open(path, "wb") as f:
        if id3v2:
            # 10-byte header + synchsafe size + body
            body = b"T" * 100
            n = len(body)
            ss = bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F,
                        (n >> 7) & 0x7F, n & 0x7F])
            f.write(b"ID3\x03\x00\x00" + ss + body)
        f.write(frames)
        if id3v1:
            f.write(b"TAG" + b"v" * 125)


def _make_flac(path, metadata=b"\x80\x00\x00\x22" + b"\x00" * 34):
    with open(path, "wb") as f:
        f.write(b"fLaC")
        f.write(metadata)  # one block, 0x80 = last-block flag set
        f.write(b"FRAMES" + b"\x01" * 200)


class TestMp3Payload(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-mp3-")

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def test_same_frames_different_tags_match(self):
        a = os.path.join(self.td, "tagged.mp3")
        b = os.path.join(self.td, "bare.mp3")
        _make_mp3(a, id3v2=True, id3v1=True)
        _make_mp3(b)
        ia, ib = fdf.mp3_audio_payload(a), fdf.mp3_audio_payload(b)
        self.assertIsNotNone(ia)
        self.assertEqual(ia, ib)

    def test_different_frames_differ(self):
        a = os.path.join(self.td, "a.mp3")
        b = os.path.join(self.td, "b.mp3")
        _make_mp3(a)
        _make_mp3(b, frames=b"\xff\xfb\x90\x64" + b"\x00" * 401)
        self.assertNotEqual(fdf.mp3_audio_payload(a),
                            fdf.mp3_audio_payload(b))

    def test_not_mp3(self):
        p = os.path.join(self.td, "x.mp3")
        with open(p, "wb") as f:
            f.write(b"not an mp3 at all")
        self.assertIsNone(fdf.mp3_audio_payload(p))


class TestFlacPayload(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-flac-")

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def test_same_frames_different_metadata_match(self):
        a = os.path.join(self.td, "a.flac")
        b = os.path.join(self.td, "b.flac")
        _make_flac(a)
        _make_flac(b, metadata=b"\x80\x00\x00\x05" + b"Z" * 5)  # diff tags
        ia, ib = fdf.flac_audio_payload(a), fdf.flac_audio_payload(b)
        self.assertIsNotNone(ia)
        self.assertEqual(ia, ib)

    def test_not_flac(self):
        p = os.path.join(self.td, "x.flac")
        with open(p, "wb") as f:
            f.write(b"RIFFxxxx")
        self.assertIsNone(fdf.flac_audio_payload(p))


if __name__ == "__main__":
    unittest.main(verbosity=2)
