#!/usr/bin/env python3
"""Boot the NetBSD guest baked into this image, and give the caller a shell or
the output of one command.

⛔ THIS FILE OWNS THE EMULATOR'S ARGUMENT LIST, and it is the only copy in the
image. Two copies is two places for a measured flag to be dropped, and every
flag below is one: -nic none because the emulator attaches an interface
otherwise, a named CPU model rather than host under tcg, and the microvm
machine with acpi and the legacy PIC off because that is what the kernel in
this image was built for. experiments/35-boot-in-container.sh measured them.

⚠ IT IMPORTS console.py RATHER THAN CARRYING A CONSOLE DRIVER. That module is
this repository's single copy of two measured tty rules, and a driver written
again here would be a second place for them to be wrong.

⛔ IT DOES NOT USE Console.run(), AND THAT IS A DEFECT IN Console RATHER THAN A
PREFERENCE HERE. run() decides a command has finished by counting prompts, and
its prompt pattern is anchored with a dollar sign, which Python matches only at
the end of the string. So the count is 0 or 1 and never rises, "one more prompt
than before" never becomes true, and every call burns its whole timeout before
returning the right answer late. Reproduced 2026-08-27 and filed as INF-08. The
send and wait_for primitives underneath it are sound, and they are what this
file uses.

Two modes, chosen from the arguments and nothing else:

  no arguments, or a bare shell name   the guest's console, wired to this
                                       container's stdin and stdout.
  anything else                        run it in the guest, print what it
                                       printed, and exit with its status.
"""

import os
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, "/opt/bsd")
from console import Console  # noqa: E402

KERNEL = "/guest/netbsd-SMOL"
ROOTFS = "/guest/rescue-amd64.img"

# ⛔ TWO MARKERS THAT CANNOT MATCH THE COMMAND LINE THAT PRODUCES THEM. A serial
# console echoes what is typed at it, so the guest's answer arrives in the same
# stream as the question. This repository has already published a false success
# read out of such an echo.
#
# ⭐ The trick is that the marker is CONCATENATED by the guest's own shell. What
# is typed carries a pair of quotes in the middle of it; what the guest prints
# does not. The literal never appears in the echo, so nothing has to filter the
# echo and no rule about where a tty wraps a line has to be right.
OUT_MARKER = "__bsdout__"
RC_MARKER = "__bsdrc__"
OUT_TYPED = '__bsdo""ut__'
RC_TYPED = '__bsdr""c__$?'

BOOT_SECONDS = int(os.environ.get("BSD_BOOT_TIMEOUT", "300"))
CMD_SECONDS = int(os.environ.get("BSD_CMD_TIMEOUT", "900"))

SHELL_NAMES = ("sh", "/bin/sh", "ash", "/bin/ash", "bash", "/bin/bash")


def note(*parts):
    """Diagnostics go to stderr. ⛔ stdout belongs to the guest."""
    print("netbsd:", *parts, file=sys.stderr, flush=True)


def qemu_argv(accel):
    cpu = "qemu64" if accel == "tcg" else "host,+invtsc"
    return [
        "qemu-system-x86_64",
        "-smp", os.environ.get("BSD_SMP", "1"),
        "-m", os.environ.get("BSD_MEM", "256"),
        "-accel", accel,
        "-M", "microvm,rtc=on,acpi=off,pic=off",
        "-cpu", cpu,
        "-kernel", KERNEL,
        "-drive", "if=none,file=%s,format=raw,id=hd0" % ROOTFS,
        "-device", "virtio-blk-device,drive=hd0",
        "-append", "console=com root=NAME=rescueroot -z",
        "-global", "virtio-mmio.force-legacy=false",
        "-display", "none", "-no-reboot",
        "-serial", "stdio",
        "-nic", "none",
    ]


def command_from(argv):
    """What the caller asked the GUEST to run, or None for a console.

    ⚠ `sh -c 'x'` is unwrapped rather than passed through. A consumer types the
    form they already use with every other image, and the guest's shell is the
    thing that will run it, so wrapping it in a second shell would ask the
    guest for a shell it does not need.
    """
    if not argv:
        return None
    if len(argv) == 1 and argv[0] in SHELL_NAMES:
        return None
    if argv[0] in SHELL_NAMES and len(argv) >= 3 and argv[1] == "-c":
        return " ".join(argv[2:])
    return " ".join(argv)


def interactive(accel):
    """Hand the guest's console to whoever is on the other end of stdio.

    ⛔ NOT exec. The emulator is spawned so that a /dev/kvm which is present
    and unusable can be answered by falling back rather than by printing an
    error at a consumer who passed no flag and can do nothing about it.
    """
    while True:
        started = time.monotonic()
        proc = subprocess.Popen(qemu_argv(accel))

        def forward(signum, _frame):
            proc.send_signal(signum)

        for sig in (signal.SIGTERM, signal.SIGINT):
            signal.signal(sig, forward)

        rc = proc.wait()
        if rc == 0 or accel == "tcg" or (time.monotonic() - started) > 5:
            return rc
        note("acceleration failed after %.1fs, retrying without it"
             % (time.monotonic() - started))
        accel = "tcg"


def boot(accel):
    """Start the guest and wait for its first prompt. Returns (console, accel)."""
    while True:
        started = time.monotonic()
        con = Console(qemu_argv(accel), prompt=r"# $")
        if con.wait_for(r"# $", BOOT_SECONDS):
            note("shell after %.1fs, accel=%s"
                 % (time.monotonic() - started, accel))
            return con, accel
        early = time.monotonic() - started
        con.stop()
        # ⛔ A /dev/kvm that is present and unusable dies in under a second. A
        # guest that is merely slow does not, so the elapsed time is what tells
        # the two apart. Falling back on every failure would hide a real one.
        if accel != "tcg" and early < 5:
            note("acceleration failed after %.1fs, retrying without it" % early)
            accel = "tcg"
            continue
        note("no shell after %.1fs. console tail follows" % early)
        print(con.text[-2000:], file=sys.stderr)
        return None, accel


def extract(chunk):
    """The guest's own output, and its exit status, out of the console stream."""
    lines = chunk.replace("\r", "").splitlines()
    rc = None
    out = []
    started = False
    for line in lines:
        stripped = line.strip()
        m = re.search(re.escape(RC_MARKER) + r"(\d+)", stripped)
        if m:
            rc = int(m.group(1))
            break
        if not started:
            if stripped.endswith(OUT_MARKER):
                started = True
            continue
        out.append(line.rstrip())
    return out, rc


def batch(accel, command):
    """Run one command in the guest. Return its status, not the emulator's."""
    con, accel = boot(accel)
    if con is None:
        return 1

    # ⛔ THE STATUS COMES BACK THROUGH THE CONSOLE OR IT DOES NOT COME BACK.
    # There is no other channel: the guest is a virtual machine, and the
    # emulator's own exit code says nothing about what ran inside it.
    #
    # ⚠ THE SUBSHELL IS NOT DECORATION. `sh -c 'exit 3'` is a command a consumer
    # really types, and run bare it would exit the guest's login shell so that
    # no status ever came back. Inside a subshell it is the subshell that exits,
    # the status is still there to be read, and that is what `sh -c` means.
    sent = 'echo "%s"; ( %s ); echo "%s"' % (OUT_TYPED, command, RC_TYPED)
    before = len(con.text)
    con.send(sent)
    ok = con.wait_for(re.escape(RC_MARKER) + r"\d", CMD_SECONDS)
    chunk = con.text[before:]
    con.stop("halt -p")

    if not ok:
        note("no exit status came back within %ss" % CMD_SECONDS)
        print(chunk[-2000:], file=sys.stderr)
        return 1

    out, rc = extract(chunk)
    for line in out:
        print(line, flush=True)
    if rc is None:
        note("the guest ran the command and no exit status came back")
        return 1
    return rc


def main():
    accel = os.environ.get("BSD_ACCEL", "tcg")
    for path in (KERNEL, ROOTFS):
        if not os.path.exists(path):
            note("missing artefact: %s. This image is not built correctly."
                 % path)
            return 2

    command = command_from(sys.argv[1:])
    if command is None:
        return interactive(accel)
    return batch(accel, command)


if __name__ == "__main__":
    sys.exit(main())
