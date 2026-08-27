#!/bin/sh
# entrypoint.sh - the seam between the container's world and the guest's.
#
# ⛔ IT DECIDES ONE THING AND DELEGATES THE REST. Acceleration is detected here
# because it is a property of the CONTAINER (whether a device was handed in),
# not of the guest. Everything about the guest itself, including the emulator's
# argument list, lives in guest.py so there is one copy of it.
#
# ⭐ THE CONSUMER CHOOSES NOTHING. There is no flag to pass, no variable to set
# and no documentation to read: /dev/kvm is used when it is present and pure
# emulation when it is not. docs/LIMITS.md carries what that costs.
#
# ⚠ BSD_ACCEL exists for the benchmark, not for the consumer. Forcing tcg on a
# host that has /dev/kvm is how the unaccelerated number gets measured on a
# machine that could have cheated.
#
# Exit code: the guest command's own, or the emulator's.

set -eu

ACCEL="${BSD_ACCEL:-auto}"

if [ "$ACCEL" = "auto" ]; then
  # ⛔ THREE TESTS, NOT ONE. A /dev/kvm that exists and cannot be opened is the
  # common case: podman without --device leaves no node at all, and a node
  # present but owned by a group the container is not in reads as -c and not as
  # -w. Each of the three is a different way for the same flag to be missing.
  if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ACCEL=kvm
  else
    ACCEL=tcg
    # ⛔ SAY SO WHEN A DEVICE WAS HANDED IN AND CANNOT BE USED. Falling back
    # silently is correct and it is not kind: on a free GitHub runner
    # `--device /dev/kvm` gets the node into the container owned by a group the
    # container is not in, everything works, and it is five hundred
    # milliseconds slower for nothing. Measured 2026-08-28, after that silence
    # cost this project a wrong conclusion about acceleration.
    if [ -c /dev/kvm ]; then
      printf 'netbsd: /dev/kvm is here and cannot be opened by this container, so it is not being used.\n' >&2
      printf 'netbsd: a rootless engine usually needs the group as well as the node, for example --group-add keep-groups.\n' >&2
    fi
  fi
fi

case "$ACCEL" in
  kvm|tcg) : ;;
  *) printf 'netbsd: BSD_ACCEL must be auto, kvm or tcg, not %s\n' "$ACCEL" >&2; exit 2 ;;
esac

export BSD_ACCEL="$ACCEL"

exec python3 /opt/bsd/guest.py "$@"
