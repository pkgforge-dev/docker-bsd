#!/bin/sh
# 31-boot-freebsd-firecracker.sh
#
# WHY. The second avenue in the ranked list: a FreeBSD microvm on the nested
# KVM that WSL2 already exposes. acj publishes a patched FreeBSD kernel and a
# root filesystem that Firecracker boots directly, so nothing is built here.
#
# MEASURES. Whether /dev/kvm inside this machine actually runs a guest rather
# than merely existing, how long FreeBSD takes to reach a usable userland, and
# what that userland reports about itself. ⛔ It asserts by running a command in
# the guest over SSH and reading its output, never by looking at a boot log.
#
# ⚠ WHERE THIS RUNS. Inside a Linux host with /dev/kvm. On the Windows machine
# this repository is developed on that is the WSL2 podman machine, and it is
# NESTED virtualisation, which TODO/bsd.md ranks as the
# floor rather than the target. Drive it from Windows with:
#
#   wsl -d podman-machine-default -u root -- /bin/sh /mnt/c/PATH/TO/THIS/SCRIPT
#
# ⛔ Do NOT pass this script's path through Git Bash without
# MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*', and do not inline a payload
# containing a dollar sign into wsl.exe: it is expanded in transit and the
# result is re-parsed. Measured again on 2026-08-27; a probe loop over "$t"
# reached the guest as an empty string and printed nothing.
#
# WHERE IT WRITES. /var/tmp/fbsd-fc inside this Linux host, deliberately NOT
# the repository, because a 5 GB disk image on a 9p or drvfs mount is slow
# enough to change the number this script exists to measure.
#
# ⛔ THE KEY IS PUBLIC. The SSH key pair below is published in acj's release,
# so anybody can read it. The guest is reachable only on the host-local tap
# device this script creates, no route to it is published, and the script
# removes the tap on exit. Do not put this guest on a routable address.
#
# EXIT. 0 FreeBSD booted and answered over SSH, 1 it did not, 2 a prerequisite
# is missing.

set -eu

REL="https://github.com/acj/freebsd-firecracker/releases/download/v0.11.0"
WORK="/var/tmp/fbsd-fc"
TAP_DEV="fcbsd0"
TAP_IP="172.16.0.1"
GUEST_IP="172.16.0.2"
FC_MAC="06:00:AC:10:00:02"
API_SOCKET="$WORK/firecracker.socket"
DISK_SIZE="5G"
MEM_MIB=2048
VCPUS=2

say() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit "${2:-1}"; }

# ---------------------------------------------------------------- preflight
say "preflight"
[ -c /dev/kvm ] || fail "/dev/kvm is not a character device here" 2
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  fail "/dev/kvm is present but not readable and writable by this user" 2
fi
for t in curl xz ip ssh truncate; do
  command -v "$t" >/dev/null 2>&1 || fail "$t is required and is not on PATH" 2
done
say "  kvm      ok, readable and writable"
say "  nested   $(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo unknown)"
say "  kernel   $(uname -r)"

mkdir -p "$WORK"
cd "$WORK"

# ------------------------------------------------------------------- fetch
fetch() {
  if [ -s "$2" ]; then
    say "  have  $2"
    return 0
  fi
  say "  fetch $2"
  curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1" \
    || fail "curl failed for $1"
}

say "fetch artefacts"
fetch "$REL/firecracker" firecracker
fetch "$REL/freebsd-kern.bin" freebsd-kern.bin
fetch "$REL/freebsd-rootfs.bin.xz" freebsd-rootfs.bin.xz
fetch "$REL/freebsd.id_rsa" freebsd.id_rsa
chmod +x firecracker
chmod 600 freebsd.id_rsa

if [ ! -s freebsd-rootfs.bin ]; then
  say "  expand freebsd-rootfs.bin.xz"
  xz -T 0 -dk freebsd-rootfs.bin.xz || fail "xz failed"
  truncate -s "$DISK_SIZE" freebsd-rootfs.bin || fail "truncate failed"
else
  say "  have  freebsd-rootfs.bin"
fi

# ------------------------------------------------------------------ network
# A host-local tap. No NAT and no forwarding are set up: this experiment asks
# whether FreeBSD boots and answers, not whether it can reach the internet.
say "network"
ip link del "$TAP_DEV" 2>/dev/null || true
ip tuntap add dev "$TAP_DEV" mode tap || fail "could not create tap device"
ip addr add "$TAP_IP/24" dev "$TAP_DEV" || fail "could not address tap device"
ip link set dev "$TAP_DEV" up || fail "could not bring tap device up"
say "  $TAP_DEV at $TAP_IP/24, guest expected at $GUEST_IP"

# ⛔ BOTH CODES, and the reason is a real CI failure. This function is reached
# only through the `trap` two lines below, which the linter cannot see. The
# local linter reports SC2329 for that; the CI runner's version reports SC2317
# for the same thing, so a directive naming only one passed here and failed
# there. Measured 2026-08-27.
# ⚠ And do not begin a comment line with that tool's own name: it is parsed as
# a directive, which is how the first attempt at this comment broke the file.
# shellcheck disable=SC2329,SC2317
cleanup() {
  rc=$?
  say "cleanup"
  if [ -n "${FC_PID:-}" ]; then
    kill "$FC_PID" 2>/dev/null || true
    # Give it a moment to release the tap before the tap is removed.
    i=0
    while kill -0 "$FC_PID" 2>/dev/null && [ "$i" -lt 20 ]; do
      i=$((i + 1)); sleep 0.2
    done
    kill -9 "$FC_PID" 2>/dev/null || true
  fi
  ip link del "$TAP_DEV" 2>/dev/null || true
  rm -f "$API_SOCKET"
  say "  tap removed, firecracker stopped"
  exit "$rc"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------- TSC clock
# ⛔ Not cosmetic. acj's kernel skips early TSC calibration, so a host whose
# CPU brand string carries no frequency makes the guest panic in LAPIC init.
# Passing a real frequency is the published fix. Three sources, best first.
tsc_mhz=$(dmesg 2>/dev/null | sed -n 's/.*Refined TSC clocksource calibration: \([0-9.]*\) MHz.*/\1/p' | tail -1)
[ -n "$tsc_mhz" ] || tsc_mhz=$(dmesg 2>/dev/null | sed -n 's/.*Detected \([0-9.]*\) MHz processor.*/\1/p' | tail -1)
[ -n "$tsc_mhz" ] || tsc_mhz=$(sed -n 's/^cpu MHz[^:]*: \([0-9.]*\)/\1/p' /proc/cpuinfo | head -1)
BOOT_ARGS="vfs.root.mountfrom=ufs:/dev/vtbd0"
if [ -n "$tsc_mhz" ]; then
  tsc_hz=$(awk "BEGIN{printf \"%d\", $tsc_mhz*1000000}")
  BOOT_ARGS="$BOOT_ARGS machdep.tsc_freq=$tsc_hz"
  say "host TSC ${tsc_mhz} MHz (${tsc_hz} Hz)"
else
  say "⚠ host TSC frequency unknown; a boot panic here is the known cause"
fi

# ------------------------------------------------------------------- config
cat > vmconfig.json <<JSON
{
  "boot-source": {
    "kernel_image_path": "$WORK/freebsd-kern.bin",
    "boot_args": "$BOOT_ARGS"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "$WORK/freebsd-rootfs.bin",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "$FC_MAC",
      "host_dev_name": "$TAP_DEV"
    }
  ],
  "machine-config": {
    "vcpu_count": $VCPUS,
    "mem_size_mib": $MEM_MIB,
    "smt": false
  }
}
JSON

# --------------------------------------------------------------------- boot
rm -f "$API_SOCKET"
say "boot"
start=$(date +%s.%N)
./firecracker --api-sock "$API_SOCKET" --config-file vmconfig.json \
  > "$WORK/console.log" 2>&1 &
FC_PID=$!
say "  firecracker pid $FC_PID"

# ⛔ ConnectTimeout=90, and the number is measured rather than generous.
# sshd accepts the TCP connection immediately and then takes about 30 SECONDS
# to send its banner, because it reverse-resolves the client and this script
# deliberately sets up no NAT, so the guest's DNS goes nowhere and the lookup
# must time out first. A short timeout here reads as "FreeBSD never booted"
# when FreeBSD in fact booted in two seconds. acj's own CI never sees this,
# because it masquerades the guest onto the runner's network.
SSH="ssh -i $WORK/freebsd.id_rsa -o StrictHostKeyChecking=no \
 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=90 \
 -o BatchMode=yes root@$GUEST_IP"

# ⛔ Wait on the CONSOLE for a login prompt before trying SSH at all. That
# separates "the guest did not boot" from "the guest booted and the way in was
# slow", which is exactly the distinction the first version of this script got
# wrong: it reported a boot failure over a FreeBSD that had been up for 295 s.
booted=0
i=0
while [ "$i" -lt 480 ]; do
  if ! kill -0 "$FC_PID" 2>/dev/null; then
    say "⛔ firecracker exited before the guest reached a login prompt"
    break
  fi
  if grep -q 'login:' "$WORK/console.log" 2>/dev/null; then
    booted=1
    break
  fi
  i=$((i + 1))
  sleep 0.25
done
boot_end=$(date +%s.%N)
boot_elapsed=$(awk "BEGIN{printf \"%.1f\", $boot_end - $start}")
if [ "$booted" -eq 1 ]; then
  say "login prompt after ${boot_elapsed}s"
else
  say "⛔ no login prompt within the budget"
fi

ready=0
if [ "$booted" -eq 1 ]; then
  say "opening a shell over SSH (the banner takes about 30 s, see above)"
  if $SSH true 2>/dev/null; then
    ready=1
  fi
fi
end=$(date +%s.%N)
elapsed=$(awk "BEGIN{printf \"%.1f\", $end - $start}")

echo
echo "RESULT"
if [ "$ready" -ne 1 ]; then
  if [ "$booted" -eq 1 ]; then
    echo "  boot        OK, login prompt after ${boot_elapsed}s"
    echo "  ssh         FAILED. ⚠ FreeBSD booted; the way in did not work,"
    echo "              which is a different defect and a different fix."
  else
    echo "  boot        FAILED, no login prompt"
  fi
  echo "  elapsed     ${elapsed}s"
  echo "  console tail:"
  tail -30 "$WORK/console.log" 2>/dev/null | sed 's/^/    /'
  exit 1
fi

echo "  boot        OK, login prompt after ${boot_elapsed}s"
echo "  ssh         OK, shell at ${elapsed}s"
echo "              ⚠ the gap is sshd's reverse lookup, not FreeBSD booting"
echo "  guest says:"
# ⛔ Root's login shell on FreeBSD is csh, so a command string passed as an ssh
# argument is parsed by csh. Pipe the script into sh -s instead.
# ⛔ The output is captured to a file and formatted afterwards, rather than
# piped straight into sed. `cmd | sed` followed by $? reads SED's status, so an
# ssh that failed would read as green. That is a row in ToolKit's
# forbidden-patterns.md, and the first draft of this script had it.
ssh_rc=0
# shellcheck disable=SC2016  # deliberate: every $(...) below must expand in the
# GUEST when sh reads it there, not on this host when the line is written.
printf '%s\n' \
  'uname -a' \
  'echo "--- freebsd-version: $(freebsd-version)"' \
  'echo "--- hostname: $(hostname)"' \
  'echo "--- cpu: $(sysctl -n hw.model)"' \
  'echo "--- ncpu: $(sysctl -n hw.ncpu)"' \
  'echo "--- mem: $(sysctl -n hw.physmem)"' \
  'echo "--- kern.vm_guest: $(sysctl -n kern.vm_guest)"' \
  'echo "--- root fs:"; df -h / | tail -1' \
  'echo "--- uptime:"; uptime' \
  | $SSH sh -s > "$WORK/guest-says.txt" 2>/dev/null || ssh_rc=$?
sed 's/^/    /' "$WORK/guest-says.txt"
if [ "$ssh_rc" -ne 0 ]; then
  echo "  ⚠ the command stream exited $ssh_rc, so the lines above may be short"
fi
echo
echo "  hypervisor  Firecracker on /dev/kvm inside this Linux host"
echo "  ⚠ nesting   one level deeper than the host's own hypervisor"
exit 0
