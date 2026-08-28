#!/bin/sh
# 42-probe-pkg-add-inside-guest.sh - ask the GUEST what pkg_add is doing.
#
# ⛔ INF-09 HAS SIX DEAD EXPLANATIONS AND EVERY ONE OF THEM WAS INFERRED FROM
# OUTSIDE THE GUEST. The emulator is at 100 percent CPU, `pkg_add` prints
# nothing for fifty minutes, and every reading so far has been a guess about
# what a busy emulator means. This script takes the reading the entry's
# approach section asks for and nobody has taken: from inside, while it runs.
#
# ⭐ WHY IT EXISTS: the six guesses all asked how FAST something was, and none
# of them could ask WHERE the process was. That question has an answer and it
# is one command away, on the other side of a serial console nobody had run an
# instrument through.
#
# ⭐ IT ANSWERS ONE QUESTION AND IT IS THE ONE THE SIX GUESSES COULD NOT.
# `top` and `ps` separate a process spinning on a CPU from a process waiting on
# something, and they name WHAT it waits on. A process at `RUN` with a climbing
# involuntary context-switch count is running; one parked in `biowait`, `tstile`
# or `uvm` is blocked, and the state names where.
#
# ⭐ AND IT LOOKS AT THE WHOLE PROCESS TABLE, NOT AT pkg_add. If the CPU is
# being burnt by the pagedaemon, by an ioflush, or by a child pkg_add forked,
# then pkg_add is innocent and every fix aimed at pkg_add is the seventh dead
# guess. Nothing outside the guest can tell those apart.
#
# ⛔ NOTHING IS TYPED AT THE GUEST WHILE pkg_add RUNS, AND THAT IS NOT A STYLE
# CHOICE. The first version of this script sampled by sending a command every
# forty seconds, and it WEDGED: the guest stops draining its serial console
# input under this load, the emulator stops reading its own stdin, and
# `Console.send` blocks on the write with no timeout. Measured 2026-08-28, ten
# minutes with one `ps` outstanding. ⚠ Filed as `INF-10` rather than patched,
# because `console.py` is this repository's single copy of two measured tty
# rules and its twin has to move with it.
#
# ⭐ SO THE RECORDING HAPPENS INSIDE THE GUEST, INTO FILES. A driver script is
# typed in while the guest is idle and then run ONCE. It starts `top` and
# `vmstat` as recorders, starts `pkg_add`, and sleeps. The console carries no
# traffic at all until it is over, and then the whole record is read back off a
# guest that is idle again because `pkg_add` has been killed.
#
# ⛔ IT DOES NOT WAIT FOR pkg_add TO FINISH, ON PURPOSE. It has never finished.
# The value is in the record, so the run is bounded and the process is killed.
#
# ⚠ IT REPRODUCES THE FAILING CONFIGURATION RATHER THAN A COMFORTABLE ONE.
# BSD_MEM=1024 and BSD_NET=none are what the Containerfile's provision stage
# sets, so this is the same guest that did not finish, not a similar one.
#
# What it needs: podman or docker, and the `build` variant of this project's
# image, which carries `/guest-package.tgz` and a package manager.
#
# Usage:
#   sh experiments/42-probe-pkg-add-inside-guest.sh [IMAGE]
#
# Environment:
#   PROBE_RUNFOR     seconds to record for. Default 600, which is well past
#                    the extraction phase, which ends at about t=200s
#   PROBE_CMD        what to run in the guest. Default `pkg_add -U
#                    /guest-package.tgz`. ⭐ The CONTROL is
#                    `tar xpf /guest-package.tgz -C /var/tmp/x`, which writes
#                    the same bytes and does no bookkeeping at all.
#                    ⚠ `xpf`, not `xzpf`: pkgsrc still names its packages
#                    `.tgz` and they are XZ. Read on 2026-08-28 off the file's
#                    own magic, `fd 37 7a 58 5a`
#   ENGINE           podman or docker. Detected otherwise
#
# Exit codes: 0 the probe ran and printed its record, 1 it could not boot the
# guest or could not start pkg_add, 2 a prerequisite is missing.
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
[ -n "$ENGINE" ] || { printf '42: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '42: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '42-probe-pkg-add-inside-guest\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  record    %ss\n' "${PROBE_RUNFOR:-600}"
printf '  command   %s\n' "${PROBE_CMD:-pkg_add -U /guest-package.tgz}"
printf '\n'

# ⛔ THE PAYLOAD TRAVELS AS BASE64 AND IS NEVER QUOTED FOR A SHELL. It contains
# quotes, dollars and newlines, and this repository already knows what those do
# to a payload crossing a shell boundary. docs/conventions/shell.md section 7.
PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Record what the guest does while pkg_add runs, from inside the guest.

⛔ THIS IMPORTS guest.py RATHER THAN REBUILDING THE EMULATOR'S ARGUMENT LIST.
Every flag in that list is a measurement, and a second copy here would be a
second place for one of them to be lost.
"""

import os
import re
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

# ⛔ AN EMPTY VARIABLE IS NOT AN ABSENT ONE, AND `.get(name, default)` CANNOT
# TELL THEM APART. The wrapper below passes `-e PROBE_CMD=` when the caller set
# nothing, so the name IS in the environment, with an empty value, and the
# default never applies.
#
# ⚠ MEASURED 2026-08-28, AND IT COST A WHOLE RUN. The driver came out holding
# `exec` with no command, which in `sh` applies the redirections and returns 0.
# So the run forked a job, printed its pid, wrote nothing, used no CPU and
# touched no disk — which is INDISTINGUISHABLE from the frozen guest this
# script exists to investigate. ⭐ `or` is the fix, and it is why the driver is
# now read back and the command confirmed running before anything is believed.
RUNFOR = int(os.environ.get("PROBE_RUNFOR") or "600")
CPULIMIT = int(os.environ.get("PROBE_CPULIMIT") or str(max(60, RUNFOR - 60)))
PKG = os.environ.get("PROBE_PKG") or "/guest-package.tgz"

# ⭐ THE CONTROL IS THE POINT OF THIS BEING A VARIABLE. `pkg_add` unpacks an
# archive and then does bookkeeping; `tar` unpacks the same archive and stops.
# ⛔ Running both through the same recorder is what separates "this guest
# cannot write half a gigabyte" from "pkg_add cannot finish", and no reading
# taken from outside the guest can tell those two apart.
COMMAND = os.environ.get("PROBE_CMD") or ("pkg_add -U %s" % PKG)

T0 = time.monotonic()

# ⛔ NOT ONE SINGLE QUOTE ANYWHERE IN THESE LINES. Each is written into the
# guest with `echo '...' >> file`, and a quote inside would end the quoting and
# hand the guest's shell the rest of the line as code.
DRIVER = [
    "set -u",
    # ⭐ TWO RECORDERS, EACH ONE PROCESS. They are started before the command
    # and write to files, so a sample costs no fork. ⛔ That is the whole
    # reason this version works and the first one did not: under this load a
    # fork takes minutes, and a sampler that forks per sample stops sampling
    # exactly when the interesting thing starts.
    "top -b -s 5 -d 400 20 > /var/tmp/top.log 2>&1 &",
    "vmstat 5 400 > /var/tmp/vm.log 2>&1 &",
    # ⭐ THE CPU LIMIT IS BOTH THE SAFETY NET AND THE MEASUREMENT, and that is
    # the best thing about it.
    #
    # ⛔ As a safety net: the kernel enforces `RLIMIT_CPU` itself. Every other
    # way of stopping this process needs some userland to be scheduled, and
    # the whole problem is that userland stops being scheduled. Measured
    # 2026-08-28: a `kill` that could not run left the guest unreadable and
    # the record unrecoverable.
    #
    # ⭐ As a measurement: a process that dies of `SIGXCPU` was BURNING CPU,
    # and a process still alive after its CPU limit was NOT. ⛔ That is the
    # spinning-or-waiting question the six dead guesses could not answer, and
    # it is answered by which of the two happens.
    "( ulimit -t CPULIMIT_HERE; exec %s ) > /var/tmp/pa.log 2>&1 &" % COMMAND,
    "PA=$!",
    "echo probe-started pa=$PA",
    # ⛔ SAY IT IS RUNNING, DO NOT ASSUME IT. `$!` is a pid the shell hands out
    # before anything has been executed, so printing it proves only that a job
    # was forked. Measured 2026-08-28: a run printed a pid and the command
    # never ran, and the record could not tell the two apart.
    "sleep 20",
    "ps -axo pid,state,wchan,pcpu,time,comm | head -12",
    "echo probe-confirmed",
    # ⛔ ONE SLEEP, NOT THIRTY. Each `sleep` is a fork, and thirty of them took
    # more than 1500 seconds of wall time to cover 900 seconds of schedule.
    "sleep RUNFOR_HERE",
    "echo probe-woke",
    # ⛔ KILLED, NOT WAITED FOR. It has never finished, and the record cannot
    # be read off a guest this process is starving.
    "kill -9 $PA 2>/dev/null",
    "sleep 20",
    "echo probe-recording-over",
]


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def raw(*parts):
    print(*parts, flush=True)


def one(con, cmd, seconds=180, quiet=False):
    """Run one command in the guest, print what it said, return its lines."""
    started = time.monotonic()
    out, rc, timed_out = guest.run_line(con, cmd, seconds)
    took = time.monotonic() - started
    if not quiet:
        say("$ %s" % cmd)
        say("  rc=%s%s in %.1fs" % (rc, " TIMED-OUT" if timed_out else "", took))
        for line in out:
            raw("        | %s" % line)
    return out, rc, timed_out


def main():
    accel = os.environ.get("BSD_ACCEL", "tcg")
    say("booting, accel=%s mem=%s net=%s"
        % (accel, os.environ.get("BSD_MEM"), os.environ.get("BSD_NET")))
    con, accel, single_user = guest.boot(accel)
    if con is None:
        say("the guest did not reach a shell")
        return 1
    guest.prepare_guest(con, single_user)

    say("=== 1. what instruments this guest has")
    one(con, "for t in ps ktrace kdump vmstat top fstat pkg_add pkg_info "
             "sysctl; do c=$(command -v $t || echo MISSING); "
             "echo \"$t $c\"; done", 120)
    # ⛔ THE BINARY BEING PRESENT IS NOT THE INSTRUMENT BEING AVAILABLE, and
    # this is the row that proves it. `ktrace` is in the userland and
    # `ktrace(2)` is NOT IN THIS KERNEL: smolBSD's SMOL config is built without
    # `options KTRACE`. ⚠ `INF-09`'s approach section asked for a ktrace and it
    # cannot be taken on this guest at all, which is a fact about the guest
    # rather than about the entry. Measured, here, every run.
    one(con, "ktrace -f /tmp/ktprobe -t cn /bin/echo ktrace-works "
             "2>&1 | head -2", 120)
    # ⚠ ASKED, NOT ASSUMED. A `top` that does not take `-b` would leave the
    # main recorder empty and the run would look like a guest that said
    # nothing, which is the failure this whole entry is about.
    one(con, "top -b -s 1 -d 1 3 2>&1 | head -6", 120)

    say("=== 2. the guest before anything runs")
    one(con, "uname -a; sysctl -n hw.physmem hw.ncpu; "
             "echo swap:; swapctl -l 2>&1 | head -3; "
             "echo disk:; df -k / /tmp /var/tmp 2>&1; "
             "echo pkg:; ls -l %s" % PKG, 180)
    one(con, "ps -axo pid,ppid,state,wchan,pcpu,time,nvcsw,nivcsw,majflt,"
             "minflt,inblk,oublk,rss,comm", 180)

    # ── the driver goes in while the guest is idle ──────────────────────────
    say("=== 3. writing the driver into the guest")
    one(con, "rm -f /var/tmp/probe.sh /var/tmp/top.log /var/tmp/vm.log "
             "/var/tmp/pa.log", 120)
    for line in DRIVER:
        body = line.replace("RUNFOR_HERE", str(RUNFOR))
        body = body.replace("CPULIMIT_HERE", str(CPULIMIT))
        _out, rc, timed_out = guest.run_line(
            con, "echo '%s' >> /var/tmp/probe.sh" % body, 120)
        if timed_out or rc != 0:
            say("could not write the driver line: %s" % body)
            con.stop("halt -p")
            return 1
    # ⛔ THE FILE IS READ BACK, NOT ASSUMED. A driver that parses is not a
    # driver that says what you meant: a run on 2026-08-28 wrote eleven lines,
    # parsed clean, printed a pid and never started the command, and there was
    # no way to tell from the record whether the line was wrong or the guest
    # was. ⭐ Printing it costs one command and removes that whole class.
    one(con, "wc -l < /var/tmp/probe.sh; cat -v /var/tmp/probe.sh; "
             "sh -n /var/tmp/probe.sh && echo driver-parses", 180)

    # ── run it, and say nothing at all until it is over ─────────────────────
    #
    # ⛔ THE BUDGET IS THE DRIVER'S OWN PLUS A LARGE MARGIN, and the margin is
    # not politeness. The guest's clock is the wall clock, so a `sleep 600` is
    # ten real minutes; but the two `sleep` calls around it are FORKS, and a
    # fork under this load was measured taking minutes on its own.
    budget = RUNFOR + 1200
    say("=== 4. running it. %ds of recording, console silent" % RUNFOR)
    _out, rc, timed_out = one(con, "sh /var/tmp/probe.sh", budget)
    if timed_out:
        say("the driver did not report back inside %ss" % budget)

    # ── the guest is idle again, so the record can be read ──────────────────
    say("=== 5. the record")
    one(con, "df -k /; echo palog=$(wc -c < /var/tmp/pa.log); "
             "cat /var/tmp/pa.log | tail -30", 600)
    one(con, "ls -l /var/tmp/top.log /var/tmp/vm.log 2>&1", 600)

    # ⭐ THE STATE COLUMN IS THE ANSWER, ONE LINE PER DISPLAY. NetBSD's `top`
    # prints the wait channel there: `RUN` or `CPU/0` is running, and
    # `biowait`, `tstile`, `vnlock`, `uvm` or `fltbal` each name a different
    # thing to be stuck on. ⛔ Every reading before this one was taken from
    # outside the guest, where this column does not exist.
    say("=== 6. the process, once per display, for the whole run")
    one(con, "grep -E 'pkg_add|pkgadd|tar|pgdaemon|ioflush' "
             "/var/tmp/top.log | head -150", 900)

    say("=== 7. memory and load, every fourth display")
    one(con, "awk '/load averages/ { d++ } d % 4 == 1 && "
             "(/load averages/ || /Memory/ || /Swap/)' /var/tmp/top.log "
             "| head -150", 900)

    say("=== 8. vmstat, every sixth line")
    one(con, "head -2 /var/tmp/vm.log; awk 'NR % 6 == 0' /var/tmp/vm.log "
             "| head -70", 900)

    con.stop("halt -p")
    say("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PROBE_PY
)

B64=$(printf '%s\n' "$PAYLOAD" | base64 | tr -d '\n')

# ⛔ MSYS REWRITES ANYTHING THAT LOOKS LIKE A PATH IN AN ARGUMENT, INCLUDING
# `/bin/sh` HANDED TO --entrypoint. docs/conventions/shell.md section 7. The
# two variables below are what stop it, and scripts/build-netbsd already
# carries the same pair for the same reason.
#
# ⛔ SC2016 IS DISABLED ON PURPOSE AND IT IS THE POINT OF THE LINE. `$PROBE_B64`
# has to reach the CONTAINER'S shell unexpanded; expanding it here would put
# eight kilobytes of base64 on this host's command line instead of reading it
# from the environment inside.
rc=0
# shellcheck disable=SC2016
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  "$ENGINE" run --rm -i \
    --entrypoint /bin/sh \
    -e "PROBE_B64=$B64" \
    -e "PROBE_RUNFOR=${PROBE_RUNFOR:-600}" \
    -e "PROBE_CPULIMIT=${PROBE_CPULIMIT:-}" \
    -e "PROBE_CMD=${PROBE_CMD:-}" \
    -e "BSD_ACCEL=${BSD_ACCEL:-tcg}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=${BSD_NET:-none}" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c 'printf %s "$PROBE_B64" | base64 -d > /probe.py && exec python3 -u /probe.py' \
  || rc=$?

printf '\n42: the container exited %s\n' "$rc"
exit "$rc"
