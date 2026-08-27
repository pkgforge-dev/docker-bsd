# LIMITS.md

⭐ **What this project can and cannot do today, with the cost of each route in
seconds.** ⛔ **This is the only page in the repository carrying those
numbers.** Everything else points here, so there is nothing to cross-check and
nothing to drift.

⚠ **Every number was measured on one machine**, described once in
[`environment.md`](environment.md). ⛔ Nothing here has been measured on a Linux
host, on macOS, or on arm64.

⛔ **A limit here is measured or it is labelled.** Never estimated.

---

## ⭐ The short answer

| you have | you get | you wait | privilege |
| --- | --- | --- | --- |
| ⭐ **only podman or docker** | a **NetBSD** shell | ⭐ **2.6 s** | ⭐ **none** |
| ⭐ the same, plus `--device /dev/kvm` | the same shell | ⭐ **0.6 s** | one device |
| an emulator, and Windows | a **FreeBSD 15.1** userland, full GENERIC | 114 s | ⭐ none |
| a Linux host or WSL2 machine with `/dev/kvm` | a **FreeBSD 15.1** userland | 1.8 s | write access to `/dev/kvm` |
| a BSD host already | ⭐ `podman run` on the images this repository publishes | seconds | none |

⛔ **What you cannot get, on any host, at any price:** a BSD userland on a Linux
kernel. [`traps.md`](traps.md) row 1 has the measurement and why no amount of
`binfmt_misc` reaches it.

---

## ⭐ 1. The route that needs nothing: a container engine

⛔ **This is the answer to "I just want a BSD shell and I am not installing
anything."**

⭐ **The trick is that the emulator ships INSIDE the image.** A container is a
Linux process and an emulator is a Linux process, so the host contributes
nothing but a container engine. No emulator on the host, no hypervisor, no
`binfmt_misc`, no root, no `--privileged`, no `--cap-add`, no `--device`.

Measured 2026-08-27 by [`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh):

```text
shell reached after 2.6s
$ sysctl -n kern.ostype      smolBSD
$ sysctl -n kern.osrelease   11.0_STABLE
$ sysctl -n hw.machine       amd64
$ sysctl -n kern.version     smolBSD 11.0_STABLE (SMOL) #17: Wed Aug 12 07:01:53 CEST 2026
```

| | |
| --- | --- |
| ⭐ time to a shell that answers, **unaccelerated** | **2.6 s** |
| ⭐ the same with `--device /dev/kvm` | ⭐ **0.6 s** |
| privilege | ⭐ **none** for the 2.6 s case. No `--privileged`, no capability, no device |
| host emulator | ⭐ **none.** It is in the image |
| what runs | NetBSD 11, as a microvm |
| what answers | the guest kernel, through `sysctl` |

⭐ **So acceleration is worth about 2 seconds here, and it is not the
difference between usable and unusable.** ⛔ That is the number that decides
the shape of this project: a consumer with nothing but a container engine pays
two seconds more than a consumer who hands in a device, and both are fast enough
that neither has to think about it.

⚠ **Why it is fast under pure emulation**, which surprises people: the guest is
a **microvm** with a kernel built for it. There is almost no firmware, almost no
device probing and no disk controller to enumerate. ⛔ **Emulation is slow per
instruction and this guest executes very few of them before it reaches a
shell.**

### ⛔ What this route does not give you

⚠ Stated plainly, because the 2.6 s is the attractive half.

- ⛔ **It is NetBSD, not FreeBSD.** The microvm that boots this fast is
  NetBSD's. FreeBSD has no equivalent published today.
- ⛔ **It is a rescue userland.** It has `sysctl` and a shell; it does **not**
  have `uname`, `tail`, or a package manager. ⚠ A first version of the
  experiment asserted on `uname` and reported failure over a guest that was
  answering correctly.
- ⚠ **Compute inside it is emulated**, so it is the wrong place to build
  anything. Reaching a shell is cheap because the work is small.
- ⚠ **`podman run --rm -it ghcr.io/pkgforge-dev/freebsd:latest sh` does not do
  this yet.** ⛔ **This repository does not publish that image.** The route is
  measured; the packaging is not built. It is the highest-value open task.

---

## 2. Windows, from a machine with nothing installed

⭐ **To the best version: a full FreeBSD 15.1 userland on the machine's own
hypervisor, unelevated.**

| step | what | cost |
| --- | --- | --- |
| 1 | install an emulator. `scoop install qemu`, or the QEMU installer | ⚠ 197 MB |
| 2 | ⭐ **check the hypervisor is reachable.** One unelevated call, in [`environment.md`](environment.md) | seconds |
| 3 | `sh experiments/21-fetch-freebsd-ci.sh` | ⚠ 666 MB, expands to 6.03 GB |
| 4 | `pwsh -NoProfile -File experiments/33-boot-freebsd-whpx.ps1` | ⭐ **114 s to a login prompt** |

⛔ **WSL is not required. Podman is not required. Administrator is not
required.**

### ⚠ Where the 114 seconds go, measured

| phase | at | this phase |
| --- | --- | --- |
| the loader hands off | 4.3 s | 4.3 s |
| the kernel banner | 4.3 s | 0 s |
| ⛔ **the root filesystem is mounted** | **112.5 s** | ⛔ **108.2 s** |
| `rc` starts | 112.8 s | 0.3 s |
| a login prompt | 113.6 s | 0.8 s |

⛔ **108 of the 114 seconds are device probing**, between the kernel banner and
mounting root. ⚠ Not the loader, not `rc`, not the filesystem, and not the
network: removing the network device entirely moved the total by under four
seconds. ⭐ **That is the single biggest addressable cost in this project.**

### ⛔ Two settings that are not optional on this route

- ⛔ **Never `-cpu host` and never `-cpu max`** under this hypervisor, and never
  a named model newer than the host. ⚠ On this machine none of them wedged the
  emulator, against published reports; the safe choice costs nothing and the
  failure it avoids is a long hang with no output. [`traps.md`](traps.md) row 6.
- ⛔ **Pass `-nic none` if you mean no network.** [`traps.md`](traps.md) row 3.

---

## 3. Linux, from a machine with nothing installed

⚠ **NOT MEASURED.** ⛔ No Linux host has been tested, and this section says what
is known rather than what was run.

| | |
| --- | --- |
| ⭐ what is measured | a FreeBSD microvm reaching a login prompt in **1.8 s** on nested `/dev/kvm` **inside a WSL2 machine**, by [`../experiments/31-boot-freebsd-firecracker.sh`](../experiments/31-boot-freebsd-firecracker.sh) |
| ⚠ what that is evidence for | ⭐ the same script on a **native** Linux host should be at least as fast, because it removes a layer. ⛔ **That is an inference, not a measurement** |
| what it needs | a readable and writable `/dev/kvm`, and a tap device, so root or a group membership |
| ⚠ the cost after boot | **30 s more** before ssh answers, and none of it is FreeBSD booting: `sshd` reverse-resolves the client and this setup deliberately provides no resolver |

⛔ **The route in section 1 also works on Linux and needs none of this.**

---

## 4. Routes that are closed, and why

| route | state | the measurement |
| --- | --- | --- |
| a BSD userland on a Linux kernel | ⛔ **closed forever** | exits 139, a SIGSEGV, on its first syscall. Not `Exec format error`, so no `binfmt_misc` reaches it |
| the Windows Host Compute System, directly | ⛔ **closed without administrator** | its library binds fine in an ordinary process, and then even **reading** the compute systems is refused: `0x8037011B`, Hyper-V Administrators only |
| a Hyper-V guest | ⚠ **untested, and now known to cost more** | it needs the elevation the recommended route does not |
| NetBSD's microvm **accelerated** on Windows | ⛔ **closed today** | the guest's paravirtual bus never attaches under that hypervisor, so the kernel boots and never finds its disk. Unaccelerated it works, which is route 1 |
| patching the WSL service to host a BSD | ⛔ **refused** | it means running a rebuilt Windows service that also runs the machine everything else here depends on |

---

## 5. ⛔ The hard blocker, stated once

⭐ **A one-shot `podman run` inside a FreeBSD guest works.** `rc=0`, on
`ocijail`, with the container's own output read back.

⛔ **A long-running `podman system service` does not. It panics the guest
kernel:**

```text
Fatal trap 12: page fault while in kernel mode
current process        = 1546 (podman)
#5 do_wait+0x123   #6 __umtx_op_wait_uint_private+0x54   #7 sys__umtx_op+0x7e
```

`_umtx_op` is FreeBSD's userspace-mutex syscall, and it is what a Go scheduler
parks threads on.

⚠ **So `podman -c freebsd run` from a Windows client does not work yet**, and
everything underneath it does: the key, the closed password door, the forwarded
loopback port, the authenticated ssh, and the connection.

⛔ **And one explanation was published and withdrawn.** Selecting a different
guest timecounter moves a short-lived Go program from failing to working, which
looked like the cause. It is not: with that timecounter the clock is measurably
correct and the daemon still takes the kernel down.
[`../TODO/bsd.md`](../TODO/bsd.md) carries the correction under the claim.

---

## 6. ⚠ What is not measured, so it is not claimed

⛔ Each of these is a gap somebody could close, and none is a number here.

- ⛔ **Steady-state performance anywhere.** Only time-to-shell was measured. A
  slow device probe hints that IO is expensive under that hypervisor, and
  nothing tested whether that follows the guest into real work.
- ⛔ **Any Linux host.** Section 3.
- ⛔ **Any arm64 anything.** All artefacts used are `amd64`.
- ⛔ **macOS.** Not attempted.
- ⚠ **Whether the 2.6 s route survives being packaged as an image.** It was
  measured with the artefacts on a bind mount, not baked into a layer.
- ⚠ **Anything about the other two BSDs.** OpenBSD and DragonFly have images
  here and no measured way to run them.
