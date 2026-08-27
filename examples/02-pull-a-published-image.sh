#!/bin/sh
# 02-pull-a-published-image.sh
#
# Pulls one of the images this repository publishes and reads back what it
# actually declares, rather than what its name suggests.
#
# NEEDS:  podman or docker, and a network.
# COSTS:  tens of megabytes, depending on the BSD and the variant.
# GIVES:  the image's own os/architecture, printed.
#
# ⛔ IT DOES NOT RUN THE IMAGE. On a Linux host that exits 139, a SIGSEGV, and
# README.md explains why no flag reaches it. Use example 01 for a shell.
#
# ⛔ AND IT REMOVES THE IMAGE AFTERWARDS, on purpose. Pulling a BSD image
# retags the shared local name, so a later unqualified pull of that name is a
# no-op that serves the BSD copy. That trap has bitten this organisation before.
#
# EXIT. 0 pulled and inspected, 1 the pull or the inspection failed, 2 no engine.

set -eu

IMAGE="${IMAGE:-ghcr.io/freebsd/freebsd-runtime:15.1}"
OS="${OS:-freebsd}"
ARCH="${ARCH:-amd64}"

ENGINE=""
for e in podman docker; do
  if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
done
if [ -z "$ENGINE" ]; then
  echo "FAIL: neither podman nor docker is on PATH" >&2
  exit 2
fi

# ⚠ --os is required and it is NOT the same flag as --platform. Reaching for
# --platform linux/amd64 out of habit asks for an image that does not exist.
echo "==> pulling $IMAGE as $OS/$ARCH"
if ! "$ENGINE" pull --os "$OS" --arch "$ARCH" "$IMAGE"; then
  echo "FAIL: pull failed. The tag may have moved; scripts/sources pins what this" >&2
  echo "      repository builds, and upstream tags are not this repository's." >&2
  exit 1
fi

echo
echo "==> what the image declares about itself"
if ! "$ENGINE" image inspect --format '{{.Os}}/{{.Architecture}}' "$IMAGE"; then
  echo "FAIL: inspect failed" >&2
  exit 1
fi

echo
echo "==> removing it again, so it cannot shadow a later unqualified pull"
"$ENGINE" image rm "$IMAGE" >/dev/null 2>&1 || true
echo "done"
