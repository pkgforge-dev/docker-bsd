# LIMITS.md

⭐ **What this project can and cannot do today, with the cost of each route in
seconds.** ⛔ **This is the only page in the repository carrying those
numbers.** Everything else points here, so there is nothing to cross-check and
nothing to drift.

⚠ **Most numbers here were measured on one machine**, described once in
[`environment.md`](environment.md). ⭐ **Section 1b is the exception**: it was
measured on a free GitHub runner, which is a Linux host and also a cloud
virtual machine. ⛔ Nothing here has been measured on macOS, on arm64, or on
Linux running on hardware somebody owns.

⛔ **A limit here is measured or it is labelled.** Never estimated.

---

## ⭐ The short answer

| you have | you get | you wait | privilege |
| --- | --- | --- | --- |
| ⭐ **only podman or docker** | a **NetBSD** shell | ⭐ **2.6 s** | ⭐ **none** |
| ⭐ the same, plus `--device /dev/kvm` | the same shell | ⭐ **0.6 s** | one device |
| ⭐ **the published image**, on a free CI runner | a **NetBSD** shell | ⭐ **2.9 to 4.2 s** | ⭐ **none** |
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
| ⭐ `netbsd:latest` | rescue. A shell and `sysctl` | **155 MB** | ⭐ **2927 ms** and **4157 ms** |
| `netbsd:build` | ⭐ **real**, with `uname`, `make`, `pkg_add` and `pkgin` | **2291 MB**, grown to hold a toolchain | **13137 ms** and **12959 ms** |

### ⭐ Where the 155 MB goes, which is what `OPT-02` needs and did not have

Measured 2026-08-28 with `du -sx` inside the published image. ⛔ **Only a fifth
of it is the BSD.**

| what | on disk | what it is |
| --- | --- | --- |
| ⭐ `/guest` | **29.4 MB** | the guest kernel and root filesystem. ⛔ **The irreducible part** |
| ⛔ `/usr/lib/python3.12` | **30.2 MB** | the interpreter for the driver |
| `/usr/bin/qemu-system-x86_64` | 24.6 MB | one emulator binary, built to emulate anything |
| `/usr/share/qemu` | 16.8 MB | firmware and ROM blobs. ⚠ A `microvm` guest loads almost none of them |
| everything else | about 53 MB | the base, its libc, and the rest of the emulator's dependencies |

⛔ **The driver those 30.2 MB exist to run is 15 KB of source**: `console.py` at
5,674 bytes, `guest.py` at 8,417, and `entrypoint.sh` at 1,554. ⚠ On a `scratch`
base there is no `python3` **and no `/bin/sh`**, so all three become one static
binary or none of them ship.

⚠ **This is a size measurement and not a recommendation.** `OPT-02` owns the
decision and [`../TODO/PROGRESS.md`](../TODO/PROGRESS.md) says no `OPT` lever is
pulled before `PERF-02` says which layer is actually stuck.

### ⛔ TWO NUMBERS PER ROW, AND THAT IS THE MOST IMPORTANT THING ON THIS PAGE

⚠ **Those pairs are two runs of the same command on the same image, hours
apart, each a median of five.** The rescue variant answered in **2927 ms**
(2920 to 2935) on one runner and **4157 ms** (3757 to 4162) on another.

⛔ **That is a 42 percent spread between runs, and under 1 percent within a
run.** A free runner is a shared machine and its neighbours are not visible.

⭐ **What that means for `PERF-03`, which has a 5 percent gate:** a ratio built
from two numbers taken in different jobs cannot see 5 percent, because the
runner moves by eight times that between jobs. ⛔ **Both sides have to be
measured in the same job**, which [`RULES.md`](../TODO/RULES.md) decision 2
already requires for a different reason, and the run-to-run figure is what makes
that requirement load bearing rather than tidy.

⚠ **The build variant did not move**, 12959 and 13137, which is under 2 percent.
⛔ **Do not read that as it being more stable.** Two samples of each is not a
distribution, and the honest statement is that one pair moved a lot and one did
not.

⚠ **The runner and the laptop are within about half a second of each other on
this**, which is worth noticing and not worth explaining: the laptop's own
figure with the published image is 3629 ms, over the same command. ⛔ **Neither is comparable to
the 2.6 s in section 1**, which timed the guest reaching a prompt inside an
already-running container rather than a whole `podman run`. Subtracting one from
the other would be inventing a number.

⛔ **The build variant costs three times as long to reach a shell and is
fifteen times the size**, and that is the price of a userland that can do
something rather than answer.

### ⛔ AND YOU CANNOT WRITE ANYTHING LARGE INTO IT. Measured 2026-08-28

⚠ **This is the limit a consumer of the build variant actually hits**, and it
has nothing to do with the package manager.

| the same 490 MB, the same 1,664 files, in the same guest | result |
| --- | --- |
| `tar` onto the guest's **root filesystem** | ⛔ **had not finished after 900 s**, and `pkg_add` has been watched not finishing for 45 minutes |
| `tar` into a **tmpfs** mounted in that guest | ⭐ **finished** |

⭐ **So it is the filesystem, not the writer and not the emulator.** The guest
root is ext2 with **1 KB blocks over 2 GB and no features at all**, because
this repository grows a small published image with `resize2fs`, which cannot
change a block size. ⛔ **The process spends 100 percent of its time in the
kernel and executes no userland instruction for the whole run.** `INF-09` in
[`../TODO/infrastructure.md`](../TODO/infrastructure.md) carries the readings
and the eight explanations that are dead.

⚠ **So the build variant has a package manager, a network and no compiler**,
and installing one is what does not finish.

### ⛔ `--device /dev/kvm` does NOT accelerate anything on a free runner

⭐ **This is the most useful thing measured on the runner, and it was nearly
published backwards.**

The first measurement said the device made the boot **slower**, consistently.
That reads as a claim about acceleration and it is not one. ⛔ **Measured again
with a harness that reports which accelerator actually ran, and with the
container's own view of the device read rather than assumed:**

⚠ **All three rows are from ONE run**, so they are comparable with each other
and not with the table above.

| what was passed | what the guest used | median |
| --- | --- | --- |
| nothing | `tcg` | **2927 ms** |
| ⛔ `--device /dev/kvm` | ⛔ **`tcg`, after trying and failing** | 3425 ms |
| ⛔ the same, plus `--group-add keep-groups` | ⛔ **`tcg`, still** | 3425 ms |

⭐ **And the image now says why, in its own words**, which is what the harness
reports beside the accelerator:

```text
accel    tcg
note     netbsd: /dev/kvm was handed in and the emulator could not use it,
         so this is running unaccelerated.
```

⛔ **The device reaches the container and the emulator cannot open it.** Read
from inside the container, with the device handed in:

```text
crw-rw----  1 nobody  nobody  10, 232  /dev/kvm
uid=0(root) gid=0(root) groups=0(root),...
```

⚠ **The engine is rootless**, so the host's `root:kvm` ownership arrives as
`nobody:nobody`, the mode grants nothing to other, and the process is root only
inside a user namespace. ⛔ **It is neither the owner nor in the group.**

⭐ **And the obvious test for that does not work.** `test -r /dev/kvm` and
`test -w /dev/kvm` both answer **yes** in that container, because for uid 0 they
are not a real permission check. The emulator's own `open` is, and it fails.
⛔ **This page said the image never tried. It tried, failed in under a second,
and fell back**, which is the behaviour it was built to have and was not the
behaviour described here.

⚠ **So the honest statement is not "acceleration is slower on CI".** It is
**"acceleration could not be turned on"**, and the ~500 ms is the price of
asking for a device and having the attempt fail.

⭐ **What a consumer should take from this:** on a rootless engine, handing in
`/dev/kvm` is not enough, and a shell test that says the node is readable is not
evidence that it is usable. ⚠ **What would make it work on a runner is not
measured here.** `--group-add keep-groups` was tried and changed nothing.

### ⛔ NARROWED 2026-08-28: this is about the CONTAINER, not about the runner

⚠ **The heading above says "on a free runner" and that is too broad.** Everything
measured here was measured **inside a rootless container**. ⛔ **A QEMU process
running on the runner itself does get working KVM**, and somebody else has been
relying on it in production for years: `cross-platform-actions/action` boots
FreeBSD, OpenBSD and NetBSD guests on `ubuntu-latest` with
`-machine accel=hvf:kvm:tcg` and hardware acceleration enabled.
[`../HISTORY/references/usable.md`](../HISTORY/references/usable.md), the `R31`
section.

⛔ **So the honest statement narrows again**, and this is the third time this
claim has been rewritten:

| the claim | state |
| --- | --- |
| "a free runner cannot use `/dev/kvm`" | ⛔ **wrong.** Withdrawn |
| "a rootless container on a free runner cannot open `/dev/kvm` when the device is handed in" | ⭐ **measured here**, and still stands |
| what would make the container able to open it | ⚠ **still not measured.** `R17`'s `udev` rule is the nearest published answer and was not tried |

⛔ **And there is a trap waiting on the day it does work.** With KVM the guest
sees the host CPU, and `images/netbsd/guest.py` asks for `-cpu host,+invtsc`.
⛔ **A NetBSD guest given a host CPU with AMX jumps to address 0 while starting
init**, measured by somebody else across 16 restarts of the same job. The
feature mask that fixes it is in the `R31` section.

⭐ **Note what none of this touches.** Boot time is not throughput. A guest that
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

⭐ **Two hosts now, not one, and the second is a free GitHub runner.** The
command is [`../scripts/time-image`](../scripts/time-image), which takes an
image reference and prints a `RESULT` line, so a stranger can produce a
comparable figure.

| host | state |
| --- | --- |
| ⭐ Windows, via a podman machine, with the **published image** | ⭐ **measured.** `RESULT device=none accel=tcg median_ms=3629` |
| ⭐ **GitHub CI, `ubuntu-latest`, `x86_64`** | ⭐ **measured.** See section 1b |
| native Linux, on hardware somebody owns | ⚠ **still inferred.** A GitHub runner is a Linux host and it is also a virtual machine in a cloud, which is not the same question as a laptop running Linux |
| CI, arm64 | ⛔ **expected to fail as written.** The artefacts are `amd64`, so it would be emulating a foreign architecture as well as a foreign operating system |
| macOS | ⛔ **not attempted.** Nobody here has one |

⛔ **So "it works everywhere" is still not a claim this repository can make.**
It has two datapoints and two named gaps, which is different from one datapoint
and an expectation.

### ⭐ What `/dev/kvm` is worth, and it is not the same in both places

⛔ **Measured with a harness that reports which accelerator actually ran**,
because handing in the device is not the same as using it: the node can be
present and unopenable, and the image falls back to emulation silently and
correctly.

| host | no device | with `--device /dev/kvm` |
| --- | --- | --- |
| ⭐ the Windows laptop's podman machine | `accel=tcg`, **3604 ms** | ⭐ `accel=kvm`, **1777 ms** |
| a free GitHub runner | ⚠ see section 1b. The first measurement said the device made it **slower**, and could not say which accelerator it used, so it is withdrawn rather than published |

⚠ **The laptop's `/dev/kvm` is itself nested**, inside the WSL2 machine, and a
runner's is nested inside a cloud VM. ⛔ **Neither is bare metal**, and nothing
here has measured one that is.

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
- ⚠ **Anything about OpenBSD.** It has an image here and no measured way to
  run it. ⛔ DragonFly was dropped on 2026-08-28:
  [`../HISTORY/dragonfly.md`](../HISTORY/dragonfly.md).
