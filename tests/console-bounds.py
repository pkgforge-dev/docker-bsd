#!/usr/bin/env python3
"""Both console primitives are BOUNDED: the read returns early and the write
returns at all.

⛔ WHY THIS EXISTS. `INF-08` and `INF-10` are two defects in one file and they
are the same missing idea. `Console.run()` decided a command had finished by
counting prompts with a `$`-anchored pattern, which Python matches at the end
of the string only, so the count was 0 or 1 and never rose: every call returned
the RIGHT answer after burning its whole timeout. `Console.send()` wrote to the
guest with no budget at all, so against a guest that had stopped draining its
console it never returned, and ten minutes were spent with one `ps`
outstanding.

⛔ NEITHER DEFECT WAS FOUND BY A TEST, AND BOTH WERE FOUND BY WAITING. That is
what this file is for.

⭐ IT NEEDS NO EMULATOR AND NO GUEST. Both cases are about a pipe and a
timeout, so the guest is a few lines of Python: one that answers like a shell
on a tty, and one that prints a prompt and then never reads its input again,
which is exactly the state `INF-09`'s guest reaches.

⛔ IT CANNOT HANG, EVEN AGAINST THE CODE IT WAS WRITTEN TO REFUSE. A test whose
failure mode is "it never returned" is the same shape as the defect, and
`INF-10` is on record as an instrument that failed that way. The signature is
checked before anything is written, and the write itself runs in a daemon
thread that is joined with a budget.

Usage:  python3 tests/console-bounds.py
Exit codes: 0 both bounds hold, 1 one does not, 2 could not run.
"""

import inspect
import os
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "experiments", "lib"))

try:
    from console import Console
except ImportError as exc:  # pragma: no cover - the tree is broken, not the test
    print("console-bounds: cannot import console.py: %s" % exc)
    sys.exit(2)

PASS = 0
FAIL = 0


def ok(msg):
    global PASS
    PASS += 1
    print("  ok   %s" % msg)


def bad(msg):
    global FAIL
    FAIL += 1
    print("  FAIL %s" % msg)


# ⚠ THE ANSWER DELIBERATELY SHARES NO TEXT WITH THE COMMAND. `run()` drops any
# line containing the command, whitespace removed, which is how it removes the
# tty's own echo; an answer of `ANSWER-hello` to a command of `hello` is eaten
# by that filter. ⛔ That is rule 2 working as designed and it is not what this
# file tests.
#
# ⚠ A GUEST THAT BEHAVES LIKE A tty, not like a pipe. It prints its prompt with
# no trailing newline, echoes what was typed the way a line discipline does,
# and prints the prompt again when it is done. That last part is the ONLY
# signal `run()` has that a command finished.
TALKER = r"""
import sys
sys.stdout.write("# ")
sys.stdout.flush()
while True:
    line = sys.stdin.readline()
    if not line:
        break
    line = line.rstrip("\n")
    sys.stdout.write(line + "\r\n")
    sys.stdout.write("GUEST-ANSWERED\r\n# ")
    sys.stdout.flush()
"""

# ⛔ A GUEST IN EXACTLY THE STATE `INF-09` MEASURED: it reached a prompt and
# then stopped being scheduled. It never reads stdin again, so the pipe fills
# and stays full.
DEAF = r"""
import sys, time
sys.stdout.write("# ")
sys.stdout.flush()
time.sleep(600)
"""

# Larger than any pipe buffer this runs on. Linux's is 64 KB by default.
FLOOD = "x" * (512 * 1024)


def check_run_returns_early():
    """⛔ INF-08. `run()` must return when the command is done, not when the
    budget is."""
    con = Console([sys.executable, "-u", "-c", TALKER], prompt=r"# $")
    try:
        if not con.wait_for(r"# $", 20):
            bad("the fake guest never printed a prompt; the test cannot run")
            return
        budget = 30
        started = time.monotonic()
        answered, lines = con.run("hello", seconds=budget)
        elapsed = time.monotonic() - started
        if not answered:
            bad("run() did not see the command finish at all")
        elif elapsed > budget / 3:
            bad("run() took %.1fs of a %ss budget. INF-08: it is counting "
                "prompts with a pattern that can only match at the end of the "
                "buffer, so it waits for a count that never rises."
                % (elapsed, budget))
        else:
            ok("run() returned in %.1fs of a %ss budget" % (elapsed, budget))
        if lines == ["GUEST-ANSWERED"]:
            ok("run() returned exactly what the guest printed: %r" % (lines,))
        else:
            bad("run() returned %r, expected ['GUEST-ANSWERED']. The trailing "
                "prompt is rstripped to `#` before it is compared against a "
                "pattern that needs the space, so it survives as a line of "
                "output the guest never printed." % (lines,))
    finally:
        con.stop()


def check_send_is_bounded():
    """⛔ INF-10. `send()` must return against a guest that stopped reading."""
    sig = inspect.signature(Console.send)
    if "seconds" not in sig.parameters:
        bad("send%s takes no budget. INF-10: every other primitive in that "
            "file takes one and returns False; the one that WRITES takes none, "
            "so it blocks in the kernel and no caller's timeout applies."
            % (sig,))
        return

    con = Console([sys.executable, "-u", "-c", DEAF], prompt=r"# $")
    try:
        if not con.wait_for(r"# $", 20):
            bad("the deaf guest never printed a prompt; the test cannot run")
            return

        result = {}

        def write():
            result["returned"] = con.send(FLOOD, per_char=0, seconds=3)

        # ⛔ DAEMON, AND JOINED WITH A BUDGET. If the bound is gone this thread
        # is blocked in a kernel write that nothing can interrupt, and the test
        # has to be able to say so and exit rather than join it.
        thread = threading.Thread(target=write, daemon=True)
        started = time.monotonic()
        thread.start()
        thread.join(30)
        elapsed = time.monotonic() - started

        if thread.is_alive():
            bad("send() did not return within %.0fs against a guest that "
                "stopped reading. INF-10." % elapsed)
        elif result.get("returned") is not False:
            bad("send() returned %r; it must report False when it could not "
                "type the whole line, because a partially typed line is a "
                "real state the caller has to know about"
                % (result.get("returned"),))
        else:
            ok("send() gave up after %.1fs and said so" % elapsed)
    finally:
        con.stop()


def main():
    print("console-bounds (%s)" % sys.executable)
    check_run_returns_early()
    check_send_is_bounded()
    print("\n%s passed, %s failed" % (PASS, FAIL))
    # ⛔ _exit, NOT sys.exit. A blocked writer thread is not joinable and a
    # normal interpreter shutdown waits for nothing but still has to tear down
    # a pipe that a kernel write is sitting on.
    sys.stdout.flush()
    os._exit(0 if FAIL == 0 else 1)


if __name__ == "__main__":
    main()
