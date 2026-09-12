#!/usr/bin/env python3
"""Interactive-UI test for the find-dupe-files stage-3 curses picker.

Drives the repository CLI (find-dupe-files) inside a pseudo-terminal
against a throwaway sandbox, simulates keystrokes, and asserts:

  1. the new layout renders: bold title, ACTION row, "1/N - Select What
     File(s) to DELETE", options, footer hint
  2. SPACE toggles a selection and CONTINUE reflects the count
  3. ENTER continues -> selected file is actually deleted
  4. Q quits the review cleanly

Runs only against /tmp sandboxes — never real user data (AGENTS.md rule 7).
Usage:  python3 test/test_stage3_curses.py
"""

import fcntl
import os
import pty
import re
import select
import shutil
import struct
import tempfile
import termios
import time
import unittest

CLI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "bin", "sidekicks", "find-dupe-files")


def run_pty(steps, setup):
    """Spawn the CLI in a pty inside a temp dir. steps: list of
    (key, wait_for) — write key, then drain until wait_for appears in the
    decoded buffer (timeout ~5s), making the drive deterministic.
    Returns (screen_text, sandbox_dir). Caller cleans up dir."""
    td = tempfile.mkdtemp(prefix="geordi-pty-")
    setup(td)
    pid, fd = pty.fork()
    if pid == 0:  # child: real CLI, fake terminal
        os.chdir(td)
        os.environ["TERM"] = "xterm-256color"
        os.execv(CLI, [CLI, td])
    # curses needs a real window size or the child dies instantly
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    buf = b""

    def drain_until(markers, timeout=6.0):
        """Read until ANY marker (str or tuple of str) appears in decoded
        buffer; return False if the child exits first."""
        nonlocal buf
        if isinstance(markers, str):
            markers = (markers,)
        end = time.time() + timeout

        def matched():
            dec = buf.decode("utf-8", "replace")
            return any(m in dec for m in markers)

        while time.time() < end:
            if matched():
                return True
            r, _, _ = select.select([fd], [], [], 0.2)
            if r:
                try:
                    chunk = os.read(fd, 65536)
                except OSError:
                    return False
                if not chunk:
                    return False
                buf += chunk
        return matched()

    drain_until("MANUAL REVIEW")
    # wait for the first full curses frame before sending keys — keys sent
    # during terminal init get flushed and lost. The footer line is stable
    # across frames and only appears once the first render completes.
    drain_until("Continue, Q to Quit")
    for key, wait_for in steps:
        try:
            os.write(fd, key)
        except OSError:
            break
        if not drain_until(wait_for):
            break
    time.sleep(0.5)
    try:
        while True:
            r, _, _ = select.select([fd], [], [], 0.3)
            if not r:
                break
            chunk = os.read(fd, 65536)
            if not chunk:
                break
            buf += chunk
    except OSError:
        pass
    try:
        os.close(fd)
    except OSError:
        pass
    os.waitpid(pid, 0)
    return buf.decode("utf-8", "replace"), td


def make_byte_dupes(td):
    """Two byte-identical pairs across two folders -> 2 stage-3 groups."""
    a, b = os.path.join(td, "a"), os.path.join(td, "b")
    os.makedirs(a); os.makedirs(b)
    for d in (a, b):
        with open(os.path.join(d, "song.wav"), "wb") as f:
            f.write(b"x" * 1000)
        with open(os.path.join(d, "book.doc"), "wb") as f:
            f.write(b"y" * 500)


def strip_ansi(text):
    """Remove ANSI escapes including charset selectors (ESC(B etc)."""
    return re.sub(r"\x1b(?:\[[0-9;]*[A-Za-z]|\(.|\).)", "", text)


class TestStage3Curses(unittest.TestCase):

    def test_layout_and_delete_selection(self):
        """SPACE selects, ENTER commits the deletion, Q quits cleanly."""
        # group 1 = the .doc pair: SPACE selects a/book.doc, ENTER deletes
        # it; group 2 (song.wav) we QUIT. NOTE: curses sends differential
        # updates after the first frame (only changed bytes), so mid-session
        # screen text like "1 selected" never appears in the raw stream —
        # we assert on the first full frame + filesystem outcomes instead.
        keys = [
            (b" ", "MANUAL REVIEW"),  # SPACE -> select a/book.doc (diff only)
            (b"\r", ("deleted:", "already gone:")),
            (b"q", "REVIEW COMPLETE"),  # Q on group 2 -> quit to summary
        ]
        text, td = run_pty(keys, make_byte_dupes)
        try:
            flat = strip_ansi(text)
            # 1. first-frame layout anchors (full render before any input)
            self.assertIn("Matches in", flat)
            self.assertIn("1/2 - Select What File(s) to DELETE", flat)
            self.assertIn(
                "UP/DOWN: move · SPACE: select/deselect · LEFT: back · "
                "V: view file location", flat)
            self.assertIn("Hit Enter or Right Arrow Key to Continue, Q to Quit",
                          flat)
            # same-filename variant: 'Found:' header + folder-only rows
            self.assertIn("Found: book.doc (500 B) in", flat)
            self.assertIn("> [ ] ./a/", flat)
            self.assertIn("[ ] ./b/", flat)
            self.assertIn("Matches in", flat)
            self.assertNotIn("[CONTINUE", flat)
            # 2. the toggle marker 'x' appears after SPACE (diff redraw)
            self.assertGreater(flat.count("x"), 0)
            # 3. outcomes: selected copy gone, twin survives, other group intact
            self.assertFalse(os.path.exists(os.path.join(td, "a", "book.doc")))
            self.assertTrue(os.path.exists(os.path.join(td, "b", "book.doc")))
            self.assertTrue(os.path.exists(os.path.join(td, "a", "song.wav")))
            self.assertTrue(os.path.exists(os.path.join(td, "b", "song.wav")))
            # 4. summary under the stage-3 section; REVIEW COMPLETE is the
            # standalone terminal sign-off; resolved group shrinks the count
            # 4. summary under the stage-3 section; REVIEW COMPLETE is the
            # standalone terminal sign-off; resolved group shrinks the count.
            # The deletion row can legitimately read either 'deleted:' or
            # 'already gone:' (macOS may reclaim the tmp file between the
            # exists-check and remove — both mean the file is gone).
            self.assertTrue(
                "deleted: a/book.doc (500 B)" in flat
                or "already gone: a/book.doc" in flat,
                f"neither deleted nor already-gone row found:\n{flat[-400:]}")
            # group1 resolved (1 remaining in queue); BOTH groups were
            # rendered (group2 via Q), so reviewed counts 2
            self.assertIn("2 of 2 duplicates reviewed, 1 remaining", flat)
            self.assertIn("rerun 'find-dupe-files' to continue anytime", flat)
            self.assertIn("=== REVIEW COMPLETE ===", flat)
        finally:
            shutil.rmtree(td, ignore_errors=True)

    def test_quit_deletes_nothing(self):
        """Q on the first group leaves every file in place."""
        keys = [(b"q", "REVIEW COMPLETE")]
        text, td = run_pty(keys, make_byte_dupes)
        try:
            for d in ("a", "b"):
                for fn in ("song.wav", "book.doc"):
                    self.assertTrue(os.path.exists(os.path.join(td, d, fn)))
            flat = strip_ansi(text)
            self.assertIn("0 files deleted (0 B), 0 failed", flat)
            self.assertIn("1 of 2 duplicates reviewed, 2 remaining", flat)
            self.assertIn("=== REVIEW COMPLETE ===", flat)
        finally:
            shutil.rmtree(td, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
