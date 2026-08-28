#!/bin/sh
# 43-siginfo-the-stuck-guest.sh - ask the KERNEL, because userland has stopped.
#
# ⛔ WHY IT EXISTS, AND IT IS A DIFFERENT REASON FROM 42's. `INF-09`'s guest
# does not merely run slowly: measured 2026-08-28 by
# [42-probe-pkg-add-inside-guest.sh](42-probe-pkg-add-inside-guest.sh), its
# whole userland stops being scheduled. A shell builtin `echo` produced no
# output for 300 seconds, twice. Thirty `sleep 30` calls took over 1500 seconds
# of wall time. ⛔ So every instrument that is a PROGRAM — `ps`, `top`,
# `vmstat`, `fstat`, a driver script, a `kill` — is an instrument that cannot
# run, and 42 could not get its own record out of the guest twice in a row.
#
# ⭐ SIGINFO IS ANSWERED BY THE KERNEL AND NEEDS NO USERLAND AT ALL. Ctrl-T on
# a NetBSD tty is handled in the line discipline: the kernel prints the
# foreground process's name, its WAIT CHANNEL and its CPU split, and it prints
# it whether or not anything in userland will ever be scheduled again.
#
# ```text
# load: 0.99  cmd: pkg_add 2902 [biowait] 412.30u 88.12s 98% 13356k
# ```
#
# ⛔ THE BRACKETED WORD IS THE ANSWER `INF-09` HAS BEEN MISSING. `[biowait]` is
# waiting on a disk, `[tstile]` is a kernel lock, `[uvn_fp2]` and `[fltbal]`
# are memory, and a `[CPU n]` or `RUN` is a process that is genuinely running.
# ⚠ Every one of the seven dead explanations was a guess at that word.
#
# ⭐ AND IT CANNOT WEDGE THE WAY 42's FIRST VERSION DID. Ctrl-T is consumed by
# the line discipline as it arrives, so it never joins the tty's input queue
# and the queue never fills. `INF-10` is about a write that blocks on a full
# queue; this instrument puts nothing in it.
#
# ⛔ THE COMMAND RUNS IN THE FOREGROUND, AND THAT IS LOAD BEARING. SIGINFO goes
# to the tty's FOREGROUND process group. 42 ran the command in the background
# so that the shell stayed free to be questioned, which is exactly the shape
# that puts it out of reach here.
#
# Usage:
#   sh experiments/43-siginfo-the-stuck-guest.sh [IMAGE]
#
# Environment:
#   PROBE_EVERY   seconds between Ctrl-T presses. Default 30
#   PROBE_FOR     seconds to keep pressing for. Default 1500
#   PROBE_CMD     what to run in the guest. Default `pkg_add -U
#                 /guest-package.tgz`
#   ENGINE        podman or docker. Detected otherwise
#
# Exit codes: 0 the probe ran and printed what came back, 1 it could not boot
# the guest, 2 a prerequisite is missing.
#
# ⛔ Read the exit code from this process, unpiped.

set -eu

IMAGE="${1:-localhost/netbsd:build}"

ENGINE="${ENGINE:-}"
if [ -z "$ENGINE" ]; then
  for e in podman docker; do
    if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
  done
fi
[ -n "$ENGINE" ] || { printf '43: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '43: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '43-siginfo-the-stuck-guest\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  every     %ss for %ss\n' "${PROBE_EVERY:-30}" "${PROBE_FOR:-1500}"
printf '  command   %s\n' "${PROBE_CMD:-pkg_add -U /guest-package.tgz}"
printf '\n'

PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Press Ctrl-T at a guest whose userland has stopped, and read what the kernel
says back.

⛔ THIS IMPORTS guest.py RATHER THAN REBUILDING THE EMULATOR'S ARGUMENT LIST.
Every flag in that list is a measurement.
"""

import os
import re
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

EVERY = int(os.environ.get("PROBE_EVERY") or "30")
FOR = int(os.environ.get("PROBE_FOR") or "1500")
PKG = os.environ.get("PROBE_PKG") or "/guest-package.tgz"
COMMAND = os.environ.get("PROBE_CMD") or ("pkg_add -U %s" % PKG)

# ⛔ 0x14. The tty's VSTATUS character, and the reason this file exists.
CTRL_T = b"\x14"

T0 = time.monotonic()


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def main():
    accel = os.environ.get("BSD_ACCEL", "tcg")
    say("booting, accel=%s mem=%s net=%s"
        % (accel, os.environ.get("BSD_MEM"), os.environ.get("BSD_NET")))
    con, accel, single_user = guest.boot(accel)
    if con is None:
        say("the guest did not reach a shell")
        return 1
    guest.prepare_guest(con, single_user)

    # ⭐ PROVE THE INSTRUMENT BEFORE TRUSTING IT, on a guest that is idle and
    # can still answer. ⛔ A Ctrl-T that produces nothing here is a tty with
    # VSTATUS disabled, and every silence later would then mean nothing.
    say("=== 1. does Ctrl-T answer at all on this tty")
    before = len(con.text)
    con.send("stty -a | head -4", per_char=0.005)
    guest.wait_after(con, r"\$", before, 30)
    con.pump(2.0)
    print(con.text[before:], flush=True)

    before = len(con.text)
    con.send("sleep 30", per_char=0.005)
    time.sleep(3)
    con.proc.stdin.write(CTRL_T)
    con.proc.stdin.flush()
    con.pump(5.0)
    say("Ctrl-T over a plain `sleep 30` said:")
    print(con.text[before:], flush=True)
    if "load:" not in con.text[before:]:
        say("⛔ SIGINFO produced nothing on this tty. Everything below is void.")
    else:
        say("⭐ SIGINFO works here, so a silence later is a real silence.")
    guest.wait_after(con, r"# $", before, 60)

    # ── the run, in the foreground, questioned by the kernel ────────────────
    say("=== 2. %s, in the foreground" % COMMAND)
    started = time.monotonic()
    before = len(con.text)
    con.send(COMMAND, per_char=0.005)
    con.pump(2.0)

    deadline = started + FOR
    next_press = started + EVERY
    presses = 0
    while time.monotonic() < deadline:
        con.pump(0.5)
        if time.monotonic() >= next_press:
            mark = len(con.text)
            try:
                con.proc.stdin.write(CTRL_T)
                con.proc.stdin.flush()
            except (BrokenPipeError, OSError) as exc:
                say("the console went away: %s" % exc)
                break
            presses += 1
            con.pump(3.0)
            answer = con.text[mark:].replace("\r", "").strip()
            say("t=%-5d %s" % (int(time.monotonic() - started),
                               answer if answer else "⛔ NOTHING CAME BACK"))
            next_press = time.monotonic() + EVERY
        if con.proc.poll() is not None:
            say("the emulator exited")
            break

    say("=== 3. %d presses, and the tail of everything the console carried"
        % presses)
    print(con.text[-4000:], flush=True)
    con.stop()
    say("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PROBE_PY
)

B64=$(printf '%s\n' "$PAYLOAD" | base64 | tr -d '\n')

# ⛔ MSYS REWRITES ANYTHING THAT LOOKS LIKE A PATH, INCLUDING `/bin/sh` HANDED
# TO --entrypoint. docs/conventions/shell.md section 7.
#
# ⛔ SC2016 IS DISABLED ON PURPOSE: `$PROBE_B64` has to reach the CONTAINER'S
# shell unexpanded and be read from its environment there.
rc=0
# shellcheck disable=SC2016
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  "$ENGINE" run --rm -i \
    --entrypoint /bin/sh \
    -e "PROBE_B64=$B64" \
    -e "PROBE_EVERY=${PROBE_EVERY:-30}" \
    -e "PROBE_FOR=${PROBE_FOR:-1500}" \
    -e "PROBE_CMD=${PROBE_CMD:-}" \
    -e "BSD_ACCEL=${BSD_ACCEL:-tcg}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=${BSD_NET:-none}" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c 'printf %s "$PROBE_B64" | base64 -d > /probe.py && exec python3 -u /probe.py' \
  || rc=$?

printf '\n43: the container exited %s\n' "$rc"
exit "$rc"
