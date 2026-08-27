#!/bin/sh
# 20-fetch-smolbsd.sh
#
# WHY. The shortest published path from nothing to a BSD kernel running on a
# host's own hypervisor. smolBSD releases a NetBSD rescue root filesystem and
# smolbsd.org serves the matching SMOL kernel, so a boot needs no build, no
# installer and no ISO. 30-boot-smolbsd.ps1 is what consumes these two files.
#
# MEASURES. Whether the two artefacts are still published, what they actually
# weigh, and whether the release checksum verifies. Nothing here boots anything.
#
# WHERE IT WRITES. ./.tmp/smolbsd under the repository root, which .gitignore
# ignores. The artefacts are re-fetchable from the URLs below and are not
# committed.
#
# HOST. Any POSIX shell with curl, sha256sum and xz. Run on the Windows host
# under Git Bash for 30-boot-smolbsd.ps1, or inside Linux for 31.
#
# EXIT. 0 both artefacts present and verified, 1 a fetch or a digest failed,
# 2 a required tool is missing.

set -eu

REL="https://github.com/NetBSDfr/smolBSD/releases/download/latest"
KERNEL_URL="https://smolbsd.org/assets/netbsd-SMOL"
IMG_XZ="rescue-amd64.img.xz"
IMG="rescue-amd64.img"
KERNEL="netbsd-SMOL"

# The repository root, so the script runs the same from anywhere.
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
out="$root/.tmp/smolbsd"

for t in curl sha256sum xz; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "FAIL: $t is required and is not on PATH" >&2
    exit 2
  fi
done

mkdir -p "$out"
# Native Windows binaries get a bare filename, never a path: a Git Bash path
# handed to a native curl fails naming neither the path nor the cause.
# HISTORY/poc.md section 7.
cd "$out"

fetch() {
  # $1 url, $2 filename. Skips a file that is already here and non-empty,
  # because this script is run repeatedly while 30 is being debugged.
  if [ -s "$2" ]; then
    echo "have    $2"
    return 0
  fi
  echo "fetch   $2"
  # ⛔ `if ! cmd` and not `cmd; rc=$?`. Under `set -e` the second is
  # unreachable: a failing curl exits the script before the test runs, so the
  # partial file is never removed and the message is never printed.
  if ! curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1"; then
    rc=$?
    echo "FAIL: curl exited $rc for $1" >&2
    rm -f "$2"
    exit 1
  fi
}

fetch "$REL/$IMG_XZ" "$IMG_XZ"
fetch "$REL/$IMG_XZ.sha256" "$IMG_XZ.sha256"
fetch "$KERNEL_URL" "$KERNEL"

# The published digest file names the artefact, so sha256sum -c reads it
# directly. Exit code read from sha256sum itself, not through a pipe.
echo "verify  $IMG_XZ"
if ! sha256sum -c "$IMG_XZ.sha256"; then
  echo "FAIL: published digest does not match $IMG_XZ" >&2
  exit 1
fi

if [ ! -s "$IMG" ]; then
  echo "expand  $IMG_XZ"
  # -k keeps the compressed copy so a re-run does not re-download.
  if ! xz -dk "$IMG_XZ"; then
    rc=$?
    echo "FAIL: xz exited $rc" >&2
    exit 1
  fi
else
  echo "have    $IMG"
fi

# The kernel has no published digest, so record what arrived rather than
# claiming it was verified.
echo
echo "RESULT"
for f in "$IMG_XZ" "$IMG" "$KERNEL"; do
  size=$(wc -c < "$f" | tr -d ' ')
  digest=$(sha256sum "$f" | cut -d' ' -f1)
  printf '  %-22s %10s bytes  sha256 %s\n' "$f" "$size" "$digest"
done
echo
echo "  directory  $out"
echo "  image      verified against the published .sha256"
echo "  kernel     NO published digest, so integrity is unverified"
exit 0
