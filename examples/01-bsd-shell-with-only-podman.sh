#!/bin/sh
# 01-bsd-shell-with-only-podman.sh
#
# A BSD shell, on a host that has nothing but a container engine.
#
# NEEDS:  podman or docker. Nothing else. No emulator on the host, no /dev/kvm,
#         no root, no --privileged, no capability.
# COSTS:  about 30 MB of downloads the first time, then seconds.
# GIVES:  an interactive NetBSD shell.
#
# HOW IT WORKS. The emulator ships INSIDE the container. A container is a Linux
# process and an emulator is a Linux process, so the host contributes nothing.
# The guest is a microvm, which is why it is fast even with no acceleration.
#
# The timings are in docs/LIMITS.md and nowhere else.
#
# EXIT. 0 you got a shell, 1 something upstream moved, 2 no container engine.

set -eu

ENGINE=""
for e in podman docker; do
  if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
done
if [ -z "$ENGINE" ]; then
  echo "FAIL: neither podman nor docker is on PATH" >&2
  exit 2
fi

# Hand /dev/kvm in when this host has one. It is worth about two seconds and it
# is not required; the whole point of this example is that it works without.
DEVICE=""
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  DEVICE="--device /dev/kvm"
  echo "==> /dev/kvm is usable here, handing it in"
else
  echo "==> no usable /dev/kvm, running unaccelerated. This still works."
fi

echo "==> starting a NetBSD microvm inside an $ENGINE container"
echo "==> type 'halt -p' to leave, or press ctrl-a x"
echo

# shellcheck disable=SC2086  # DEVICE is empty or exactly one flag and its value
# shellcheck disable=SC2016  # deliberate: every $ below expands INSIDE the
# container when its shell reads it, not here when this line is written.
exec "$ENGINE" run --rm -it $DEVICE docker.io/library/alpine:3.22 /bin/sh -c '
set -eu
apk add --no-cache qemu-system-x86_64 xz curl >/dev/null 2>&1
cd /tmp
curl -fsSL -o netbsd-SMOL https://smolbsd.org/assets/netbsd-SMOL
curl -fsSL -o r.img.xz https://github.com/NetBSDfr/smolBSD/releases/download/latest/rescue-amd64.img.xz
xz -d r.img.xz
ACCEL=tcg; CPU=qemu64
if [ -c /dev/kvm ] && [ -w /dev/kvm ]; then ACCEL=kvm; CPU=host; fi
exec qemu-system-x86_64 -smp 1 -m 256 \
  -accel "$ACCEL" -M microvm,rtc=on,acpi=off,pic=off -cpu "$CPU" \
  -kernel netbsd-SMOL \
  -drive if=none,file=r.img,format=raw,id=hd0 \
  -device virtio-blk-device,drive=hd0 \
  -append "console=com root=NAME=rescueroot -z" \
  -global virtio-mmio.force-legacy=false \
  -display none -no-reboot -nic none -serial mon:stdio
'
