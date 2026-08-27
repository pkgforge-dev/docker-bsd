# SUMMARY.md

⭐ **The brief. Read this in full, first, every session.** It is the fastest
orientation into what the last session actually did.
[`PROGRESS.md`](PROGRESS.md) is what to read next, and it is the authority on
what to do.

⛔ Overwritten each session. It is a snapshot, not a log. The log is
[`../HISTORY/`](../HISTORY/) and the git history.

---

## 2026-08-27, the session that booted a BSD and made this repository standalone

| row | before | after |
| --- | --- | --- |
| **Elapsed** | 2026-08-27T12:54:52Z | about 3 hours |
| **Commits** | `878e286` | ⭐ **one squashed root commit**, then one more. `main` is protected, with admin bypass left on |
| **Work** | 1 assigned: reach a BSD userland from Windows | ⭐ **reached, and then overtaken by a better route.** ⚠ `BSD-01` stays open on its own acceptance command, and is no longer the headline |
| **Changes** | 6 tracked files | ⭐ **9 new experiments**, a shared console driver in **two** languages, and the whole of this repository's own tooling, conventions and record, vendored and adapted |
| **Checks** | `sh tests/run.sh`, 27 passed | ⭐ same, plus a 12-check gate this repository now owns |
| **Cost** | | no money. ⚠ about **1.0 GB downloaded**, and **7.4 GB of scratch left on disk**, all in ignored directories |
| **Health** | not standalone, 2 entries | ⭐ **standalone**, **19 entries**, 2 of them P0, every one filed from a measurement. Seven deep reviews, each naming what it did not look at |

---

## ⭐ What was reached

⛔ **The ask was a BSD that boots on an ordinary machine, not a plan for one.**

```text
FreeBSD freebsd 15.1-RELEASE FreeBSD 15.1-RELEASE releng/15.1-n283562 GENERIC amd64
BSD userland is running as root on FreeBSD
```

On a **Windows** host, on the machine's **own hypervisor**, **unelevated**, with
**no nesting**. A container runs inside it, `rc=0`, on `ocijail`.

⭐ **The exact command, the timings and the conditions are in
[`../docs/LIMITS.md`](../docs/LIMITS.md).** They are not repeated here: one
fact, one home.

---

## ⛔ The honest answer to "can I actually use this"

⚠ **Read this before the findings.** The time-to-a-shell is the attractive
half; this is the half that decides whether the project is worth continuing.

| the question | the answer today |
| --- | --- |
| how does it work | ⭐ an emulator **inside** a Linux container, booting a BSD microvm, console wired to the container's stdio. No privilege, nothing kernel-level |
| does it work on Linux, on CI | ⚠ **inferred, not measured.** One Windows laptop is the whole sample |
| do my usual flags work | ⛔ **`-v`, `-p` and `-e` do NOT reach the guest.** It is a VM inside the container |
| can I install a compiler and build a BSD binary | ⛔ **no.** It is NetBSD not FreeBSD, a 20 MB rescue userland, no package manager, nothing persists |
| what does real work cost | ⛔ **unknown.** Nothing here has measured throughput of any kind |
| would I switch from a cross toolchain | ⛔ **no evidence either way.** That is `PERF-02` and `PERF-03`, and the bar is 5 percent |
| can I get it without a registry | ⛔ **not today.** Every route starts with a network fetch. `INF-04` |

⭐ **All five are in [`../docs/LIMITS.md`](../docs/LIMITS.md) with the
evidence, and all five now have an entry against them.** ⛔ Three of the
answers are "no", and a project that hides those is a project that surprises
somebody later.

---

## ⭐ The six findings that change what the next session does

1. ⭐ **The Windows hypervisor presents the HOST's identity to the guest**, not
   the emulator's. `Hypervisor: Origin = "Microsoft Hv"`. ⛔ **Everything else
   below follows from that one line**, which is why it is first.
2. ⛔ **So NetBSD's paravirtual bus never attaches**, and smolBSD boots a kernel
   that never finds its disk. The same image unaccelerated boots to a shell in
   499 ms of kernel time.
3. ⛔ **And Go binaries misbehave in the guest, and the tidy explanation is
   wrong.** FreeBSD picks a Hyper-V timecounter and every Go binary dies of
   `SIGFPE` in the garbage collector; one sysctl moves `podman run` to `rc=0`.
   ⛔ **But the clock then measurably works**, and a long-running Go daemon
   **panics the guest kernel** in `_umtx_op`. ⚠ The sysctl moved the symptom; it
   did not explain it. This repository published the tidy version and withdrew
   it in the same session.
4. ⛔ **The published rule about which CPU model wedges the emulator did not
   reproduce here.** Five models behaved identically, including the two the
   advice forbids. ⚠ The sources measured older software on other hardware and
   are not falsified; the prediction about this machine is.
5. ⛔ **The Host Compute System is reachable and closed.** Its library binds in
   an ordinary unelevated process, and then even **reading** the compute systems
   is refused to anyone outside one Windows group.
6. ⭐ **A host needs nothing but a container engine.** A BSD shell, in an
   unprivileged container, with no acceleration, no device and no emulator on
   the host, because the emulator ships inside the image. ⛔ **That is the
   result that changes what this repository should publish**, and the timings
   are in [`../docs/LIMITS.md`](../docs/LIMITS.md).

---

## ⛔ Six defects this session shipped and then caught

⚠ **Every one is a class this repository's own tables already name, and the
reviews caught what running did not.** Five new rows went into
[`../docs/conventions/forbidden-patterns.md`](../docs/conventions/forbidden-patterns.md).

- ⛔ **A false success.** An experiment printed "a container ran" over a
  `podman run` that had exited with an error, because its success marker matched
  the guest's **echo of the command line that mentioned the marker**.
- ⛔ An `ssh` piped into `sed` with `$?` read afterwards, which reads `sed`'s.
- ⛔ `curl` and `xz` guarded by `cmd; rc=$?` under `set -e`, where the shell has
  already exited before the guard can run.
- ⛔ A probe reporting a library "did not load" about a library that had loaded,
  because a `try`/`catch` cannot tell that from a missing entry point.
- ⛔ `network NONE` printed while the guest ran `dhclient`. The emulator attaches
  a default interface unless told not to.
- ⛔ A boot time attributed to a filesystem resize that never happened. Replaced
  with four measured boot phases, which located it.

---

## ⚠ What was NOT measured, so it is not claimed

- ⛔ **Steady-state performance.** Only boot time was measured. Nothing here
  tested whether the guest is slow at ordinary work.
- ⛔ **The two FreeBSD boot times are not a hypervisor comparison.** Different
  kernels and different root filesystems; two variables moved at once.
- ⚠ **Every number is one machine**, one Windows laptop.
- ⚠ **No Linux host was measured at all** except the WSL2 machine inside this
  one, which is not the same question.
- ⚠ **Whether the container route survives being packaged as an image.**
  It was measured with the artefacts on a bind mount, not baked into layers, and
  packaging it is the highest-value open task.
- ⚠ **Anything about OpenBSD or DragonFly running.** They have images here
  and no measured way to run them.
