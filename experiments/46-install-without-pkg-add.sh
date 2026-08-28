#!/bin/sh
# 46-install-without-pkg-add.sh - put the compiler in the guest with `tar`.
#
# ⛔ WHY IT EXISTS. `INF-09` is the entry that blocks `IMG-02` and `PERF-01`,
# and after nine explanations what is measured is narrow and useful:
# `pkg_add -U` on this package never returns, and plain `tar` of the same
# archive to the same destination finishes in about half a minute.
# [44-block-size-control.sh](44-block-size-control.sh) and
# [45-is-it-the-root.sh](45-is-it-the-root.sh) took the filesystem, the block
# size, the disk and the root out of the frame one at a time.
#
# ⭐ AND `pkg_add -v` SAYS WHERE IT STOPS. It prints every path in the package,
# reaches the last one alphabetically, and then goes silent for the rest of the
# run while the kernel reports user time frozen and system time climbing.
# ⛔ **The unpack finishes. Whatever `pkg_add` does after the unpack does not.**
#
# ⭐ SO SKIP IT. A pkgsrc binary package is an archive with a known layout, and
# nothing about it needs the package manager:
#
#   @cwd /usr/pkg              one line in +CONTENTS, and every payload path is
#                              relative to it
#   gcc14/...                  1,655 files, all under that one prefix
#   +CONTENTS +COMMENT ...     nine metadata files, which belong in
#                              /var/db/pkg/<pkgname>/ and are marked @ignore so
#                              they are not payload
#   +INSTALL                   the standard pkgsrc script. Every branch in it is
#                              guarded by `test -x ./+HELPER`, and this package
#                              ships no helper, so it is a no-op here. ⚠ It is
#                              still run, because assuming it is a no-op for the
#                              NEXT package is how this stops working quietly
#
# ⛔ THE PACKAGE NAME IS READ, NOT TYPED. `@name` in +CONTENTS is what pkgsrc
# itself uses, and a name hardcoded in a script is a name that is wrong the
# first time the pin moves.
#
# ⭐ AND IT MEASURES THE COMPILE, BECAUSE THE GUEST IS ALREADY BOOTED. `PERF-01`
# needs `cc -O2 -c sqlite3.c` inside the guest and has never had a number for
# it, only for the Linux side. The source is already in the image, at /sqlite3.c,
# because `-v` does not reach the guest and there is no other way to hand it one.
#
# Usage:
#   sh experiments/46-install-without-pkg-add.sh [IMAGE]
#
# Environment:
#   PROBE_FOR     seconds to allow the compile. Default 2400
#   PROBE_TAR     the package. Default /guest-package.tgz
#   ENGINE        podman or docker. Detected otherwise
#
# Exit codes: 0 the probe ran and printed what came back, 1 the guest did not
# boot, 2 a prerequisite is missing.
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
[ -n "$ENGINE" ] || { printf '46: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '46: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '46-install-without-pkg-add\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  package   %s\n' "${PROBE_TAR:-/guest-package.tgz}"
printf '  budget    %ss for the compile\n' "${PROBE_FOR:-2400}"
printf '\n'

PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Install a pkgsrc binary package with `tar`, then use what it installed.

⛔ THIS IMPORTS guest.py RATHER THAN REBUILDING THE EMULATOR'S ARGUMENT LIST.
Every flag in that list is a measurement.
"""

import os
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

FOR = int(os.environ.get("PROBE_FOR") or "2400")
PKG = os.environ.get("PROBE_TAR") or "/guest-package.tgz"

T0 = time.monotonic()
FAILED = []


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def step(con, name, line, seconds, want_rc=0):
    """Run one line, time it, print what came back, and say whether it passed."""
    say("=== %s" % name)
    say("    %s" % line)
    started = time.monotonic()
    out, rc, timed_out = guest.run_line(con, line, seconds)
    wall = time.monotonic() - started
    if timed_out:
        say("⛔ %s: NOTHING CAME BACK IN %ss (wall %.1fs)" % (name, seconds, wall))
        for chunk in out:
            print(chunk, flush=True)
        FAILED.append(name)
        return None
    for line_out in out:
        print("    " + line_out, flush=True)
    if rc != want_rc:
        say("⛔ %s: rc=%s, wanted %s, wall %.1fs" % (name, rc, want_rc, wall))
        FAILED.append(name)
    else:
        say("⭐ %s: rc=%s, wall %.1fs" % (name, rc, wall))
    return out


def main():
    say("booting")
    con, _accel, single_user = guest.boot("tcg")
    if con is None:
        say("the guest did not reach a shell")
        return 1
    guest.prepare_guest(con, single_user)

    # ⛔ THE ONE COMMAND `pkg_add` WOULD HAVE RUN, MINUS `pkg_add`. The prefix is
    # the `@cwd` line in the package's own +CONTENTS and it is the only place a
    # payload path is relative to.
    step(con, "extract into the prefix",
         'mkdir -p /usr/pkg && cd /usr/pkg && '
         'S=$(date +%%s); tar xpf %s; R=$?; E=$(date +%%s); '
         'echo "EXTRACT rc=$R seconds=$((E-S))"; exit $R' % PKG, 900)

    # ⛔ READ THE NAME OUT OF THE PACKAGE. A hardcoded one is wrong the first
    # time scripts/sources moves the pin.
    out = step(con, "read the package name",
               'cd /usr/pkg && sed -n "s/^@name //p" +CONTENTS | head -1', 120)
    name = None
    for line in out or []:
        candidate = line.strip()
        if candidate and "@name" not in candidate:
            name = candidate
            break
    if not name:
        say("⛔ no @name in the package's +CONTENTS. Nothing else can run.")
        con.stop()
        return 1
    say("the package calls itself %s" % name)

    step(con, "register it in the package database",
         'cd /usr/pkg && mkdir -p /var/db/pkg/%s && mv +* /var/db/pkg/%s/ && '
         'ls /var/db/pkg/%s | tr "\\n" " "' % (name, name, name), 300)

    # ⚠ RUN IT EVEN THOUGH IT IS A NO-OP FOR THIS PACKAGE. Every branch in the
    # standard +INSTALL is guarded by `test -x ./+HELPER` and this package ships
    # no helper. ⛔ Assuming that for the NEXT package is how this stops working
    # without anybody noticing.
    step(con, "run the package's own +INSTALL",
         'cd /var/db/pkg/%s && sh ./+INSTALL %s POST-INSTALL' % (name, name), 300)

    step(con, "the package manager can see it",
         'pkg_info -e %s; echo "pkg_info -e said $?"; pkg_info | head -5' % name,
         300)

    step(con, "the compiler answers",
         '/usr/pkg/gcc14/bin/gcc --version | head -2', 300)

    step(con, "space left", 'df -k / | tail -1', 120)

    # ⭐ PERF-01's guest side. The same line scripts/bench-compile runs, against
    # the same bytes the Linux side compiles.
    step(con, "cc -O2 -c sqlite3.c, which is PERF-01",
         'S=$(date +%s); /usr/pkg/gcc14/bin/gcc -O2 -c /sqlite3.c -o /tmp/s.o; '
         'R=$?; E=$(date +%s); ls -l /tmp/s.o; '
         'echo "BENCH rc=$R seconds=$((E-S))"; exit $R', FOR)

    con.stop("halt -p")
    say("=== the result, as one line")
    print("RESULT install=%s failed=%s"
          % ("no" if FAILED else "yes", ",".join(FAILED) or "none"), flush=True)
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
    -e "PROBE_FOR=${PROBE_FOR:-2400}" \
    -e "PROBE_TAR=${PROBE_TAR:-/guest-package.tgz}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=none" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c 'printf %s "$PROBE_B64" | base64 -d > /probe.py && exec python3 -u /probe.py' \
  || rc=$?

printf '\n46: the container exited %s\n' "$rc"
exit "$rc"
