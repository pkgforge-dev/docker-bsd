#!/bin/sh
# 47-comp-set-and-compile.sh - the guest has a compiler and cannot compile.
#
# ⛔ WHY IT EXISTS, AND IT IS A DEFECT NOBODY HAD LOOKED FOR.
# [46-install-without-pkg-add.sh](46-install-without-pkg-add.sh) put `gcc14`
# into the guest with `tar`, in 46 seconds, and `gcc --version` answered.
# ⛔ **The first compile then failed in under two seconds:**
#
# ```text
# /usr/pkg/gcc14/lib/gcc/.../include-fixed/stdio.h:54:10:
#         fatal error: sys/cdefs.h: No such file or directory
# ```
#
# ⛔ **Read out of the guest rather than guessed at**, and it is worse than one
# header:
#
# ```text
# /usr/include            exists, and has no sys/cdefs.h
# /usr/lib/libc.a         missing
# /usr/bin/as             MISSING. /usr/bin/ld is there
# ```
#
# ⛔ **Without an assembler `gcc -c` cannot produce an object file at all**, so
# the headers are only half of it. ⭐ All three live in NetBSD's `comp` set,
# which this repository does not fetch anywhere: `scripts/sources` takes `base`
# and `etc`. ⚠ `TODO/measurement.md` already recorded that gap for a CROSS
# sysroot, from reading `R29`. **It is the same gap inside the guest**, and
# nothing had connected the two.
#
# ⭐ THE SET IS PUBLISHED AND THE VERSION MATCHES. The guest says
# `smolBSD 11.0_STABLE`, and NetBSD publishes `NetBSD-11.0/amd64/binary/sets/`.
# ⛔ Pinning the guest against 11.0 rather than the 10.1 that `scripts/sources`
# uses for the OCI userlands is a decision this experiment does not make; it
# uses the one the guest reports.
#
# ⭐ AND IT IS PROVED WITHOUT A REBUILD. The set rides in on a second disk, the
# way [45-is-it-the-root.sh](45-is-it-the-root.sh) carries one, so this answers
# in minutes instead of a full image build. ⛔ **That is what makes it an
# experiment**: a published image must bake the set into a layer, and
# `images/netbsd/Containerfile` is where that belongs once this says it works.
#
# ⭐ IT ALSO PRODUCES `PERF-01`'s MISSING HALF. The Linux side of
# `scripts/bench-compile` is measured and the guest side never has been, because
# there was no compiler. The workload here is the same line against the same
# bytes: the image already carries `/sqlite3.c` inside the guest.
#
# Usage:
#   sh experiments/47-comp-set-and-compile.sh [IMAGE]
#
# Environment:
#   PROBE_FOR     seconds to allow the compile. Default 3600
#   COMP_URL      the set. Default NetBSD 11.0 amd64 comp.tar.xz
#   ENGINE        podman or docker. Detected otherwise
#
# Exit codes: 0 the probe ran and printed what came back, 1 the guest did not
# boot or the set could not be prepared, 2 a prerequisite is missing.
#
# ⛔ Read the exit code from this process, unpiped.

set -eu

IMAGE="${1:-localhost/netbsd:build}"
COMP_URL="${COMP_URL:-https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0/amd64/binary/sets/comp.tar.xz}"

ENGINE="${ENGINE:-}"
if [ -z "$ENGINE" ]; then
  for e in podman docker; do
    if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
  done
fi
[ -n "$ENGINE" ] || { printf '47: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '47: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '47-comp-set-and-compile\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  comp      %s\n' "$COMP_URL"
printf '  budget    %ss for the compile\n' "${PROBE_FOR:-3600}"
printf '\n'

PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Give the guest the toolchain it is missing, then compile with it.

⛔ THIS WRAPS guest.qemu_argv RATHER THAN REBUILDING THE ARGUMENT LIST. Every
flag in that list is a measurement.
"""

import os
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

FOR = int(os.environ.get("PROBE_FOR") or "3600")
SPARE = "/scratch/comp.img"
MOUNT = "/probe"

T0 = time.monotonic()
FAILED = []


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def step(con, name, line, seconds, want_rc=0):
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
    original = guest.qemu_argv

    def qemu_argv(accel):
        return original(accel) + [
            "-drive", "if=none,file=%s,format=raw,id=comp0" % SPARE,
            "-device", "virtio-blk-device,drive=comp0",
        ]
    guest.qemu_argv = qemu_argv

    try:
        say("booting, with the comp set on a second disk")
        con, _accel, single_user = guest.boot("tcg")
        if con is None:
            say("the guest did not reach a shell")
            return 1
        guest.prepare_guest(con, single_user)

        # ⚠ PROBED, NOT ASSUMED. An extra drive enumerates before the root disk,
        # which 44 measured, so the device number is not a constant.
        guest.run_line(con, "mkdir -p %s" % MOUNT, 60)
        found = None
        for dev in ("/dev/ld0d", "/dev/ld1d", "/dev/ld2d"):
            _out, rc, timed_out = guest.run_line(
                con, "mount -t ext2fs %s %s 2>&1" % (dev, MOUNT), 90)
            if timed_out or rc != 0:
                continue
            _out, rc, timed_out = guest.run_line(
                con, "test -f %s/comp.tar.xz" % MOUNT, 60)
            if not timed_out and rc == 0:
                found = dev
                break
            guest.run_line(con, "umount %s" % MOUNT, 60)
        if found is None:
            say("⛔ the comp disk did not mount anywhere. Nothing else can run.")
            con.stop()
            return 1
        say("the comp set is on %s, mounted at %s" % (found, MOUNT))

        step(con, "what is missing before the set goes in",
             'ls /usr/include/sys/cdefs.h /usr/bin/as /usr/lib/libc.a 2>&1; true',
             120)

        # ⛔ INTO `/`, BECAUSE THAT IS WHERE A NetBSD SET UNPACKS. The sets are
        # root-relative tars; `comp` carries /usr/include, /usr/lib and the
        # toolchain binaries under /usr/bin.
        step(con, "extract the comp set",
             'cd / && S=$(date +%%s); tar xpf %s/comp.tar.xz; R=$?; '
             'E=$(date +%%s); echo "COMP rc=$R seconds=$((E-S))"; exit $R'
             % MOUNT, 1800)

        step(con, "what is there now",
             'ls -l /usr/include/sys/cdefs.h /usr/bin/as /usr/lib/libc.a', 120)

        step(con, "install gcc14 the way 46 does",
             'mkdir -p /usr/pkg && cd /usr/pkg && '
             'S=$(date +%s); tar xpf /guest-package.tgz; R=$?; E=$(date +%s); '
             'echo "EXTRACT rc=$R seconds=$((E-S))"; exit $R', 900)

        out = step(con, "read the package name",
                   'cd /usr/pkg && sed -n "s/^@name //p" +CONTENTS | head -1', 120)
        name = None
        for line in out or []:
            candidate = line.strip()
            if candidate and "@name" not in candidate:
                name = candidate
                break
        if name:
            step(con, "register it and run its +INSTALL",
                 'cd /usr/pkg && mkdir -p /var/db/pkg/%s && mv +* /var/db/pkg/%s/ && '
                 'cd /var/db/pkg/%s && sh ./+INSTALL %s POST-INSTALL && '
                 'pkg_info -e %s' % (name, name, name, name, name), 300)

        step(con, "space left before the compile", 'df -k / | tail -1', 120)

        # ⭐ PERF-01's guest side, the same line scripts/bench-compile runs
        # against the same bytes as the Linux side.
        step(con, "cc -O2 -c sqlite3.c, which is PERF-01",
             'S=$(date +%s); /usr/pkg/gcc14/bin/gcc -O2 -c /sqlite3.c -o /var/tmp/s.o; '
             'R=$?; E=$(date +%s); ls -l /var/tmp/s.o 2>&1; '
             'echo "BENCH rc=$R seconds=$((E-S))"; exit $R', FOR)

        guest.run_line(con, "umount %s" % MOUNT, 120)
        con.stop("halt -p")
        say("=== the result, as one line")
        print("RESULT compiled=%s failed=%s"
              % ("no" if FAILED else "yes", ",".join(FAILED) or "none"), flush=True)
        return 0
    finally:
        guest.qemu_argv = original


if __name__ == "__main__":
    sys.exit(main())
PROBE_PY
)

B64=$(printf '%s\n' "$PAYLOAD" | base64 | tr -d '\n')

# ⛔ THE SET IS FETCHED BY LINUX AND CARRIED IN ON A DISK, for the same reason
# images/netbsd/Containerfile fetches the package that way: through the guest's
# emulated network the same file took longer than everything else put together.
#
# ⚠ `mke2fs -d` populates a filesystem from a directory in one call, so nothing
# has to write 86 MB through debugfs a block at a time.
# shellcheck disable=SC2016
PREP='
set -e
mkdir -p /scratch /stage
apk add --no-cache curl e2fsprogs e2fsprogs-extra >/dev/null
curl -fsSL -o /stage/comp.tar.xz "$COMP_URL"
echo "the comp set is $(wc -c < /stage/comp.tar.xz) bytes"
truncate -s 256M /scratch/comp.img
mke2fs -q -F -O none -b 4096 -d /stage /scratch/comp.img
dumpe2fs -h /scratch/comp.img 2>/dev/null | grep -E "^(Block size|Free blocks)"
echo
printf %s "$PROBE_B64" | base64 -d > /probe.py
exec python3 -u /probe.py
'

# ⛔ MSYS REWRITES ANYTHING THAT LOOKS LIKE A PATH, INCLUDING `/bin/sh` HANDED
# TO --entrypoint. docs/conventions/shell.md section 7.
#
# ⛔ SC2016 IS DISABLED ON PURPOSE: `$PROBE_B64` and `$COMP_URL` have to reach
# the CONTAINER'S shell unexpanded and be read from its environment there.
rc=0
# shellcheck disable=SC2016
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  "$ENGINE" run --rm -i \
    --entrypoint /bin/sh \
    -e "PROBE_B64=$B64" \
    -e "COMP_URL=$COMP_URL" \
    -e "PROBE_FOR=${PROBE_FOR:-3600}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=none" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c "$PREP" \
  || rc=$?

printf '\n47: the container exited %s\n' "$rc"
exit "$rc"
