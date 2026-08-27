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
| ⭐ **the published image**, on a free CI runner | a **NetBSD** shell | ⭐ **3.0 s** | ⭐ **none** |
| an emulator, and Windows | a **FreeBSD 15.1** userland, full GENERIC | ⚠ **114 to 118 s** | ⭐ none |
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
- ⛔ **It is a rescue userland.** It has `sysctl` and a shell. It does **not**
  have `uname`, `tail`, or a package manager.
- ⚠ **Compute inside it is emulated**, so it is the wrong place to build
  anything. Reaching a shell is cheap because the work is small.

---

## ⭐ 1b. The published image, measured on a free GitHub runner

⭐ **The route in section 1 is now packaged, and the packaging was measured
where it will be used.** [`RULES.md`](../TODO/RULES.md) decision 2: the baseline
is a free runner, not the developer's laptop.

```bash
podman run --rm -it ghcr.io/pkgforge-dev/netbsd:latest sh
```

⛔ **Nothing is fetched at run time.** The emulator, the guest kernel and the
guest root filesystem are in layers. The same run with `--network none` reaches
the same shell, which is what proves it.

### The conditions, so the numbers mean something

| | |
| --- | --- |
| runner | `ubuntu-latest`, Linux 6.17.0-1022-azure x86_64, **4 vCPU** |
| engine | podman, rootless, no `--privileged`, no capability |
| `/dev/kvm` on the runner | ⭐ **present**, `crw-rw---- root kvm` |
| what is timed | ⛔ **the whole `podman run`**, to the guest's answer on stdout. Not the kernel's own boot time |
| how | median of five, by [`../scripts/time-image`](../scripts/time-image) |

### What it costs

| variant | userland | image | to an answer, no device |
| --- | --- | --- | --- |
| ⭐ `netbsd:latest` | rescue. A shell and `sysctl` | **155 MB** | ⭐ **2981 ms** (2918 to 3031) |
| `netbsd:build` | ⭐ **real**, with `uname`, `make`, `pkg_add`, `pkgin` | 671 MB before provisioning | **11518 ms** (10917 to 11525) |

⚠ **The runner is about 400 ms slower to a shell than the laptop in section 1**,
over a different measurement: section 1 timed the guest reaching a prompt inside
an already-running container, and this times `podman run` end to end. ⛔ **They
are not the same quantity and subtracting one from the other would be
inventing a number.**

⛔ **The build variant costs four times as long to reach a shell**, and that is
the price of a userland that can do something rather than answer.

### ⚠ What `--device /dev/kvm` did on the runner, and why it is not published

⛔ **The first runner measurement said acceleration made the boot SLOWER**:
3442 ms against 2981 ms, consistently, across five runs each.

⚠ **That result is withdrawn until the harness can tell what it measured.** The
image falls back to emulation, correctly and silently, when `/dev/kvm` is
present and cannot be opened, which is the ordinary case for a rootless
container. So the comparison may have been between an unaccelerated run and a
slightly slower unaccelerated run, and the flag's only effect was the device
setup. [`../scripts/time-image`](../scripts/time-image) now reports which
accelerator actually ran, and the answer goes here when it has been read rather
than assumed.

⭐ **Note what this does not touch.** Boot time is not throughput. A guest that
executes very few instructions before reaching a prompt is the case where an
accelerator has least to win, and a compile is the opposite case.

---

## ⛔ 1a. The five questions a consumer actually asks about route 1

⚠ **Answered here because the 2.6 seconds is the attractive half and these
are the half that decides whether the project is useful.** Each answer says
whether it is measured or inferred.

### Q. How does it work? Is it an emulator inside a Linux container?

⭐ **Yes, exactly that, and there is no trick beyond it.**

```text
your host (any OS with a container engine)
  |
  +-- an ordinary Linux container, unprivileged
       |
       +-- qemu-system-x86_64, an ordinary userspace process
            |
            +-- a NetBSD microvm kernel and root filesystem
                 |
                 +-- its serial console, wired to the container's stdio
```

⭐ **Nothing is kernel-level and nothing needs privilege.** The container
does not need `binfmt_misc`, a device, a capability or root, because the guest
is not being executed by the host kernel at all: it is being **interpreted** by
a normal program that happens to live in the image.

⛔ **What that means for `--platform`, `binfmt` and friends: they are
irrelevant here.** They translate a foreign **architecture** presenting Linux
syscalls. This is a foreign **operating system**, and route 1 sidesteps it by
not asking the host kernel to run BSD code at all.

### Q. Does it work everywhere? On Linux? On CI?

⚠ **MEASURED ON EXACTLY ONE PATH**: a container running inside the WSL2
Linux machine on one Windows host, with podman.

| host | state |
| --- | --- |
| Windows, via a podman or docker machine | ⭐ **measured** |
| native Linux | ⚠ **INFERRED, not measured.** The container is a Linux container either way, so a native host is the same code path with one layer removed. Nothing has run it |
| GitHub CI, `x86_64` | ⚠ **inferred.** The unaccelerated path needs nothing a runner lacks. `/dev/kvm` on those runners is a sourced claim, not one measured here |
| CI, arm64 | ⛔ **expected to fail as written.** The artefacts are `amd64`, and those runners have no `/dev/kvm`, so it would be emulating a foreign architecture as well as a foreign OS |
| macOS | ⛔ **not attempted** |

⛔ **So "it works everywhere" is not a claim this repository can make today.**
It is a reasonable expectation with one datapoint under it.

### Q. Do I really need no setup, and do my usual flags work?

⭐ **For a shell: yes.** `podman run --rm -it IMAGE` and you are in a BSD
shell. `-it` is not optional, because what you are being given is a console.

⛔ **For anything else: no, and this is the biggest gap in route 1.**

| the flag you know | what actually happens |
| --- | --- |
| `-v /host/path:/in/container` | ⛔ **reaches the CONTAINER, not the guest.** The BSD has its own root filesystem and cannot see the mount |
| `-p 8080:80` | ⛔ **reaches the container.** Nothing forwards it into the guest |
| `-e FOO=bar` | ⛔ the same. The guest does not inherit the container's environment |
| `--device /dev/kvm` | ⭐ **works, and is the one that helps.** Worth about two seconds |
| `--rm`, `-it`, `--name` | ⭐ work normally: they are about the container |

⚠ **All three of the first row are solvable** with a shared filesystem and
a port forward inside the emulator, and none of it is built. That is a filed
task, not a law of nature.

### Q. Is this better than a toy? Can I install Rust and build a FreeBSD binary?

⛔ **No. Not with what is published today, and the honest answer is worth
more than an encouraging one.**

| why not | detail |
| --- | --- |
| ⛔ it is **NetBSD**, not FreeBSD | the microvm that boots in 2.6 s is NetBSD's. There is no equivalent published FreeBSD one |
| ⛔ it is a **rescue** userland | about 20 MB. No package manager, no `uname`, no compiler, no `pkgin`. It is a shell and a kernel |
| ⛔ there is **no persistence** | `--rm` and a read-only-shaped workflow; nothing carries a build out |
| ⚠ compute is **emulated** without `/dev/kvm` | fine for reaching a prompt, wrong for a compile |

⭐ **What would make it real**, and none of it is measured:

1. a full BSD root filesystem in the microvm instead of a rescue one, with a
   package manager;
2. a shared filesystem, so a source tree on the host is visible in the guest;
3. `/dev/kvm` when it is available, so the compile is virtualised and not
   interpreted;
4. ⛔ **a measured build**, of something real, with a number beside it.

⚠ **Until 4 exists, treat route 1 as a demonstration that the shape works,
not as a development environment.** That is what it is.

### Q. What does it cost when it IS doing real work?

⛔ **UNKNOWN. Nothing in this repository has measured throughput of any kind.**

⚠ The only adjacent number is a warning rather than a guide: a stock
general-purpose FreeBSD kernel on the Windows hypervisor spends **108 seconds**
probing devices before it mounts a root filesystem, **accelerated**. That says
IO through that path is expensive; it does not say what a compile costs, and
extrapolating from it would be inventing a number.

---

## 2. Windows, from a machine with nothing installed

⭐ **To the best version: a full FreeBSD 15.1 userland on the machine's own
hypervisor, unelevated.**

| step | what | cost |
| --- | --- | --- |
| 1 | install an emulator. `scoop install qemu`, or the QEMU installer | ⚠ 197 MB |
| 2 | ⭐ **check the hypervisor is reachable.** One unelevated call, in [`environment.md`](environment.md) | seconds |
| 3 | `sh experiments/21-fetch-freebsd-ci.sh` | ⚠ 666 MB, expands to 6.03 GB |
| 4 | `pwsh -NoProfile -File experiments/33-boot-freebsd-whpx.ps1` | ⚠ **114 to 118 s to a login prompt** |

⛔ **WSL is not required. Podman is not required. Administrator is not
required.**

### ⚠ Where the time goes, measured

⛔ **Three boots, not one: 113.6 s, 117.4 s and 117.7 s.** The table below is
the phase breakdown of the fastest of them, and the range is quoted above
rather than the best number, because quoting the best one is how a benchmark
becomes a claim.

| phase | at | this phase |
| --- | --- | --- |
| the loader hands off | 4.3 s | 4.3 s |
| the kernel banner | 4.3 s | 0 s |
| ⛔ **the root filesystem is mounted** | **112.5 s** | ⛔ **108.2 s** |
| `rc` starts | 112.8 s | 0.3 s |
| a login prompt | 113.6 s | 0.8 s |

⛔ **108 of those seconds are device probing**, between the kernel banner and
mounting root. ⚠ Not the loader, not `rc`, not the filesystem and not the
network: removing the network device moved the total by under four seconds.
⭐ **It is the single biggest addressable cost on this route.**

### ⛔ Two settings that are not optional on this route

- ⛔ **Use a named CPU model no newer than the host.** Not `host`, not `max`.
  ⚠ Published reports say those wedge the emulator; they did not here, and
  the safe choice costs nothing. [`traps.md`](traps.md) row 6.
- ⛔ **Pass `-nic none` if you mean no network.** The emulator attaches one
  otherwise. [`traps.md`](traps.md) row 3.

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

⚠ **A workaround exists for short-lived Go programs and not for the
daemon**: selecting a different guest timecounter moves `podman run` to `rc=0`.
⛔ **It is not a fix and the cause is not known.** With that timecounter the
clock is measurably correct and the daemon still takes the kernel down.
[`../HISTORY/README.md`](../HISTORY/README.md) records what was believed and
withdrawn.

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
