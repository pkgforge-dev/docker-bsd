#!/bin/sh
# grow-rootfs.sh - make the guest's root filesystem bigger, from Linux.
#
# ⭐ THE FILESYSTEM IS ext2, NOT FFS, AND THAT IS THE WHOLE REASON THIS WORKS.
# Measured 2026-08-27 by reading `mount` in the guest: `/dev/dk0 on / type
# ext2fs`. A BSD root filesystem would have to be grown from inside a booted
# BSD, which means an emulator run per resize. An ext2 one is grown by the
# ordinary Linux tools, in a build step, with no guest involved at all.
#
# ⛔ WHY IT IS NEEDED, MEASURED RATHER THAN ASSUMED. The published build
# userland has 201 MB free. `pkg_add gcc14` fills it and stops at 106 percent
# with `uid 0 on /: file system full`, leaving a package database that cannot
# be opened. A development environment that cannot hold a compiler is not one.
#
# ⚠ THE PARTITION NAME IS THE BOOT ARGUMENT. The kernel is told
# `root=NAME=buildroot` and resolves that against the GPT partition label. This
# script recreates partition 1 to reach the end of the grown disk and MUST set
# the same name back, or the next boot is a kernel that never finds its disk.
#
# ⛔ e2fsck RUNS BEFORE resize2fs AND THAT IS NOT OPTIONAL. resize2fs refuses an
# unchecked filesystem, and the refusal is the useful behaviour: growing a
# filesystem whose state is unknown is how a corrupt image is made bigger.
#
# ⭐ IT ALSO PUTS FILES INSIDE, AND THAT IS NOT A SIDE ERRAND. The filesystem
# is already extracted at that moment, so writing into it costs one debugfs
# call each and no second extract. The alternative measured on 2026-08-27 was
# letting the GUEST download the same file through its emulated network stack,
# which took longer than every other step in the build put together and did not
# finish inside a runner's hour.
#
# Usage:
#   sh grow-rootfs.sh IMAGE SIZE LABEL [DIR]
#   e.g. rootfs.img 2G buildroot /inject
#
# ⚠ DIR is a DIRECTORY and every ordinary file directly inside it is written
# into the guest's root. A single file argument was the first shape and it did
# not survive the second thing that needed carrying in.
#
# Needs: sgdisk, e2fsck, resize2fs, dd, truncate, and debugfs for the files.
#
# Exit codes: 0 grown, 1 it did not grow, 2 a prerequisite is missing.

set -eu

IMG="${1:-}"
SIZE="${2:-}"
LABEL="${3:-}"
INJECT="${4:-}"   # a directory, or empty

# ⚠ Written out rather than `A && B || C`, which is not if-then-else: the C
# branch also runs when B fails. tests/run.sh carries the same note.
if [ -z "$IMG" ] || [ -z "$SIZE" ] || [ -z "$LABEL" ]; then
  printf 'grow-rootfs: usage: grow-rootfs.sh IMAGE SIZE LABEL [DIR]\n' >&2
  exit 2
fi
[ -f "$IMG" ] || { printf 'grow-rootfs: no such image: %s\n' "$IMG" >&2; exit 2; }

for t in sgdisk e2fsck resize2fs dd truncate; do
  command -v "$t" >/dev/null 2>&1 || {
    printf 'grow-rootfs: %s is not on PATH\n' "$t" >&2; exit 2; }
done

before=$(wc -c < "$IMG")
printf 'grow-rootfs: %s is %s bytes, growing to %s\n' "$IMG" "$before" "$SIZE"

truncate -s "$SIZE" "$IMG"

# ⚠ The backup GPT header is at the OLD end of the disk and is now in the
# middle of it. `sgdisk -e` moves it, and every later call would otherwise warn
# about a header it can still read but no longer believes.
sgdisk -e "$IMG" >/dev/null 2>&1 || true

# Recreate the one partition so it reaches the end, keeping its name.
sgdisk -d 1 -n "1:2048:0" -c "1:$LABEL" -t 1:8300 "$IMG" >/dev/null

FIRST=$(sgdisk -i 1 "$IMG" | sed -n 's/^First sector: \([0-9]*\).*/\1/p')
LAST=$(sgdisk -i 1 "$IMG" | sed -n 's/^Last sector: \([0-9]*\).*/\1/p')
if [ -z "$FIRST" ] || [ -z "$LAST" ]; then
  printf 'grow-rootfs: could not read the partition bounds back\n' >&2
  exit 1
fi

NAME=$(sgdisk -i 1 "$IMG" | sed -n "s/^Partition name: '\(.*\)'/\1/p")
[ "$NAME" = "$LABEL" ] || {
  printf 'grow-rootfs: the partition is named %s and must be %s\n' "$NAME" "$LABEL" >&2
  exit 1; }

# ⚠ EXTRACTED AND PUT BACK RATHER THAN RESIZED IN PLACE. resize2fs works on a
# filesystem at the start of what it is given, and this one starts a megabyte
# in. A loop device with an offset would do it and needs a privilege a build
# does not have.
COUNT=$((LAST - FIRST + 1))
dd if="$IMG" of=fs.tmp bs=512 skip="$FIRST" count="$COUNT" status=none
e2fsck -fy fs.tmp >/dev/null 2>&1 || true
resize2fs fs.tmp

# ⛔ WRITTEN IN, THEN READ BACK. debugfs reports most failures on stderr and
# still exits 0, so its exit code is not evidence. The `stat` afterwards is:
# if the file is not there, this stops rather than shipping an image whose
# provisioning step will fail later for a reason nobody will connect to here.
if [ -n "$INJECT" ]; then
  command -v debugfs >/dev/null 2>&1 || {
    printf 'grow-rootfs: debugfs is not on PATH and files were asked for\n' >&2
    exit 2; }
  [ -d "$INJECT" ] || {
    printf 'grow-rootfs: not a directory: %s\n' "$INJECT" >&2; exit 2; }
  for f in "$INJECT"/*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    debugfs -w -R "write $f $base" fs.tmp >/dev/null 2>&1 || true
    if ! debugfs -R "stat $base" fs.tmp 2>/dev/null | grep -q 'Inode:'; then
      printf 'grow-rootfs: %s did not appear inside the filesystem\n' "$base" >&2
      exit 1
    fi
    printf 'grow-rootfs: wrote %s into the guest root\n' "$base"
  done
fi

dd if=fs.tmp of="$IMG" bs=512 seek="$FIRST" conv=notrunc status=none
rm -f fs.tmp

after=$(wc -c < "$IMG")
printf 'grow-rootfs: %s is now %s bytes, partition %s spans %s to %s\n' \
  "$IMG" "$after" "$LABEL" "$FIRST" "$LAST"
[ "$after" -gt "$before" ] || {
  printf 'grow-rootfs: it did not grow\n' >&2; exit 1; }
exit 0
