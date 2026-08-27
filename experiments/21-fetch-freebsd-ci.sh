#!/bin/sh
# 21-fetch-freebsd-ci.sh
#
# WHY. 30-boot-smolbsd.ps1 measured that a NetBSD SMOL kernel boots under WHPX
# but never finds its disk, because that kernel reaches virtio-mmio only
# through NetBSD's paravirtual bus and WHPX does not present one. A kernel with
# ordinary PCI and AHCI drivers does not have that dependency, and FreeBSD's
# BASIC-CI image is the smallest published one that needs no installer: it
# boots to a serial console, runs DHCP and grows its own filesystem.
#
# MEASURES. Whether the image is still published, its size, and whether the
# published SHA-256 verifies. Nothing here boots anything; 33-boot-freebsd-whpx.ps1
# consumes what this leaves behind.
#
# WHERE IT WRITES. ./.tmp/freebsd under the repository root, which .gitignore
# ignores. About 666 MB compressed and about 4 GB expanded.
#
# ⛔ THE FIRST-BOOT DOOR. This image's sshd accepts root with an EMPTY password
# on first boot. That is what makes it provisionable without an installer, and
# it is a door left open. 33-boot-freebsd-whpx.ps1 binds its forwarded port to
# 127.0.0.1 only and closes the empty-password login in the same step that uses
# it. Do not put this guest on a routable address before that has run.
#
# HOST. Any POSIX shell with curl, sha256sum and xz.
#
# EXIT. 0 fetched and verified, 1 a fetch or a digest failed, 2 a tool missing.

set -eu

REL="https://download.freebsd.org/releases/CI-IMAGES/15.1-RELEASE/amd64/Latest"
XZ="FreeBSD-15.1-RELEASE-amd64-BASIC-CI-ufs.raw.xz"
RAW="FreeBSD-15.1-RELEASE-amd64-BASIC-CI-ufs.raw"
SUMS="CHECKSUM.SHA256"

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
out="$root/.tmp/freebsd"

for t in curl sha256sum xz; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "FAIL: $t is required and is not on PATH" >&2
    exit 2
  fi
done

mkdir -p "$out"
# Native Windows binaries get a bare filename, never a path.
cd "$out"

if [ ! -s "$XZ" ]; then
  echo "fetch   $XZ  (about 666 MB)"
  # -C - resumes a partial file, because this is large enough to be
  # interrupted and re-running the whole fetch is 666 MB of nobody's time.
  # ⛔ `if ! cmd` and not `cmd; rc=$?`. Under `set -e` the second is
  # unreachable: the script exits before the guard can run.
  if ! curl -fL --retry 3 --retry-delay 5 --connect-timeout 20 -C - -o "$XZ" "$REL/$XZ"; then
    rc=$?
    echo "FAIL: curl exited $rc" >&2
    exit 1
  fi
else
  echo "have    $XZ"
fi

echo "fetch   $SUMS"
if ! curl -fsSL --retry 3 -o "$SUMS" "$REL/$SUMS"; then
  rc=$?
  echo "FAIL: curl exited $rc for $SUMS" >&2
  exit 1
fi

# The published file covers every image in the directory and uses BSD's
# "SHA256 (name) = digest" format, which sha256sum -c does not read. Pull the
# one line that names this artefact and compare it ourselves.
want=$(sed -n "s/^SHA256 (${XZ}) = //p" "$SUMS")
if [ -z "$want" ]; then
  echo "FAIL: $SUMS does not name $XZ" >&2
  exit 1
fi
got=$(sha256sum "$XZ" | cut -d' ' -f1)
echo "verify  $XZ"
if [ "$want" != "$got" ]; then
  echo "FAIL: digest mismatch for $XZ" >&2
  echo "  published $want" >&2
  echo "  computed  $got" >&2
  exit 1
fi
echo "        OK  $got"

if [ ! -s "$RAW" ]; then
  echo "expand  $XZ"
  if ! xz -dk "$XZ"; then
    rc=$?
    echo "FAIL: xz exited $rc" >&2
    exit 1
  fi
else
  echo "have    $RAW"
fi

echo
echo "RESULT"
for f in "$XZ" "$RAW"; do
  size=$(wc -c < "$f" | tr -d ' ')
  printf '  %-46s %12s bytes\n' "$f" "$size"
done
echo "  directory  $out"
echo "  image      verified against the published $SUMS"
exit 0
