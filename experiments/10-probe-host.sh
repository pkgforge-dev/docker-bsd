#!/bin/sh
# 10-probe-host.sh - what can this Linux or WSL host do about booting a BSD.
#
# WHY. Every other experiment here costs a download or a boot. This one costs
# nothing and says which of them are worth starting on this machine.
#
# ⛔ THIS REPOSITORY BUILDS IMAGES NOTHING CAN RUN. A BSD image needs a BSD
# kernel, so every route to running one starts with a hypervisor. This script
# answers, for one host, which routes are open before anything is downloaded.
#
# It is a probe, not a gate. A missing tool is data. It exits 0 whenever it was
# able to look, and 2 only when it could not look at all.
#
# Usage:  sh experiments/10-probe-host.sh
#
# ⛔ Read the exit code from this process, unpiped.
#
# ⚠ Run it inside the machine you intend to boot the guest in. On Windows with
# WSL2 that is the podman machine, not the Windows host:
#     wsl -d podman-machine-default -u root -- /bin/sh -lc 'sh /path/10-probe-host.sh'
# and from Git Bash that command needs MSYS_NO_PATHCONV=1, or Git Bash rewrites
# the guest's /bin/sh into a Windows path and the error names neither.

set -u

say()  { printf '  %-22s %s\n' "$1" "$2"; }

case "$(uname -s 2>/dev/null || echo unknown)" in
  Linux) : ;;
  *)
    printf 'probe: this half is for a Linux or WSL host. On Windows run 10-probe-host.ps1\n' >&2
    exit 2
    ;;
esac

printf 'host probe (linux)\n\n'

printf 'KERNEL\n'
say kernel "$(uname -r)"
# ⛔ The usual test, grep -i microsoft /proc/version, is WRONG on a machine that
# runs a custom WSL2 kernel. Measured here: podman-machine-default reports
# "Linux version 7.2.0-WSL2-STABLE (root@...) (gcc ...)" with no "microsoft"
# anywhere, so the usual test answers "not WSL" inside WSL. Key on markers the
# WSL runtime creates instead, and say which one fired.
if [ -d /run/WSL ]; then
  say wsl "yes (/run/WSL)"
elif [ -n "${WSL_INTEROP:-}" ]; then
  say wsl "yes (WSL_INTEROP)"
elif uname -r | grep -qiE 'wsl|microsoft'; then
  say wsl "yes (kernel release)"
else
  say wsl "no"
fi
say arch "$(uname -m)"

printf '\nVIRTUALISATION\n'
# ⛔ Presence is not enough. QEMU tests whether /dev/kvm is WRITABLE, so a node
# that exists and is root-only still falls back to TCG, which is the difference
# between a boot and a ten-minute boot. Test the same thing QEMU tests.
if [ -e /dev/kvm ]; then
  if [ -w /dev/kvm ]; then
    say /dev/kvm "present and WRITABLE"
  else
    say /dev/kvm "present, NOT writable by $(id -un). QEMU would use TCG"
  fi
  say "" "$(ls -l /dev/kvm 2>/dev/null)"
else
  say /dev/kvm "absent. No KVM acceleration on this host"
fi

for f in vmx svm; do
  n=$(grep -c "$f" /proc/cpuinfo 2>/dev/null) || n=0
  [ "$n" -gt 0 ] && say "cpu flag $f" "$n threads"
done

# Nested KVM. Present means this host can itself host an accelerated guest,
# which is what a WSL2 machine needs to run a BSD under QEMU or Firecracker.
for m in kvm_intel kvm_amd; do
  p="/sys/module/$m/parameters/nested"
  [ -r "$p" ] && say "$m.nested" "$(cat "$p")"
done

# ⚠ The 'hypervisor' flag is present only when this host is ITSELF a guest.
# On an AMD host that also reports avx512f, nested AMD-V mishandles the L2
# guest's AVX512 XSAVE state and a modern guest takes random SIGSEGVs across
# nearly every dynamically linked binary while its kernel stays up.
if grep -q hypervisor /proc/cpuinfo 2>/dev/null; then
  say nested "this host is itself a guest"
  if grep -q AuthenticAMD /proc/cpuinfo 2>/dev/null && grep -q avx512f /proc/cpuinfo 2>/dev/null; then
    say "⛔ AVX512 hazard" "AMD + nested + avx512f. Drop AVX512 from -cpu host"
  fi
else
  say nested "this host is bare metal or reports no hypervisor flag"
fi

printf '\nTOOLING\n'
for t in qemu-system-x86_64 qemu-img firecracker podman docker curl xz zstd oras bsdtar 7z; do
  p=$(command -v "$t" 2>/dev/null) || p=""
  if [ -n "$p" ]; then say "$t" "$p"; else say "$t" "absent"; fi
done

printf '\nWHAT THIS MEANS\n'
if [ -w /dev/kvm ]; then
  printf '  ⭐ KVM is usable. A BSD guest here runs accelerated:\n'
  printf '     - Firecracker, with a published BSD kernel and rootfs;\n'
  printf '     - qemu-system-x86_64 -accel kvm.\n'
elif [ -e /dev/kvm ]; then
  printf '  ⚠ /dev/kvm exists and is not writable. On a CI runner a udev rule\n'
  printf '     fixes that; QEMU otherwise falls back to TCG, and a FreeBSD first\n'
  printf '     boot under TCG has been measured overrunning ten minutes.\n'
else
  printf '  ⛔ No KVM. Every guest here would be emulated.\n'
fi
printf '\nThis is a probe, not a gate. A missing tool is data.\n'
exit 0
