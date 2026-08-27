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
# Usage:
#   sh grow-rootfs.sh IMAGE SIZE LABEL      e.g. rootfs.img 2G buildroot
#
# Needs: sgdisk, e2fsck, resize2fs, dd, truncate.
#
# Exit codes: 0 grown, 1 it did not grow, 2 a prerequisite is missing.

set -eu

IMG="${1:-}"
SIZE="${2:-}"
LABEL="${3:-}"

[ -n "$IMG" ] && [ -n "$SIZE" ] && [ -n "$LABEL" ] || {
  printf 'grow-rootfs: usage: grow-rootfs.sh IMAGE SIZE LABEL\n' >&2; exit 2; }
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
[ -n "$FIRST" ] && [ -n "$LAST" ] || {
  printf 'grow-rootfs: could not read the partition bounds back\n' >&2; exit 1; }

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
dd if=fs.tmp of="$IMG" bs=512 seek="$FIRST" conv=notrunc status=none
rm -f fs.tmp

after=$(wc -c < "$IMG")
printf 'grow-rootfs: %s is now %s bytes, partition %s spans %s to %s\n' \
  "$IMG" "$after" "$LABEL" "$FIRST" "$LAST"
[ "$after" -gt "$before" ] || {
  printf 'grow-rootfs: it did not grow\n' >&2; exit 1; }
exit 0
