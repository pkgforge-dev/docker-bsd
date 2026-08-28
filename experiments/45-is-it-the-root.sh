#!/bin/sh
# 45-is-it-the-root.sh - the shipped filesystem's own bytes, mounted as DATA.
#
# ⛔ WHY IT EXISTS, AND IT IS BECAUSE 44 KILLED THE HYPOTHESIS IT WAS WRITTEN
# FOR. [44-block-size-control.sh](44-block-size-control.sh) extracted the same
# 490 MB onto two fresh ext2 filesystems that differed only in `-b`, at the same
# 2 GB size, with the same `-O none` and the same inode density the shipped root
# has. ⭐ BOTH FINISHED, in tens of seconds, and one of them had the 1 KB blocks
# this repository was about to rebuild away from. So `mke2fs -b 4096` would have
# "worked" and would have been the ninth guess.
#
# ⛔ SO THE 1 KB BLOCK SIZE IS NOT THE LEVER, and what is left is the list of
# things the shipped root has that a fresh filesystem on a second disk does not:
#
#   1. it is the bytes upstream published, then GROWN by `resize2fs` from the
#      size `mke2fs` made it to 2 GB, with no `resize_inode` feature to grow
#      into;
#   2. it is `/`, mounted by the kernel at boot and then remounted read-write
#      by `mount -u -w /` because this guest stops in single user mode;
#   3. it is reached through a `dk` WEDGE on a GPT disk, not a raw disk;
#   4. the archive being unpacked is READ from the same filesystem it is
#      written to.
#
# ⭐ THREE CASES, AND EACH TURNS ONE OF THOSE OFF:
#
#   raw    the shipped root's ext2 partition, `dd` out of the image this
#          container ships and attached as an ordinary second disk. ⛔ Same
#          bytes, same geometry, same history: it was grown by the same
#          resize2fs. It is simply not `/`, not a wedge, and not what the
#          archive is read from.
#   self   the same disk, with the archive copied ONTO it first and unpacked in
#          place, so one filesystem carries both the read and the write. ⚠ That
#          is condition 4 on its own.
#   root   the reference. `tar` into `/var/tmp` on the real root, which is the
#          run `INF-09` recorded as not finishing in 900 s. ⛔ It is here so
#          that a session reading this cannot ask whether the fault still
#          reproduces on the day the other cases were taken.
#
# ⛔ `root` RUNS LAST AND THAT IS NOT AN ORDERING PREFERENCE. `INF-09` measured
# that the guest's whole userland stops being scheduled during that write, so
# the case that hangs has to be the one with nothing after it.
#
# ⛔ WHAT EACH OUTCOME MEANS, WRITTEN BEFORE IT IS RUN:
#
#   raw finishes, root does not     ⭐ the filesystem's own bytes are exonerated
#                                   and it is about being the root. The fix is
#                                   not a filesystem rebuild at all.
#   raw does not finish             ⭐ it IS this filesystem rather than a 1 KB
#                                   one, so what `resize2fs` did to it is the
#                                   next question, and 44 already proved a fresh
#                                   1 KB filesystem is fine.
#   self differs from raw           ⛔ it is the read and the write sharing one
#                                   filesystem, which is a fifth thing and none
#                                   of the four above.
#
# ⚠ WHAT THIS DOES NOT READ. Which loop inside NetBSD's `ext2fs` is spinning.
# `INF-09` has published an invented mechanism twice; this is a control.
#
# ── ⭐ WHAT IT FOUND, 2026-08-28. ALL THREE FINISHED ───────────────────────
#
#   RESULT case=raw  finished=yes    34 s
#   RESULT case=self finished=yes    34 s
#   RESULT case=root finished=yes    35 s
#
# ⛔ THE REFERENCE IS THE FINDING. `root` is the exact run `INF-09` recorded
# as still going after 900 seconds, and it finished in 35. So the filesystem
# is exonerated and so is the reading that convicted it.
# ⭐ `pkg_add` on the same archive still does not finish, which is what is
# left. ../HISTORY/inf-09.md carries the wording that was withdrawn.
#
# Usage:
#   sh experiments/45-is-it-the-root.sh [IMAGE]
#
# Environment:
#   PROBE_FOR     seconds to allow each extraction. Default 900
#   PROBE_CASES   which to run, in order. Default `raw self root`
#   PROBE_TAR     what to extract. Default /guest-package.tgz
#   ENGINE        podman or docker. Detected otherwise
#
# Exit codes: 0 the control ran and printed what came back, 1 it could not boot
# the guest or could not prepare the disk, 2 a prerequisite is missing.
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
[ -n "$ENGINE" ] || { printf '45: neither podman nor docker is on PATH\n' >&2; exit 2; }

command -v base64 >/dev/null 2>&1 || {
  printf '45: base64 is not on PATH, and the payload travels as base64\n' >&2; exit 2; }

printf '45-is-it-the-root\n'
printf '  engine    %s\n' "$ENGINE"
printf '  image     %s\n' "$IMAGE"
printf '  cases     %s\n' "${PROBE_CASES:-raw self root}"
printf '  budget    %ss each\n' "${PROBE_FOR:-900}"
printf '\n'

PAYLOAD=$(cat <<'PROBE_PY'
#!/usr/bin/env python3
"""Unpack the same archive onto the shipped root filesystem's own bytes, once
as an ordinary data disk and once as the root, and time both.

⛔ THIS WRAPS guest.qemu_argv RATHER THAN REBUILDING THE ARGUMENT LIST. Every
flag in that list is a measurement.
"""

import os
import sys
import time

sys.path.insert(0, "/opt/bsd")
import guest  # noqa: E402

FOR = int(os.environ.get("PROBE_FOR") or "900")
TAR = os.environ.get("PROBE_TAR") or "/guest-package.tgz"
CASES = (os.environ.get("PROBE_CASES") or "raw self root").split()

SPARE = "/scratch/shipped.img"
MOUNT = "/probe"
T0 = time.monotonic()


def say(*parts):
    print("%7.1f " % (time.monotonic() - T0), *parts, flush=True)


def with_disk(path):
    """Attach one extra raw disk, and change nothing else.

    ⚠ MEASURED 2026-08-28 by 44: an extra drive enumerates BEFORE the root
    disk, so the root's own disk moves from `ld0` to `ld1`. Nothing breaks,
    because the kernel finds its root by GPT label rather than by device
    number, and a probe that hardcoded a device number would read the wrong
    disk.
    """
    original = guest.qemu_argv

    def qemu_argv(accel):
        return original(accel) + [
            "-drive", "if=none,file=%s,format=raw,id=probe0" % path,
            "-device", "virtio-blk-device,drive=probe0",
        ]
    return original, qemu_argv


def mount_spare(con):
    """Mount the copy of the shipped filesystem, wherever it landed.

    ⛔ PROBED, NOT ASSUMED, AND THE MARKER IS WHY. This guest has a 2 GB ext2 of
    its own and the copy is byte-for-byte the same filesystem, so "it mounted"
    is not evidence it is the right one. A file written from Linux before boot
    is.
    """
    guest.run_line(con, "mkdir -p %s" % MOUNT, 60)
    for dev in ("/dev/ld0d", "/dev/ld1d", "/dev/ld2d"):
        _out, rc, timed_out = guest.run_line(
            con, "mount -t ext2fs %s %s 2>&1" % (dev, MOUNT), 90)
        if timed_out or rc != 0:
            continue
        _out, rc, timed_out = guest.run_line(
            con, "ls -a %s | grep probe-shipped" % MOUNT, 60)
        if not timed_out and rc == 0:
            return dev
        guest.run_line(con, "umount %s" % MOUNT, 60)
    return None


def timed(con, case, line):
    """Run one self-timing line and say what came back, or that nothing did."""
    say("%s: %s" % (case, line))
    started = time.monotonic()
    out, rc, timed_out = guest.run_line(con, line, FOR)
    wall = time.monotonic() - started
    if timed_out:
        say("⛔ %s: NOTHING CAME BACK IN %ss. Wall %.1fs." % (case, FOR, wall))
        for chunk in out:
            print(chunk, flush=True)
        return False
    say("⭐ %s: finished. rc=%s wall=%.1fs" % (case, rc, wall))
    for line_out in out:
        print("    " + line_out, flush=True)
    return rc == 0


def extract_line(archive, dest):
    return ('S=$(date +%%s); tar xpf %s -C %s; R=$?; E=$(date +%%s); '
            'echo "EXTRACT rc=$R seconds=$((E-S))"' % (archive, dest))


def one_case(case):
    """Boot a guest for this case, run it, and report."""
    attach = case in ("raw", "self")
    say("=== %s: booting%s" % (case, ", with %s attached" % SPARE if attach else ""))

    original = guest.qemu_argv
    if attach:
        original, wrapped = with_disk(SPARE)
        guest.qemu_argv = wrapped
    try:
        con, _accel, single_user = guest.boot("tcg")
        if con is None:
            say("%s: the guest did not reach a shell" % case)
            return False
        guest.prepare_guest(con, single_user)

        if case == "root":
            # ⛔ THE REFERENCE, AND IT IS THE EXACT LINE 43 RECORDED. The
            # destination is the root filesystem this image ships and boots.
            ok = timed(con, case, extract_line(TAR, "/var/tmp"))
            if ok:
                timed(con, case, "df -k / && find /var/tmp -type f | wc -l")
            con.stop()
            return ok

        dev = mount_spare(con)
        if dev is None:
            say("⛔ %s: the copy did not mount anywhere. The case cannot run."
                % case)
            con.stop()
            return False
        say("%s: %s is mounted at %s" % (case, dev, MOUNT))

        if case == "self":
            # ⚠ COPIED FIRST, SO ONE FILESYSTEM CARRIES BOTH SIDES. The copy is
            # timed separately: it is 107 MB of sequential write and it is not
            # the thing under test.
            if not timed(con, case,
                         'S=$(date +%s); cp /guest-package.tgz /probe/pkg.tgz; '
                         'R=$?; E=$(date +%s); '
                         'echo "COPY rc=$R seconds=$((E-S))"'):
                con.stop()
                return False
            ok = timed(con, case,
                       extract_line("%s/pkg.tgz" % MOUNT, MOUNT))
        else:
            ok = timed(con, case, extract_line(TAR, MOUNT))

        if ok:
            timed(con, case, "df -k %s && find %s -type f | wc -l"
                  % (MOUNT, MOUNT))
            guest.run_line(con, "umount %s" % MOUNT, 120)
        con.stop("halt -p" if ok else None)
        return ok
    finally:
        guest.qemu_argv = original


def main():
    say("cases %s, budget %ss each, archive %s" % (" ".join(CASES), FOR, TAR))
    finished = {}
    for case in CASES:
        finished[case] = one_case(case)
        # ⛔ EACH CASE GETS ITS OWN COPY OR THE SECOND ONE IS NOT A CONTROL.
        # `raw` leaves 490 MB in the copy's root directory, and `self` would
        # then be unpacking over files that are already there.
        if case == "raw" and "self" in CASES:
            say("restoring a clean copy for the next case")
            os.system("dd if=/scratch/pristine.img of=%s bs=1M status=none"
                      % SPARE)

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

# ⛔ THE PARTITION IS CUT OUT OF THE IMAGE THIS CONTAINER SHIPS, WITH THE SAME
# METHOD images/netbsd/grow-rootfs.sh USES, and for the same reason: a
# filesystem that starts a megabyte into a disk cannot be handed to a tool that
# expects one at offset 0, and a loop device with an offset needs a privilege a
# container does not have.
#
# ⚠ `sgdisk -i 1` IS READ RATHER THAN ASSUMED. The offset is 2048 sectors on
# the image built today and that is a fact about today's image, not a constant.
# shellcheck disable=SC2016
PREP='
set -e
mkdir -p /scratch
apk add --no-cache e2fsprogs e2fsprogs-extra sgdisk >/dev/null
FIRST=$(sgdisk -i 1 /guest/rootfs.img | sed -n "s/^First sector: \([0-9]*\).*/\1/p")
LAST=$(sgdisk -i 1 /guest/rootfs.img | sed -n "s/^Last sector: \([0-9]*\).*/\1/p")
if [ -z "$FIRST" ] || [ -z "$LAST" ]; then
  echo "45: could not read the partition bounds out of /guest/rootfs.img" >&2
  exit 1
fi
echo "the shipped root: partition 1 spans sector $FIRST to $LAST"
dd if=/guest/rootfs.img of=/scratch/shipped.img bs=512 skip="$FIRST" \
   count=$((LAST - FIRST + 1)) status=none
echo "--- /scratch/shipped.img, as dumpe2fs reads it back"
dumpe2fs -h /scratch/shipped.img 2>/dev/null \
  | grep -E "^(Filesystem features|Filesystem state|Block count|Block size|Inode count|Blocks per group|Free blocks|Free inodes)"
: > /tmp/probe-shipped
debugfs -w -R "write /tmp/probe-shipped probe-shipped" /scratch/shipped.img >/dev/null 2>&1
debugfs -R "stat probe-shipped" /scratch/shipped.img 2>/dev/null | grep -q "Inode:" \
  || { echo "45: the marker did not land in the copy" >&2; exit 1; }
cp /scratch/shipped.img /scratch/pristine.img
echo
printf %s "$PROBE_B64" | base64 -d > /probe.py
exec python3 -u /probe.py
'

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
    -e "PROBE_FOR=${PROBE_FOR:-900}" \
    -e "PROBE_CASES=${PROBE_CASES:-raw self root}" \
    -e "PROBE_TAR=${PROBE_TAR:-/guest-package.tgz}" \
    -e "BSD_MEM=${BSD_MEM:-1024}" \
    -e "BSD_NET=none" \
    -e "BSD_BOOT_TIMEOUT=600" \
    "$IMAGE" \
    -c "$PREP" \
  || rc=$?

printf '\n45: the container exited %s\n' "$rc"
exit "$rc"
