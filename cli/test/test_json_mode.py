#!/usr/bin/env python3
"""--json output mode tests (the desktop seam).

Contract (plan: desktop-dupe-management-and-bundling.md): one JSON document
on stdout, schema_version-pinned, groups with stable group_keys, per-file
path/size/mtime. State-free — never reads or writes seen-state — and stdout
carries NOTHING but JSON (progress goes to stderr), so the GUI consumer can
parse it blind. A golden-file test fails on any silent shape change.
"""

import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SIDEKICK = REPO / "cli/bin/sidekicks/find-dupe-files"


def make_wav(path, samples, list_info=b"INFOICRD\x05\x00\x00\x002010\x00"):
    """Minimal RIFF WAVE: fmt + LIST + data (mirrors test_same_audio)."""
    fmt = struct.pack("<HHIIHH", 1, 2, 44100, 176400, 4, 16)
    data = b"\x00\x00\x00\x00" * samples
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"LIST" + struct.pack("<I", len(list_info)) + list_info
    if len(list_info) & 1:
        chunks += b"\x00"
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


class JsonModeTests(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="geordi-json-")
        self.addCleanup(shutil.rmtree, self.td, ignore_errors=True)
        env = dict(os.environ, FDF_STATE_DIR=os.path.join(self.td, "state"))
        self.env = env
        self.state_dir = Path(self.td) / "state"

    def run_json(self, *args):
        return subprocess.run(
            [sys.executable, str(SIDEKICK), self.td, "--json", *args],
            capture_output=True, text=True, timeout=60, env=self.env)

    def scan(self, *args):
        result = self.run_json(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)  # raises if stdout isn't pure JSON

    def test_stdout_is_pure_json_and_document_shape(self):
        Path(self.td, "a.txt").write_bytes(b"x" * 100)
        Path(self.td, "a copy.txt").write_bytes(b"x" * 100)
        doc = self.scan()
        self.assertEqual(doc["schema_version"], 1)
        self.assertEqual(doc["scan_root"], self.td)
        self.assertIn("generated", doc)
        self.assertEqual(doc["group_count"], len(doc["groups"]))

    def test_byte_identical_tier_with_stable_group_key(self):
        Path(self.td, "song.mp3").write_bytes(b"x" * 100)
        Path(self.td, "song copy.mp3").write_bytes(b"x" * 100)
        Path(self.td, "other.mp3").write_bytes(b"y" * 100)
        doc = self.scan()
        byte_groups = [g for g in doc["groups"] if g["tier"] == "byte-identical"]
        self.assertEqual(len(byte_groups), 1)
        group = byte_groups[0]
        paths = sorted(m["path"] for m in group["files"])
        self.assertEqual(group["group_key"], "|".join(paths))
        self.assertEqual(group["count"], 2)
        for member in group["files"]:
            self.assertEqual(member["size"], 100)
            self.assertIsInstance(member["mtime"], int)
            self.assertIn("temp", member)
        # deterministic across runs
        again = self.scan()
        self.assertEqual(
            [g["group_key"] for g in again["groups"] if g["tier"] == "byte-identical"],
            [group["group_key"]])

    def test_same_audio_payload_tier(self):
        """Same name (different dirs), identical audio payload, different
        metadata chunks — the same_audio_groups fixture from test_same_audio."""
        for d, info in (("v1", b"INFOICRD\x05\x00\x00\x002010\x00"),
                        ("v2", b"INFOZ" + b"q" * 100)):
            os.makedirs(os.path.join(self.td, d))
            make_wav(os.path.join(self.td, d, "track.wav"), 100, info)
        doc = self.scan()
        group = next(g for g in doc["groups"] if g["tier"] == "same-audio-payload")
        self.assertEqual(len(group["files"]), 2)
        self.assertTrue(all(m["path"].endswith("track.wav") for m in group["files"]))

    def test_hidden_and_empty_files_never_grouped(self):
        Path(self.td, ".hidden").write_bytes(b"x" * 100)
        Path(self.td, "empty.txt").write_bytes(b"")
        doc = self.scan()
        self.assertEqual(doc["groups"], [])

    def test_state_free_never_writes_seen_state(self):
        Path(self.td, "a.txt").write_bytes(b"x" * 100)
        Path(self.td, "a copy.txt").write_bytes(b"x" * 100)
        self.scan()
        self.scan()
        self.assertFalse(self.state_dir.exists(),
                         "--json must not create the seen-state directory")

    def test_progress_goes_to_stderr_not_stdout(self):
        make_wav(os.path.join(self.td, "big.wav"), 50)
        make_wav(os.path.join(self.td, "big2.wav"), 50)
        result = self.run_json()
        self.assertEqual(result.returncode, 0, result.stderr)
        json.loads(result.stdout)  # would fail on any interleaved progress text
        doc = json.loads(result.stdout)
        self.assertEqual(doc["group_count"], len(doc["groups"]))

    def test_golden_document(self):
        """Any change to the emitted shape must bump schema_version and
        update this golden file deliberately."""
        Path(self.td, "t.wav").write_bytes(b"a" * 64)
        Path(self.td, "t copy.wav").write_bytes(b"a" * 64)
        doc = self.scan()
        golden = {
            "schema_version": 1,
            "scan_root": self.td,
            "group_count": 1,
            "tiers": [g["tier"] for g in doc["groups"]],
            "keys": [g["group_key"] for g in doc["groups"]],
            "file_fields": sorted(doc["groups"][0]["files"][0].keys()),
        }
        self.assertEqual(golden, {
            "schema_version": doc["schema_version"],
            "scan_root": doc["scan_root"],
            "group_count": doc["group_count"],
            "tiers": ["byte-identical"],
            "keys": ["|".join(sorted([
                os.path.join(self.td, "t copy.wav"),
                os.path.join(self.td, "t.wav")]))],
            "file_fields": ["mtime", "path", "size", "temp"],
        })


if __name__ == "__main__":
    unittest.main()
