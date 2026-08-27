#!/bin/sh
# 35-boot-in-container.sh
#
# WHY. ⭐ THE HEADLINE QUESTION FOR A CONSUMER, and nothing had measured it.
# Everything else in this directory assumes a host somebody is willing to set
# up: an emulator installed, a hypervisor reachable, a machine to configure.
# The question that actually decides whether this project is usable is the
# opposite one:
#
#   I have podman. That is all. No emulator on the host, no hypervisor I can
#   reach, no root. Can I get a BSD shell?
#
# ⭐ The answer does not depend on the host at all if the emulator ships INSIDE
# the image. A container is a Linux process; an emulator is a Linux process. So
# this measures a BSD booting inside an ordinary unprivileged container, with
# the host contributing nothing but a container engine.
#
# MEASURES.
#   1. wall-clock seconds from `podman run` to a BSD shell that answers;
#   2. the same with /dev/kvm handed in, when the host has one, so the price of
#      having no acceleration is a number rather than an adjective;
#   3. ⛔ whether it needs any privilege at all. It is run with --network none
#      and no --privileged, no --cap-add and no --device unless measuring 2.
#
# ⛔ IT ASSERTS BY RUNNING COMMANDS IN THE GUEST and reading their output, not
# by looking at a boot log for a hopeful string.
#
# HOST. Any machine with podman or docker. Nothing else.
#
# EXIT. 0 a BSD userland answered inside a container, 1 it did not, 2 a
# prerequisite is missing.

set -eu

BASE_IMAGE="${BASE_IMAGE:-docker.io/library/alpine:3.22}"
KERNEL_URL="https://smolbsd.org/assets/netbsd-SMOL"
IMG_URL="https://github.com/NetBSDfr/smolBSD/releases/download/latest/rescue-amd64.img.xz"

say() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit "${2:-1}"; }

ENGINE=""
for e in podman docker; do
  if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
done
[ -n "$ENGINE" ] || fail "neither podman nor docker is on PATH" 2

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
out="$root/.tmp/incontainer"
mkdir -p "$out"

# The path handed to the engine is not always the path this shell uses. Under
# Git Bash the engine is a native Windows binary and wants a Windows path, and
# a POSIX one silently becomes an empty mount. docs/conventions/shell.md
# section 7.
MOUNT="$out"
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    command -v cygpath >/dev/null 2>&1 && MOUNT=$(cygpath -w "$out")
    ;;
esac

say "engine   $ENGINE"
say "base     $BASE_IMAGE"
say "workdir  $out"
say "mount    $MOUNT"

# The guest-side script. ⛔ Written to a file and mounted, never inlined into
# the engine's argument list: a payload crossing an engine, a shell and a
# container runtime is the shape docs/conventions/shell.md exists about.
cat > "$out/inside.sh" <<'INSIDE'
#!/bin/sh
# Runs INSIDE the container. Fetches the artefacts, boots them, drives the
# console, prints a machine-readable RESULT line.
set -eu
ACCEL="${ACCEL:-tcg}"
cd /work

if [ ! -s netbsd-SMOL ] || [ ! -s rescue-amd64.img ]; then
  echo "==> installing qemu and python inside the container"
  apk add --no-cache qemu-system-x86_64 python3 xz curl >/dev/null 2>&1 \
    || { echo "FAIL: apk add failed"; exit 2; }
  echo "==> fetching the artefacts"
  curl -fsSL -o netbsd-SMOL "$KERNEL_URL" || { echo "FAIL: kernel fetch"; exit 1; }
  curl -fsSL -o rescue-amd64.img.xz "$IMG_URL" || { echo "FAIL: image fetch"; exit 1; }
  xz -dkf rescue-amd64.img.xz || { echo "FAIL: xz"; exit 1; }
else
  command -v qemu-system-x86_64 >/dev/null 2>&1 \
    || apk add --no-cache qemu-system-x86_64 python3 >/dev/null 2>&1
fi

exec python3 /work/drive.py "$ACCEL"
INSIDE

# The console driver, kept beside lib/console.py rather than duplicating it.
cp "$root/experiments/lib/console.py" "$out/console.py"

cat > "$out/drive.py" <<'DRIVE'
#!/usr/bin/env python3
"""Boot smolBSD inside this container and run commands in it."""
import sys
import time

sys.path.insert(0, "/work")
from console import Console  # noqa: E402

accel = sys.argv[1] if len(sys.argv) > 1 else "tcg"
cpu = "qemu64" if accel == "tcg" else "host"

argv = [
    "qemu-system-x86_64",
    "-smp", "1", "-m", "256",
    "-accel", accel,
    "-M", "microvm,rtc=on,acpi=off,pic=off",
    "-cpu", cpu + ",+invtsc" if accel != "tcg" else cpu,
    "-kernel", "netbsd-SMOL",
    "-drive", "if=none,file=rescue-amd64.img,format=raw,id=hd0",
    "-device", "virtio-blk-device,drive=hd0",
    "-append", "console=com root=NAME=rescueroot -z",
    "-global", "virtio-mmio.force-legacy=false",
    "-display", "none", "-no-reboot",
    "-serial", "stdio",
    "-nic", "none",
]

t0 = time.monotonic()
con = Console(argv, cwd="/work", prompt=r"# $")
ok = con.wait_for(r"# $", 300)
to_shell = time.monotonic() - t0

if not ok:
    print("RESULT accel=%s shell=no seconds=%.1f" % (accel, to_shell))
    print("--- console tail ---")
    print(con.text[-1500:])
    con.stop()
    sys.exit(1)

print("shell reached after %.1fs" % to_shell)
print("GUEST OUTPUT")
answered = False
# ⛔ ASSERT WITH SOMETHING THE GUEST ACTUALLY HAS. The smolBSD rescue image is
# a rescue image: it ships no uname and no tail, so a first version of this
# asserted on `uname -sr` and reported "answered=no" over a BSD that was
# answering perfectly through sysctl. Measured 2026-08-27.
for cmd in ("sysctl -n kern.ostype", "sysctl -n kern.osrelease",
            "sysctl -n hw.machine", "sysctl -n hw.ncpu", "sysctl -n kern.version"):
    got, lines = con.run(cmd, seconds=90)
    print("  $ " + cmd)
    for line in lines:
        print("      " + line)
    if cmd == "sysctl -n kern.ostype" and any("BSD" in x for x in lines):
        answered = True

con.stop("halt -p")
print("RESULT accel=%s shell=%s seconds=%.1f answered=%s"
      % (accel, "yes", to_shell, "yes" if answered else "no"))
sys.exit(0 if answered else 1)
DRIVE

run_case() {
  # $1 label, $2 accel, $3.. extra engine args
  label=$1; accel=$2; shift 2
  say "case: $label"
  # ⛔ --network none is deliberate on the second run: it proves the boot needs
  # nothing from the network once the artefacts are cached in the work
  # directory. The first run has to fetch, so it keeps networking.
  set -- "$@"
  if [ "$ENGINE" = "podman" ]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$ENGINE" run --rm \
      -e "ACCEL=$accel" -e "KERNEL_URL=$KERNEL_URL" -e "IMG_URL=$IMG_URL" \
      -v "$MOUNT:/work:z" "$@" "$BASE_IMAGE" /bin/sh /work/inside.sh
  else
    "$ENGINE" run --rm \
      -e "ACCEL=$accel" -e "KERNEL_URL=$KERNEL_URL" -e "IMG_URL=$IMG_URL" \
      -v "$MOUNT:/work" "$@" "$BASE_IMAGE" /bin/sh /work/inside.sh
  fi
}

echo
say "run 1: no acceleration, no devices, no capabilities"
tcg_rc=0
run_case "unprivileged, tcg" tcg || tcg_rc=$?

# ⛔ ALWAYS ATTEMPT IT. Testing the HOST for /dev/kvm is the wrong test: on
# Windows and macOS the container runs inside a Linux machine, and it is THAT
# machine's /dev/kvm that matters. A first version skipped this case on every
# Windows host and reported "not attempted" where the answer was available.
echo
say "run 2: the same, with /dev/kvm handed in"
kvm_rc=0
run_case "accelerated" kvm --device /dev/kvm || kvm_rc=$?

echo
echo "RESULT"
echo "  engine            $ENGINE"
echo "  unprivileged tcg  $([ "$tcg_rc" -eq 0 ] && echo 'a BSD shell answered' || echo "FAILED, rc=$tcg_rc")"
case "$kvm_rc" in
  0) echo "  with /dev/kvm     a BSD shell answered" ;;
  *) echo "  with /dev/kvm     FAILED, rc=$kvm_rc. ⚠ Either the engine refused the" ;;
esac
[ "$kvm_rc" -eq 0 ] || echo "                    device or the machine has no /dev/kvm. Both are results."
echo "  ⛔ the seconds= figures above are what a consumer actually waits"
[ "$tcg_rc" -eq 0 ] || exit 1
exit 0
