#!/bin/sh
# 03-what-can-this-host-do.sh
#
# Asks this machine which routes to a running BSD are open to it, and says why
# the others are not.
#
# NEEDS:  nothing.
# COSTS:  nothing. It reads, it does not fetch and it does not run a guest.
# GIVES:  one line per route, and a pointer to the page with the timings.
#
# ⛔ IT PRINTS NO SECONDS. Every timing lives in docs/LIMITS.md, which is the
# only page in this repository carrying them.
#
# EXIT. 0 always. It is a probe, not a gate: a closed route is data.

set -u

yes_no() { if [ "$1" = 1 ]; then printf 'YES'; else printf 'no '; fi; }

engine=0
for e in podman docker; do
  command -v "$e" >/dev/null 2>&1 && { engine=1; ENGINE=$e; break; }
done

kvm=0
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then kvm=1; fi

qemu=0
command -v qemu-system-x86_64 >/dev/null 2>&1 && qemu=1

os=$(uname -s 2>/dev/null || echo unknown)

echo "host: $os"
echo
printf '  %s  a container engine        %s\n' "$(yes_no "$engine")" \
  "$([ "$engine" = 1 ] && echo "($ENGINE)" || echo '(install podman or docker)')"
printf '  %s  a usable /dev/kvm         %s\n' "$(yes_no "$kvm")" \
  "$([ "$kvm" = 1 ] && echo '(worth about two seconds)' || echo '(not required)')"
printf '  %s  an emulator on the host   %s\n' "$(yes_no "$qemu")" \
  "$([ "$qemu" = 1 ] && echo '(qemu-system-x86_64)' || echo '(not required for route 1)')"
echo
echo "routes open to this host:"
if [ "$engine" = 1 ]; then
  echo "  ⭐ a BSD shell with only a container engine -> examples/01-bsd-shell-with-only-podman.sh"
else
  echo "  ⛔ nothing, until a container engine or an emulator is installed"
fi
if [ "$qemu" = 1 ]; then
  echo "  ⭐ a full BSD userland on this host's own hypervisor -> docs/LIMITS.md section 2"
fi
if [ "$kvm" = 1 ]; then
  echo "  ⭐ a BSD microvm on /dev/kvm -> experiments/31-boot-freebsd-firecracker.sh"
fi
echo
echo "⛔ what is closed on every host: a BSD userland on a Linux kernel."
echo "   It exits 139, a SIGSEGV, and no binfmt_misc setting reaches it."
echo
echo "the timings for each route are in docs/LIMITS.md"
