#!/bin/sh
# 44-block-size-control.sh - is the BLOCK SIZE the lever, or is that guess nine?
#
# ⛔ WHY IT EXISTS. `INF-09` measured that the DESTINATION FILESYSTEM decides
# whether a 490 MB write finishes: the same `tar`, the same bytes, the same
# guest, onto the ext2 root does not finish in 900 s and into a tmpfs does.
# ⭐ Then the fourth reference sweep found `mkimg.sh:155`, where smolBSD writes
# `mke2fs -O none` because its BUILD HOST is Linux, and this repository ships
# that builder image as its runtime root and grows it with `resize2fs`, which
# cannot change a block size. So the root is 1 KB blocks over 2 GB.
#
# ⛔ THAT IS A NARROWING AND NOT A MECHANISM, AND EIGHT EXPLANATIONS ARE ALREADY
# DEAD HERE. `tmpfs` differs from the root in the block size, in being a
# different filesystem type, in being memory, in being empty, and in not being
# `/`. ⚠ A fix built on "it must be the block size" would be the ninth guess,
# and the entry says in as many words: prove the block size is the lever BEFORE
# rebuilding anything.
#
# ⭐ SO THIS VARIES ONE THING. Two scratch disks, made by the same `mke2fs` on
# the same Linux, in the same container, at the SAME SIZE, with the same
# `-O none` upstream uses and the same inode density the shipped root has.
# ⛔ The only argument that differs between them is `-b`.
#
#   /dev/ld?d   ext2, -O none, -b 1024   the geometry this repository ships
#   /dev/ld?d   ext2, -O none, -b 4096   what mke2fs makes at this size
#
# ⛔ ONE BOOT PER DESTINATION, AND THAT IS NOT TIDINESS. Extracting half a
# gigabyte leaves the guest's 1 GB of RAM full of page cache, and a second
# extraction in the same boot would be charged for the first one's eviction.
# ⚠ Each case gets a guest that has just booted and a disk nothing has touched.
#
# ⭐ THE 4 KB CASE RUNS FIRST, ON PURPOSE. `INF-09` measured that the guest's
# whole userland stops being scheduled during the slow write, so a case that
# does not finish takes the rest of the run with it. The case under suspicion
# goes last so that the other one has already reported.
#
# ⛔ WHAT EACH OUTCOME MEANS, WRITTEN DOWN BEFORE IT IS RUN, so the result is
# read rather than fitted:
#
#   4k finishes, 1k does not     ⭐ the block size is the lever. `mke2fs -b 4096`
#                                is the fix and it is understood.
#   both finish                  ⛔ the block size is NOT the lever on its own,
#                                and what the root has that a fresh filesystem
#                                does not is the next question.
#   neither finishes             ⛔ it is not the block size at all. Guess nine
#                                dies here rather than in a rebuild.
#
# ⚠ WHAT THIS STILL DOES NOT READ. Which loop inside NetBSD's `ext2fs` is
# spinning. This is a control, not a mechanism, and `INF-09` says so.
#
# Usage:
#   sh experiments/44-block-size-control.sh [IMAGE]
#
# Environment:
#   PROBE_FOR     seconds to allow each extraction. Default 900
#   PROBE_SIZE    each scratch disk. Default 2G, the size the root is grown to
#   PROBE_CASES   which to run, in order. Default `4k 1k`
#   PROBE_TAR     what to extract. Default /guest-package.tgz
#   ENGINE        podman or docker. Detected otherwise
#
# Exit codes: 0 the control ran and printed what came back, 1 it could not boot
# the guest or could not prepare a disk, 2 a prerequisite is missing.
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
[ -n "$ENGINE" ] || { printf '44: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '44: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '44-block-size-control\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  cases     %s\n' "${PROBE_CASES:-4k 1k}"
printf '  budget    %ss each\n' "${PROBE_FOR:-900}"
printf '  disks     %s each, ext2, -O none, one -b apart\n' "${PROBE_SIZE:-2G}"
printf '\n'

PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Extract the same archive onto two ext2 filesystems that differ only in block
size, one freshly booted guest each, and time both.

⛔ THIS WRAPS guest.qemu_argv RATHER THAN REBUILDING THE ARGUMENT LIST. Every
flag in that list is a measurement and this experiment has no business
restating any of them; it appends one drive and changes nothing else.
"""

import os
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

FOR = int(os.environ.get("PROBE_FOR") or "900")
TAR = os.environ.get("PROBE_TAR") or "/guest-package.tgz"
CASES = (os.environ.get("PROBE_CASES") or "4k 1k").split()

MOUNT = "/probe"
T0 = time.monotonic()


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def with_disk(path):
    """Attach one extra raw disk, and nothing else.

    ⚠ MEASURED 2026-08-28: the extra drives enumerate BEFORE the root disk.
    With two attached, the root's own disk arrived as `ld2` and the scratch
    ones as `ld0` and `ld1`. ⛔ Nothing breaks, because the kernel is told
    `root=NAME=buildroot` and finds its wedge by GPT label rather than by
    device number, but a probe that hardcoded `ld1` would read the wrong disk.
    """
    original = guest.qemu_argv

    def qemu_argv(accel):
        return original(accel) + [
            "-drive", "if=none,file=%s,format=raw,id=probe0" % path,
            "-device", "virtio-blk-device,drive=probe0",
        ]
    return original, qemu_argv


def find_disk(con, marker):
    """Mount the scratch disk, wherever the guest decided to put it.

    ⛔ PROBED, NOT ASSUMED, AND THE MARKER IS WHY. Mounting something is not
    evidence it is the right something: this guest has a 2 GB ext2 of its own
    and the whole experiment is about telling two ext2 filesystems apart.
    ⭐ Each disk carries a file named for the block size it was made with,
    written from Linux by `debugfs` before the guest ever saw it.
    """
    guest.run_line(con, "mkdir -p %s" % MOUNT, 60)
    for dev in ("/dev/ld0d", "/dev/ld1d", "/dev/ld2d"):
        out, rc, timed_out = guest.run_line(
            con, "mount -t ext2fs %s %s 2>&1" % (dev, MOUNT), 90)
        if timed_out or rc != 0:
            continue
        out, rc, timed_out = guest.run_line(
            con, "ls -a %s | grep %s" % (MOUNT, marker), 60)
        if not timed_out and rc == 0:
            return dev
        guest.run_line(con, "umount %s" % MOUNT, 60)
    return None


def one_case(case):
    """Boot a guest, mount that case's disk, extract, and say what happened."""
    marker = "probe-%s" % case
    path = "/scratch/%s.img" % case

    say("=== %s: booting a guest with %s attached" % (case, path))
    original, wrapped = with_disk(path)
    guest.qemu_argv = wrapped
    try:
        con, accel, single_user = guest.boot("tcg")
        if con is None:
            say("%s: the guest did not reach a shell" % case)
            return False
        guest.prepare_guest(con, single_user)

        dev = find_disk(con, marker)
        if dev is None:
            say("⛔ %s: the scratch disk did not mount anywhere. "
                "The case cannot run." % case)
            con.stop("halt -p")
            return False
        say("%s: %s is mounted at %s" % (case, dev, MOUNT))

        # ⚠ THE SAME LINE ON BOTH CASES AND THE SAME LINE `INF-09` RECORDED,
        # give or take where it lands. `tar` does no bookkeeping at all, which
        # is what exonerated `pkg_add`.
        line = ('S=$(date +%%s); tar xpf %s -C %s; R=$?; E=$(date +%%s); '
                'echo "EXTRACT rc=$R seconds=$((E-S))"' % (TAR, MOUNT))
        say("%s: %s" % (case, line))
        started = time.monotonic()
        out, rc, timed_out = guest.run_line(con, line, FOR)
        wall = time.monotonic() - started

        if timed_out:
            say("⛔ %s: NOTHING CAME BACK IN %ss. Wall %.1fs."
                % (case, FOR, wall))
            say("%s: the tail of the console follows" % case)
            for chunk in out:
                print(chunk, flush=True)
            con.stop()
            return False

        say("⭐ %s: finished. rc=%s wall=%.1fs" % (case, rc, wall))
        for line_out in out:
            print("    " + line_out, flush=True)

        for after in ("df -k %s" % MOUNT,
                      "find %s -type f | wc -l" % MOUNT):
            out, rc, timed_out = guest.run_line(con, after, 300)
            say("%s: %s -> rc=%s%s"
                % (case, after, rc, " TIMED OUT" if timed_out else ""))
            for line_out in out:
                print("    " + line_out, flush=True)

        guest.run_line(con, "umount %s" % MOUNT, 120)
        con.stop("halt -p")
        return True
    finally:
        guest.qemu_argv = original


def main():
    say("cases %s, budget %ss each, archive %s" % (" ".join(CASES), FOR, TAR))
    finished = {}
    for case in CASES:
        finished[case] = one_case(case)

    say("=== the control, as one line per case")
    for case in CASES:
        print("RESULT case=%s finished=%s"
              % (case, "yes" if finished[case] else "no"), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
PROBE_PY
)

B64=$(printf '%s\n' "$PAYLOAD" | base64 | tr -d '\n')

# ⛔ THE DISKS ARE MADE BY LINUX, IN THE CONTAINER, AND READ BACK BEFORE THE
# GUEST SEES THEM. `dumpe2fs` is what says what was actually made; the
# arguments passed to `mke2fs` are what was asked for, and those are not the
# same claim. ⚠ `e2fsprogs-extra` is where `dumpe2fs` lives on Alpine, and
# leaving it out is how the first draft of this file exited 1 with no message.
#
# ⚠ `-i 4096` ON BOTH. The shipped root has 522,240 inodes over 2,096,108
# blocks, which is one inode per 4 KB. mke2fs would otherwise pick a different
# density for each block size, and this control has exactly one variable.
# shellcheck disable=SC2016
PREP='
set -e
mkdir -p /scratch
apk add --no-cache e2fsprogs e2fsprogs-extra >/dev/null
for c in 1k 4k; do
  case "$c" in
    1k) b=1024 ;;
    4k) b=4096 ;;
  esac
  truncate -s "$PROBE_SIZE" "/scratch/$c.img"
  mke2fs -q -F -O none -b "$b" -i 4096 "/scratch/$c.img"
  : > "/tmp/probe-$c"
  debugfs -w -R "write /tmp/probe-$c probe-$c" "/scratch/$c.img" >/dev/null 2>&1
  echo "--- /scratch/$c.img, as dumpe2fs reads it back"
  dumpe2fs -h "/scratch/$c.img" 2>/dev/null \
    | grep -E "^(Filesystem features|Block count|Block size|Inode count|Blocks per group)"
  debugfs -R "stat probe-$c" "/scratch/$c.img" 2>/dev/null | grep -q "Inode:" \
    || { echo "44: the marker did not land in $c" >&2; exit 1; }
done
echo
printf %s "$PROBE_B64" | base64 -d > /probe.py
exec python3 -u /probe.py
'

# ⛔ MSYS REWRITES ANYTHING THAT LOOKS LIKE A PATH, INCLUDING `/bin/sh` HANDED
# TO --entrypoint. docs/conventions/shell.md section 7.
#
# ⛔ SC2016 IS DISABLED ON PURPOSE: `$PROBE_B64` and `$PROBE_SIZE` have to reach
# the CONTAINER'S shell unexpanded and be read from its environment there.
rc=0
# shellcheck disable=SC2016
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
  "$ENGINE" run --rm -i \
    --entrypoint /bin/sh \
    -e "PROBE_B64=$B64" \
    -e "PROBE_SIZE=${PROBE_SIZE:-2G}" \
    -e "PROBE_FOR=${PROBE_FOR:-900}" \
    -e "PROBE_CASES=${PROBE_CASES:-4k 1k}" \
    -e "PROBE_TAR=${PROBE_TAR:-/guest-package.tgz}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=none" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c "$PREP" \
  || rc=$?

printf '\n44: the container exited %s\n' "$rc"
exit "$rc"
