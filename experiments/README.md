# experiments

⭐ **Committed experiments.** Each one is a script somebody ran, kept so the
next person does not run it again to find out what it printed.

⚠ **This is not `./.tmp`.** Scratch goes in `.tmp/`, which is ignored. Anything
here is tracked, reviewed, and expected to still run in six months.

The layout follows
[`pkgforge-dev/cross-libc-dlopen`](https://github.com/pkgforge-dev/cross-libc-dlopen),
which is the same organisation and the same problem shape: a question that can
only be answered by running something on a specific host.

---

## ⭐ The two headlines, measured 2026-08-27

### 1. ⭐ A BSD shell in **2.6 seconds** with nothing but a container engine

⛔ **No emulator on the host, no `/dev/kvm`, no capability, no device, no
root.** The emulator ships inside the image, because a container is a Linux
process and an emulator is a Linux process.

```text
shell reached after 2.6s
$ sysctl -n kern.ostype      smolBSD
$ sysctl -n kern.osrelease   11.0_STABLE
$ sysctl -n hw.machine       amd64
```

⭐ **0.6 s** with `--device /dev/kvm` handed in. That is
[`35-boot-in-container.sh`](35-boot-in-container.sh), and it is the route a
consumer actually cares about.

### 2. ⛔ A **full FreeBSD** userland on a Windows host, with no nesting

```text
$ uname -a
FreeBSD freebsd 15.1-RELEASE FreeBSD 15.1-RELEASE releng/15.1-n283562 GENERIC amd64
$ sysctl -n kern.vm_guest
hv
```

That is [`33-boot-freebsd-whpx.ps1`](33-boot-freebsd-whpx.ps1), driving the
emulator on the machine's own hypervisor, unelevated, and reading the answers
off the serial console.

⚠ **Conditions for both**, and for every number below: Windows 11 Pro
26200, QEMU 11.1.0, an i7-12700H reporting `Intel64 Family 6 Model 154
Stepping 3`, WSL2 podman machine running throughout.

---

## The naming rule

```text
NN-verb-noun.sh      POSIX shell, runs on Linux, in a container, or in WSL
NN-verb-noun.ps1     the Windows half, when the question is about a Windows host
lib/                 shared code, dot-sourced, never run on its own
```

⭐ **Numbered, and grouped by decade.** The number is the order somebody would
run them in, not the order they were written.

| decade | what belongs in it |
| --- | --- |
| `10` | probe the host. What can this machine actually do. |
| `20` | fetch and prepare. Kernels, root filesystems, disk images. |
| `30` | boot. The experiments that try to get a BSD running. |
| `40` | drive. Once something boots, talk to it. |
| `50` | publish. Registry, artefacts, digests. |

⚠ **A follow-on takes the next number in the same decade**, so `30`, `31`, `32`
are three attempts at the same question rather than three unrelated ones. That
is what makes the numbering readable a year later.

## What every experiment carries

⛔ **A header comment saying why it exists and what it measures**, before any
code. A script whose name says what it does and whose header does not say why it
was worth doing is a script the next person deletes.

⛔ **`set -u` at minimum.** Use `set -eu` unless the experiment deliberately
continues past a failure, and say so if it does.

⛔ **Read exit codes unpiped.** `cmd | tail; rc=$?` reads `tail`'s status. That
defect shipped in this repository once, in the script whose whole job was
verification. [`../HISTORY/poc.md`](../HISTORY/poc.md) section 8. ⚠ It shipped
again in the first draft of
[`31-boot-freebsd-firecracker.sh`](31-boot-freebsd-firecracker.sh), which piped
`ssh` into `sed` and then read `sed`'s status, and it was caught by review
rather than by anything running.

⛔ **`cmd; rc=$?` is unreachable under `set -e`**, which is the same class from
the other side: the shell has already exited by the time the guard would run, so
the guard is decoration. Write `if ! cmd; then`. Both fetch scripts here had
this before review.

⚠ **Native Windows binaries get a bare filename, never a path.** Run the binary
from the directory instead. [`../HISTORY/poc.md`](../HISTORY/poc.md) section 7
cost three debugging rounds to learn that, once per tool.

⚠ **On the PowerShell side, build argument lists with
`ProcessStartInfo.ArgumentList`, never `Start-Process -ArgumentList`.** The
latter joins the array with spaces and quotes nothing, so a QEMU `-append`
value arrives as four separate arguments and QEMU dies on `-z: invalid option`.

⛔ **Assert an absence; do not infer it from what you left out.**
`-display none` says nothing about the network, and QEMU attaches a **default
NIC** unless given `-nic none`. An experiment here printed `network NONE` in its
own header while its guest ran `dhclient` and took a lease on 10.0.2.15.

## What CI does with these

⚠ **Nothing, deliberately.** `.github/workflows/ci.yml` parses and lints
`scripts/` and `tests/`, not this directory. An experiment is allowed to be
mid-thought; a script in `scripts/` is not.

⭐ **The consequence: an experiment that graduates moves to `scripts/` and gets
gated.** That move is the signal that a question stopped being a question.

⚠ Every `.sh` here is nonetheless clean under `shellcheck -s sh`, and every
`.ps1` clean under `PSScriptAnalyzer -Severity Error,Warning`. Not gated, and
not an excuse.

---

## What is here, and what each one answered

| script | question | answer |
| --- | --- | --- |
| [`10-probe-host.sh`](10-probe-host.sh) | On Linux or WSL: is there a usable `/dev/kvm`, and what VM tooling is installed | `/dev/kvm` present and writable inside `podman-machine-default`, `kvm_intel.nested` is `Y` |
| [`10-probe-host.ps1`](10-probe-host.ps1) | On Windows: is the Windows Hypervisor Platform usable | ✅ `WHvGetCapability` returns `HypervisorPresent` 1, unelevated |
| [`20-fetch-smolbsd.sh`](20-fetch-smolbsd.sh) | Are smolBSD's rescue image and SMOL kernel still published, and do they verify | ✅ 4,376,660 B image, verified; 9,160,808 B kernel, ⚠ no published digest |
| [`21-fetch-freebsd-ci.sh`](21-fetch-freebsd-ci.sh) | Same, for FreeBSD's BASIC-CI image | ✅ 666,285,484 B, verified against the published `CHECKSUM.SHA256`, expands to 6.03 GiB |
| [`30-boot-smolbsd.ps1`](30-boot-smolbsd.ps1) | Does a NetBSD microvm boot under WHPX, and which CPU model works | ⛔ the kernel runs under every model tried; **no model reaches a disk**. See finding 1 and 2. |
| [`31-boot-freebsd-firecracker.sh`](31-boot-freebsd-firecracker.sh) | Does FreeBSD boot on the nested KVM inside the podman machine | ✅ **login prompt in 1.8 s**, shell over SSH at 32.3 s, `kern.vm_guest` is `kvm` |
| [`32-boot-hcs.ps1`](32-boot-hcs.ps1) | Can the Host Compute System be driven directly, with no patched service | ⚠ the API is reachable unelevated; ⛔ **every call is not.** See finding 3. |
| [`33-boot-freebsd-whpx.ps1`](33-boot-freebsd-whpx.ps1) | Does a BSD **userland** run on the Windows host's own hypervisor | ⭐ **yes.** Login prompt at 113.6 s, root shell on `ttyu0`, commands answered |
| [`40-drive-freebsd-podman.ps1`](40-drive-freebsd-podman.ps1) | Does a container run **inside** that guest, which is the gesture `BSD-01` opens with | ⭐ **yes**, `rc=0`, after three corrections. See findings 5 and 6 |
| [`41-connect-podman-from-windows.ps1`](41-connect-podman-from-windows.ps1) | Does the **Windows** podman client reach it, which is `BSD-01`'s acceptance | ⚠ ssh and the connection work; ⛔ the podman **daemon** does not stay up. See finding 7 |
| [`35-boot-in-container.sh`](35-boot-in-container.sh) | ⭐ **What can a host with only a container engine do?** | ⭐ **a BSD shell in 2.6 s**, unprivileged. 0.6 s with `/dev/kvm`. See finding 8 |
| [`lib/console.ps1`](lib/console.ps1) | not an experiment | the shared serial-console driver for the Windows half. ⛔ One copy, so `33`, `40` and `41` cannot diverge |
| [`lib/console.py`](lib/console.py) | not an experiment | ⛔ the same driver, POSIX side, carrying the same two measured tty rules |

---

## ⭐ The results worth carrying out of here

### 1. ⛔ `-cpu host` and `-cpu max` did NOT wedge QEMU on this machine

The published advice, reached independently by two projects, is that under WHPX
`-cpu host` and `-cpu max` can wedge QEMU before the guest runs an instruction,
and that a named model newer than the host does the same. ⚠ **It did not
reproduce here.** All five models booted the NetBSD kernel and behaved
identically:

| accel | `-cpu` | verdict | qemu CPU seconds at 35 s |
| --- | --- | --- | --- |
| whpx | `Icelake-Server-v7` | kernel ran, no disk | 15.41 |
| whpx | `kvm64-v1` | kernel ran, no disk | 15.73 |
| whpx | `qemu64` | kernel ran, no disk | 14.52 |
| whpx | ⛔ `host` | kernel ran, no disk | 15.34 |
| whpx | ⛔ `max` | kernel ran, no disk | 15.44 |
| tcg | `qemu64` | ⭐ **booted to a shell** | 3.98 |

⚠ **This does not falsify the original reports.** They were taken on QEMU 9.x
and on different hardware, one of them a Zen 5 AMD part. It falsifies the
prediction this repository wrote down, that this host's Model 154 CPU would
be handed a newer model and wedge. On QEMU 11.1.0 on an i7-12700H, nothing
wedged and no zero-byte serial log ever appeared. ⭐ **Prefer a named model
anyway**: it costs nothing and the failure it avoids is expensive.

### 2. ⭐ Why smolBSD boots under TCG and not under WHPX, exactly

The `-cpu` column is a red herring. The column that matters is the bus:

```text
tcg :  pv0 at mainbus0 -> qemufwcfg0 -> virtio0 (viommio @0xfeb00e00) -> ld0 -> root on dk0
whpx:  (nothing)
```

⛔ **NetBSD's paravirtual bus never attaches under WHPX**, so the QEMU
firmware-config device is never found, so virtio-mmio is never enumerated, so
there is no disk. The kernel is fine: it prints its banner, sizes memory,
attaches `com0`, and then sits at `root device:` forever.

⭐ **FreeBSD says why, in one line.** Under the same accelerator it reports:

```text
Hypervisor: Origin = "Microsoft Hv"
```

and `sysctl -n kern.vm_guest` answers `hv`, where the same FreeBSD under
Firecracker answers `kvm`. ⛔ **Under WHPX the guest sees the HOST's hypervisor
signature, not QEMU's.** FreeBSD has Hyper-V support and carries on; NetBSD's
`pv` bus is looking for QEMU and does not find it.

⚠ **So this is a guest-side limitation, not a QEMU one, and it is specific to
kernels that reach their disk only through a paravirtual bus.** A kernel with
ordinary PCI drivers is unaffected, which is why experiment 33 works with
exactly the same accelerator and CPU model.

⭐ **smolBSD is not out of reach on Windows: it is out of reach accelerated.**
Under TCG it boots to a NetBSD shell with a 499 ms kernel boot time.

### 3. ⛔ The Host Compute System is reachable and still closed

⭐ **The API half of the finding holds.** `computecore.dll` loads in an ordinary
unelevated process and all seven wanted HCS v2 entry points resolve. No patched
`wslservice.exe` and no third party is needed to reach what WSL itself calls.

⛔ **The privilege half closes it.** `HcsEnumerateComputeSystems`, which is a
**read**, returns `0x8037011B`:

```text
Insufficient privileges. Only administrators or users that are members of the
Hyper-V Administrators user group are permitted to access virtual machines or
containers.
```

`Get-VM` is refused the same way. If reading is privileged, creating certainly
is.

⚠ **And a probe defect worth keeping.** The first version of this experiment
pointed a P/Invoke at `vmcompute.dll`, caught the failure, and printed
"vmcompute.dll did not load". ⛔ **That was false.** The library loaded
perfectly; it exports 36 `Hcs*` functions and simply does not carry
`HcsCreateOperation`, which lives in `computecore.dll`. A `try`/`catch` around a
P/Invoke cannot tell "library absent" from "entry point absent", and reporting
the second as the first sends the next reader after the wrong problem.
`LoadLibrary` plus `GetProcAddress` separates them, which is what the script
does now.

### 4. ⛔ 108 of the 114 seconds are device probing, and the first write-up guessed

FreeBSD under WHPX reaches a login prompt in about 114 s. ⚠ **The first
write-up of that attributed it to `growfs`, and that was a guess.** The console
carries no `growfs` line, reports the root filesystem
`FILE SYSTEM CLEAN; SKIPPING CHECKS`, and three independent boots landed at
117.7 s, 117.4 s and 113.6 s. ⭐ The experiment now stamps four phases:

| phase, from the QEMU process starting | at | this phase cost |
| --- | --- | --- |
| loader hands off to the kernel | 4.3 s | 4.3 s |
| kernel banner | 4.3 s | 0 s |
| ⛔ **root mounted** | **112.5 s** | ⛔ **108.2 s** |
| `rc` starts | 112.8 s | 0.3 s |
| login prompt | 113.6 s | 0.8 s |

⛔ **Not the loader, not `rc`, not the filesystem, and not the network**:
removing the NIC entirely moved the total by under four seconds.

⚠ **Do not read this as a hypervisor benchmark.** The Firecracker guest that
boots in 1.8 s is a **different kernel** and a **different root filesystem**,
purpose-built with almost nothing to probe. Two variables moved at once.
⛔ **Steady-state performance under WHPX was not measured at all.**

### 5. ⭐ A container runs inside that guest, and it took three corrections

```text
$ podman run --rm ghcr.io/freebsd/freebsd-runtime:15.1 /bin/sh -c 'uname -sr; echo ...'
rc=0
Trying to pull ghcr.io/freebsd/freebsd-runtime:15.1...
Getting image source signatures
Copying blob sha256:78d645ce98ae...
Writing manifest to image destination
FreeBSD 15.1-RELEASE
CONTAINER-OK
```

⭐ **`podman info` reports `freebsd/amd64 runtime=ocijail`**, so the runtime
under it is jails, which is the whole reason a FreeBSD host was needed: the same
image on a Linux kernel exits 139. Three things had to be corrected first, and
each looked like a different problem than it was:

- ⛔ **Podman on FreeBSD defaults to the ZFS storage driver**, and the
  BASIC-CI image is UFS. Every podman verb dies with
  `could not open /dev/zfs ... prerequisites for driver not satisfied`. Set
  `driver = "vfs"` in `/usr/local/etc/containers/storage.conf`.
- ⛔ **The storage database outranks that config file.** A run that already
  failed against ZFS records the driver and then refuses to be told otherwise:
  `User-selected graph driver "vfs" overwritten by graph driver "zfs" from
  database`. Editing the config is not enough; `/var/db/containers/storage` has
  to go.
- ⛔ **Whatever is wrong with Go binaries in this guest. See finding 6**, which is the one worth reading and which does NOT end with a cause.

### 6. ⛔ Go binaries die in this guest, and the tidy explanation is wrong

⛔ **This is the most useful thing in this file, and it follows directly from
finding 2.** Under WHPX the guest sees the **host's** hypervisor signature. So:

```text
Hypervisor: Origin = "Microsoft Hv"
Timecounter "Hyper-V-TSC" frequency 10000000 Hz quality 3000
```

FreeBSD offers these, and picks the highest quality:

```text
TSC-low(-100) i8254(0) ACPI-fast(900) HPET(950) Hyper-V-TSC(3000) Hyper-V(2000)
was: Hyper-V-TSC
```

⛔ **It trusts a paravirtual clock that QEMU is only pretending to provide.**
Go's garbage collector divides by a rate derived from the monotonic clock, so
every Go binary in the guest dies:

```text
SIGFPE: floating-point exception
runtime.deductSweepCredit(0x2000, 0x0)
        /usr/local/go125/src/runtime/mgcsweep.go:948
runtime.(*mcentral).cacheSpan(...)
```

⭐ **One sysctl changes the outcome**, and nothing in that stack trace would
ever point you at a clock:

```bash
sysctl kern.timecounter.hardware=ACPI-fast
```

With that set, `podman run` pulls its image and runs a container, `rc=0`.

⛔ **BUT THE MECHANISM IS NOT ESTABLISHED, AND A LATER MEASUREMENT ARGUES
AGAINST THE OBVIOUS ONE.** This section first said the clock was the cause. Two
things then disagreed with that, and both are measurements:

- ⭐ **With `ACPI-fast` selected the clock is demonstrably correct.** Two
  reads of `date +%s%N` a second apart: `delta_ns=1002101384`. That is 1.0021
  seconds for a 1 second sleep. A clock that good does not divide by zero.
- ⛔ **A long-running Go daemon then does something worse than SIGFPE. It
  takes the guest KERNEL down.** `podman system service` panics FreeBSD:

```text
Fatal trap 12: page fault while in kernel mode
current process        = 1546 (podman)
#5 0xffffffff80bade73 at do_wait+0x123
#6 0xffffffff80bab814 at __umtx_op_wait_uint_private+0x54
#7 0xffffffff80ba8f9e at sys__umtx_op+0x7e
```

`_umtx_op` is FreeBSD's userspace-mutex syscall, and it is what Go's scheduler
parks threads on.

⚠ **So the honest reading is that something about this guest under WHPX is
wrong below the timecounter**, the timecounter change moved the symptom, and
calling it "the cause" would be a story rather than a measurement. ⛔ Recorded
this way on purpose: the first version of this section had the tidy explanation
and the tidy explanation was not supported.

⚠ **A related observation, now with company.** FreeBSD also page-faulted in
the kernel during `rc.shutdown`, in `vget_finish`, on a boot that had run
podman. ⛔ Boots that never ran podman shut down cleanly. Two kernel page
faults at different sites, both on boots that ran a multithreaded Go program,
is a pattern rather than a coincidence, and it is not diagnosed here.

### 7. ⚠ The Windows client reaches the guest, and the last hop is the daemon

[`41-connect-podman-from-windows.ps1`](41-connect-podman-from-windows.ps1) does
the client half. Everything up to the last hop works, and it is worth listing so
nobody redoes it:

| step | state |
| --- | --- |
| a throwaway key installed over the serial console | ⭐ works |
| ⛔ empty-password ssh closed **before** the port is forwarded | ⭐ works, read back from `sshd_config` |
| the port forwarded, bound to `127.0.0.1` only | ⭐ works |
| ssh from Windows into the guest | ⭐ **works**, the client authenticates |
| the podman API socket existing | ⭐ works |
| `podman system connection add` | ⭐ works, exit 0 |

⛔ **And it stops one step short, on a blocker worth naming precisely.**
`podman system service` is a **long-running Go daemon**, and it dies of `SIGFPE`
inside the Go runtime seconds after starting, leaving the socket file behind
with nothing listening. The client then gets:

```text
ssh: rejected: connect failed (open failed)
```

⭐ **It is finding 6 again, harder.** The timecounter correction that is
enough for a short-lived `podman run` is not enough for a daemon: more GC
cycles, more chances to divide by zero. ⚠ And the daemon does not merely crash itself: it panics the guest kernel in `_umtx_op`, which is finding 6's second measurement.

⚠ **What is left is one question, not one command:** can a Go daemon be
kept alive in a FreeBSD guest under WHPX. Three untried things, in order:
a timecounter chosen for the daemon rather than for a command; setting it at
boot through `/etc/sysctl.conf` so no Go binary ever runs while `Hyper-V-TSC`
is selected; or sidestepping it, since a podman connection is only an SSH URI
and the service does not have to live in that guest. ⛔ The third is a weaker
result and should be labelled as one if it is taken.

⛔ **The door is closed in the same step that opens it.** The BASIC-CI image
takes root over ssh with an empty password, so the experiment installs a key
over the console, sets `PermitEmptyPasswords no`, `PasswordAuthentication no`
and `PermitRootLogin prohibit-password`, restarts `sshd`, and only then forwards
a port, bound to loopback. The connection is removed again at the end.

### 8. ⭐ The host does not have to provide anything at all

⛔ **This is the result that changes what this repository should publish.**

| the host has | time to a BSD shell that answers |
| --- | --- |
| ⭐ podman or docker, and nothing else | ⭐ **2.6 s** |
| the same, plus `--device /dev/kvm` | ⭐ **0.6 s** |

⭐ **Acceleration is worth about two seconds**, and it is not the difference
between usable and unusable. Both are fast enough that a consumer never thinks
about it.

⚠ **Why pure emulation is this fast**, which surprises people: the guest is
a **microvm**. There is almost no firmware, almost no device probing and no
disk controller to enumerate, so very few instructions run before a shell
appears. ⛔ Compare finding 4: a stock general-purpose kernel on an emulated
machine spends 108 seconds probing devices, accelerated.

⛔ **What it is not.** It is NetBSD, not FreeBSD; it is a rescue userland with
no `uname` and no package manager; and compute inside it is emulated, so it is
the wrong place to build anything.

⚠ **And it is not packaged.** ⛔ **This repository publishes no image
that does this.** The route is measured, the packaging is not built, and that is
the highest-value open task.

⚠ **A defect worth keeping.** The first version asserted on `uname -sr` and
reported `answered=no` over a guest answering perfectly through `sysctl`, because
the rescue image ships no `uname`. ⭐ Assert with something the guest
actually has, and confirm what that is before writing the assertion.

---

## ⭐ What to write next

1. ⛔ **Package finding 8 as a published image.** `podman run --rm -it
   ghcr.io/pkgforge-dev/freebsd:latest sh` should do what
   [`35-boot-in-container.sh`](35-boot-in-container.sh) measures, with the
   emulator, the kernel and the root filesystem baked into layers rather than
   fetched and bind-mounted. ⭐ It is the single highest-value thing in this
   list and everything else is smaller.
2. ⛔ **Keep a Go daemon alive under the Windows hypervisor.** Finding 7 is
   the only thing between here and `BSD-01`'s acceptance command, and finding 6
   says the tidy explanation is not the answer.
3. **Cut the 108-second device probe.** Finding 4 says where the time goes on
   the FreeBSD route. Finding 8 says a leaner guest does not pay it at all,
   which is the obvious lead.
4. ⚠ **A second host.** Every number here is from one Windows machine, and
   no Linux host, no macOS host and no arm64 host has been measured at all.
