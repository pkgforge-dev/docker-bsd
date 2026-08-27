# traps.md

⭐ **The traps that are specific to booting a BSD**, as opposed to the general
ones about shells and scripts. Every row cost this project real time, and every
row was measured here.

⛔ **This page carries no measurement of its own.** The numbers live in
[`LIMITS.md`](LIMITS.md) and the experiments that produced them live in
[`../experiments/`](../experiments/README.md). One fact, one home.

⚠ **The general traps are elsewhere and are not repeated here:**
[`conventions/shell.md`](conventions/shell.md) for crossing a shell, and
[`conventions/forbidden-patterns.md`](conventions/forbidden-patterns.md) for
the coding classes.

---

## 1. ⛔ A BSD image on a Linux kernel exits 139, not `Exec format error`

⭐ **Read the number, not the text.** 139 is 128 + 11, a SIGSEGV. The Linux ELF
loader **accepts** the binary and it dies on its first syscall, because the
syscall ABI is a different operating system's.

⛔ **So `binfmt_misc` and `qemu-user` are both irrelevant.** They solve a
foreign **architecture** presenting **Linux** syscalls. This is a native
architecture presenting **BSD** syscalls.

⚠ **The near miss is what makes this expensive.** The adjacent failure,
`Exec format error`, looks like the same family and is fixable. Filing them
together produces a plan built on the wrong remedy.

---

## 2. ⛔ Under the Windows hypervisor, the guest sees the HOST's hypervisor

```text
Hypervisor: Origin = "Microsoft Hv"
```

⭐ **Not the emulator's identity. The host's.** Everything below follows from
that one line, and none of it is obvious from any error message it produces.

### 2a. A guest that looks for the emulator finds nothing

NetBSD's paravirtual bus goes looking for the emulator's firmware-configuration
device, does not find it, and never enumerates its virtio transport. ⛔ **The
kernel boots perfectly and then has no disk**, and sits at a root-device prompt
forever. A guest with ordinary PCI drivers is unaffected.

### 2b. The guest trusts a paravirtual clock that is not really there

FreeBSD sees the Hyper-V timecounter, rates it highest, and selects it. ⛔ **Go
binaries then die of `SIGFPE` inside the garbage collector.** One `sysctl`
moves a short-lived one to success.

⛔ **AND THE CLOCK IS NOT THE CAUSE.** This repository published that
explanation and withdrew it in the same session: with the other timecounter
selected the clock is measurably correct, and a long-running Go daemon still
panics the **guest kernel**. ⚠ The `sysctl` moved the symptom. Nothing here
knows why yet. [`../TODO/bsd.md`](../TODO/bsd.md) carries the correction under
the claim.

---

## 3. ⚠ The emulator gives you a network device you did not ask for

⛔ **`-display none` says nothing about the network**, and a default interface
is attached unless it is explicitly refused. An experiment here printed
`network NONE` in its own header while the guest ran a DHCP client and took a
lease.

⭐ **Assert an absence; do not infer it from what you left out.** No inbound
door was actually opened, and the header was still false, and a false header
about a security property is the kind that gets believed.

---

## 4. ⛔ A serial console is a real tty, and it drops what you type

Two halves, and the second is the one that produces a **wrong answer** rather
than a missing one.

- ⛔ **Typing a whole line at once loses characters** while the guest is still
  setting up the line discipline. A marker arrived as a corrupted prefix and
  never matched, which read as "the guest never answered" over a guest that had
  answered correctly.
- ⛔ **A tty wraps the echo**, so a filter that removes the echo by matching the
  command text **misses it**. The echo survives into the output, and a success
  marker can then match the command line that merely mentioned it. That
  reported "a container ran" over a run that had exited with an error.

⭐ Both fixes live in one place, [`../experiments/lib/console.ps1`](../experiments/lib/console.ps1)
and [`../experiments/lib/console.py`](../experiments/lib/console.py): type one
character at a time, and compare with whitespace removed.

---

## 5. ⚠ Podman on FreeBSD defaults to a storage driver the image cannot use

⛔ **Two traps in a row, and the second undoes the fix for the first.**

- The default storage driver is ZFS and the published FreeBSD CI image is UFS,
  so every podman verb dies naming `/dev/zfs`.
- ⛔ **The storage database then outranks the config file.** A run that has
  already failed against ZFS records the driver and refuses to be told
  otherwise, so editing the configuration changes nothing until the recorded
  state is removed.

---

## 6. ⚠ A published rule measured elsewhere may not reproduce here

Two projects independently measured that certain CPU models wedge the emulator
under the Windows hypervisor. ⛔ **It did not reproduce on current software on
this hardware**, including the two models the advice forbids.

⭐ **Neither report is falsified and the prediction was.** They measured older
software on other hardware. ⚠ **Prefer the safe option anyway**: it costs
nothing, and the failure it avoids is a long hang with no output.

---

## 7. ⚠ `pgrep -f` and `pkill -f` match their own shell

⛔ **The pattern appears in the command line of the shell that is running it.**
This produced a false "still running" report, and then a `pkill` that killed the
shell issuing it.

⭐ Use `-x` and an exact process name.
