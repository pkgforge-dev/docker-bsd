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

    def prompts(self):
        return len(self.prompt.findall(self.text))

    def wait_for_prompt(self, baseline, seconds):
        """Wait until one MORE prompt than *baseline*.

        ⭐ That is what "the command finished" means on a console. Waiting for
        the prompt pattern itself matches the prompt the command was typed at
        and returns immediately.
        """
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if self.prompts() > baseline:
                return True
            if self.proc.poll() is not None:
                self.pump(0.3)
                return self.prompts() > baseline
            self.pump()
        return False

    # ----------------------------------------------------------------- write
    def send(self, line, per_char=0.005):
        """Type *line* one character at a time, then a newline. See rule 1."""
        for ch in line:
            self.proc.stdin.write(ch.encode())
            self.proc.stdin.flush()
            if per_char:
                time.sleep(per_char)
        self.proc.stdin.write(b"\n")
        self.proc.stdin.flush()

    def run(self, command, seconds=120):
        """Run one command in the guest and return the lines it printed."""
        baseline = self.prompts()
        before = len(self.text)
        self.send(command)
        ok = self.wait_for_prompt(baseline, seconds)
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
            if self.prompt.search(line) and not self.prompt.sub("", line).strip():
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
