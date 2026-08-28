#!/usr/bin/env python3
"""Drive a VM over its serial console: start it, wait for text, type, read back.

⛔ THIS FILE EXISTS SO THERE IS ONE COPY, on the POSIX side. It is the sibling
of ``console.ps1`` and carries the same measured rules, because the rules are
about ttys and not about a language.

⚠ IT IS IMPORTED, NOT RUN. It defines a class and does nothing else.

The two rules that look like fussiness and are not, both measured 2026-08-27:

1. ⛔ TYPE SLOWLY. A serial console is a real tty with a real input queue.
   Writing a whole line at once while ``login`` or the shell is still setting
   up the line discipline silently DROPS characters. A marker of
   ``TOOLKIT-READY-789f28b0`` reached a shell as ``TOO789f28b``.
2. ⛔ COMPARE THE ECHO WITH WHITESPACE REMOVED. A tty wraps the echo at the
   terminal width and inserts a space, so a literal match on the command text
   misses its own echo, the echo survives into the output, and a success marker
   can match the command line that merely mentioned it. That reported "a
   container ran" over a run that had exited with an error.

⛔ AND EVERY PRIMITIVE HERE IS BOUNDED, INCLUDING THE ONE THAT WRITES. That was
not true until 2026-08-28, and the two defects it caused were filed separately
before anybody saw they were the same missing idea:

  INF-08  ``run`` waited for one more PROMPT than there was before, counted with
          a ``$``-anchored pattern that Python matches at the end of the string
          only. The count was 0 or 1 and never rose, so every call returned the
          right answer after burning its whole budget. ⭐ It waits for a prompt
          at or after a POSITION in the stream now, which is what "the command
          finished" means and cannot be miscounted.
  INF-10  ``send`` wrote with no budget at all. Against a guest that has stopped
          draining its console the tty's 1,024-byte queue fills, the write
          blocks in the kernel, and no caller's timeout applies because the
          caller never gets back to check one. ⭐ It takes a budget and returns
          whether the whole line was typed.

⚠ ``send`` RETURNING FALSE IS A REAL STATE AND NOT A WARNING. Part of a line is
sitting in the guest's input queue, so the next thing typed continues it. A
caller that gets False stops the guest; it does not type again.
"""

import os
import re
import subprocess
import time


class Console:
    """A child process whose stdin and stdout are a guest's serial console."""

    def __init__(self, argv, cwd=None, prompt=r"# $"):
        self.argv = list(argv)
        self.prompt = re.compile(prompt)
        self.started = time.monotonic()
        self.proc = subprocess.Popen(
            self.argv,
            cwd=cwd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        os.set_blocking(self.proc.stdout.fileno(), False)
        # ⛔ THE WRITE END TOO, AND THAT IS WHAT MAKES `send` ABLE TO GIVE UP.
        # A blocking write into a full pipe parks in the kernel and no timeout
        # in this process can reach it; a non-blocking one raises
        # BlockingIOError, which is a thing a budget can be spent against.
        # INF-10.
        os.set_blocking(self.proc.stdin.fileno(), False)
        self.text = ""

    # ------------------------------------------------------------------ read
    def pump(self, seconds=0.2):
        """Read whatever is available. Never blocks for longer than *seconds*."""
        deadline = time.monotonic() + seconds
        got = False
        while time.monotonic() < deadline:
            try:
                chunk = self.proc.stdout.read(8192)
            except (BlockingIOError, InterruptedError):
                chunk = None
            if chunk:
                self.text += chunk.decode("utf-8", "replace")
                got = True
            else:
                time.sleep(0.02)
        return got

    def wait_for(self, pattern, seconds):
        """Pump until *pattern* matches, or the budget runs out."""
        rx = re.compile(pattern)
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if rx.search(self.text):
                return True
            if self.proc.poll() is not None:
                self.pump(0.3)
                return bool(rx.search(self.text))
            self.pump()
        return False

    def wait_for_prompt(self, position, seconds):
        """Wait for a prompt that begins at or after *position* in the stream.

        ⭐ That is what "the command finished" means on a console. Waiting for
        the prompt pattern anywhere matches the prompt the command was typed at
        and returns immediately.

        ⛔ A POSITION, NOT A COUNT, AND THAT IS INF-08. This waited for one more
        prompt than there had been, counted with the caller's pattern. Every
        caller anchors that pattern with `$` so it matches a guest sitting idle
        rather than a `# ` in the middle of some output, and Python matches `$`
        at the end of the STRING. So the count was 0 or 1 whatever the guest
        did, "one more than before" was never true, and every call returned the
        right answer after burning its whole budget.

        ⚠ The prompt the command was typed at starts BEFORE *position* and so
        cannot match, which is the whole trick: no count, no baseline, and
        nothing that depends on how many times a pattern can match.
        """
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if self.prompt.search(self.text, position):
                return True
            if self.proc.poll() is not None:
                self.pump(0.3)
                return bool(self.prompt.search(self.text, position))
            self.pump()
        return False

    # ----------------------------------------------------------------- write
    def _type(self, byte, deadline):
        """Put one byte in the guest's input queue, or give up. See INF-10.

        ⛔ The queue is the guest's, it is 1,024 bytes, and a guest that has
        stopped being scheduled stops draining it. The fd is non-blocking, so a
        full queue is a BlockingIOError rather than a process parked in the
        kernel, and a budget can be spent against it.
        """
        while True:
            try:
                if self.proc.stdin.write(byte):
                    return True
            except BlockingIOError:
                pass
            except (BrokenPipeError, OSError):
                return False
            if time.monotonic() >= deadline:
                return False
            time.sleep(0.02)

    def send(self, line, per_char=0.005, seconds=30):
        """Type *line* one character at a time, then a newline. See rule 1.

        ⛔ RETURNS WHETHER THE WHOLE LINE WAS TYPED, and a False is a real state
        rather than a warning: part of the line is in the guest's input queue,
        so the next thing typed continues it. A caller that gets False stops the
        guest. INF-10.
        """
        deadline = time.monotonic() + seconds
        for ch in line:
            if not self._type(ch.encode(), deadline):
                return False
            if per_char:
                time.sleep(per_char)
        return self._type(b"\n", deadline)

    def send_raw(self, data, seconds=5):
        """Put raw bytes in the guest's input queue, with no newline after.

        ⭐ FOR THE CHARACTERS THAT ARE NOT A LINE. `\\x14` is the tty's VSTATUS
        character and 43-siginfo-the-stuck-guest.sh presses it at a guest whose
        userland has stopped, because the KERNEL answers it. ⛔ It exists so
        that nothing has to reach into `proc.stdin` directly: this file's fds
        are non-blocking, so a bare `write` returns None instead of blocking and
        a press would be lost in silence.
        """
        deadline = time.monotonic() + seconds
        for byte in data:
            if not self._type(bytes([byte]), deadline):
                return False
        return True

    def run(self, command, seconds=120):
        """Run one command in the guest and return the lines it printed."""
        before = len(self.text)
        sent = self.send(command)
        ok = sent and self.wait_for_prompt(before, seconds)
        chunk = self.text[before:]
        # See rule 2. Whitespace is stripped from BOTH sides of the comparison
        # so a tty-wrapped echo still matches itself and is removed.
        want = re.sub(r"\s", "", command)
        lines = []
        for raw in chunk.splitlines():
            line = raw.rstrip()
            if not line:
                continue
            if re.sub(r"\s", "", line).find(want) >= 0:
                continue
            # ⚠ THE PROMPT IS MATCHED AGAINST THE RAW LINE, NOT THE STRIPPED
            # ONE. A prompt is `# ` with a trailing space and `raw.rstrip()`
            # removes it, so a `# $` pattern stopped matching its own prompt and
            # a bare `#` was returned as a line of output the guest never
            # printed. ⛔ console.ps1 already allowed for it, with `# ?$`, and
            # this side did not: that is exactly the twin drift the pair exists
            # to prevent.
            if self.prompt.search(raw) and not self.prompt.sub("", raw).strip():
                continue
            lines.append(self.prompt.sub("", line).rstrip())
        return ok, [x for x in lines if x.strip()]

    # ------------------------------------------------------------------ stop
    def elapsed(self):
        return time.monotonic() - self.started

    def stop(self, graceful_command=None, seconds=20):
        if graceful_command and self.proc.poll() is None:
            try:
                self.send(graceful_command)
                self.wait_for(r"Uptime|rebooting|Powering off|halt", seconds)
            except (BrokenPipeError, OSError):
                pass
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=10)
        return self.proc.returncode
