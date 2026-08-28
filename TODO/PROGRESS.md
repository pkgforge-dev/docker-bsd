# PROGRESS.md

⭐ **The only file that carries a work order.** Where the work is, what is next,
and why. [`INDEX.md`](INDEX.md) is the list of entries; the **order lives here
and nowhere else**. [`SUMMARY.md`](SUMMARY.md) is the brief, read first and in
full, and it is a snapshot rather than an authority.

⛔ Rewritten at the beginning and the end of every session. It carries no
history: the history is the git log, [`../HISTORY/`](../HISTORY/) and the
entries themselves. Do not add a "previous sessions" section.

⛔ Edited in the same change as the work, never as a report afterwards.

---

## State

```text
session started 2026-08-28T09:00:00Z
baseline        an image that boots, and an answer to INF-09 that did not survive a repeat
entries         total 22  open 18  blocked 0  done 4
```

⚠ The counts above are checked against [`INDEX.md`](INDEX.md)'s rows by
`scripts/common/check-record.sh`, which runs as a gate. ⛔ Do not edit them by
hand to make a check pass; fix whichever file is wrong. ⭐
`scripts/common/set-record.mjs` moves them for you.

| fact | value |
| --- | --- |
| repository | `pkgforge-dev/docker-bsd`, public, 0BSD |
| work model | todo. [`../docs/methodology/work-todo.md`](../docs/methodology/work-todo.md) |
| publishes | ⭐ **`ghcr.io/pkgforge-dev/netbsd`, which boots**, plus OCI images for three userlands. ⛔ DragonFly dropped 2026-08-28, [`RULES.md`](RULES.md) decision 7 |
| the local gate | ⭐ `sh scripts/common/check-gate.sh --fast`, then `sh tests/run.sh` |
| CI | `ci.yml` static, and ⭐ **`image-netbsd.yml`, which builds a BSD, runs it and asserts on it** |

---

## ⛔ The headline: yesterday's answer was withdrawn, and one repeat is what did it

⛔ **"The destination filesystem decides whether a 490 MB write finishes" was the
headline of four documents and it rested on a single `tar`.** Run again today,
through the plain driver and through the instrument that took the original
reading, ⭐ **that same `tar` onto that same ext2 root finishes in about half a
minute.**

| what was believed yesterday | what is measured today |
| --- | --- |
| the ext2 root cannot take the write | ⛔ **it can.** So can a fresh 1 KB filesystem, a fresh 4 KB one, and the shipped root's own bytes mounted as data |
| `pkg_add` is exonerated | ⛔ **it is not.** It is the only suspect left, and it reproduces every time |
| the 1 KB block size is the lever | ⛔ **it is not.** One `mke2fs -b` apart, both finish |

⭐ **And `pkg_add -v` says WHERE it stops**: it prints every path in the package,
reaches the last one, and then goes silent while the kernel reports user time
frozen and system time tracking the wall clock. ⛔ **The unpack finishes. The
phase after it does not.**

⚠ The withdrawn wording is in [`../HISTORY/inf-09.md`](../HISTORY/inf-09.md), the
seconds are in [`../docs/LIMITS.md`](../docs/LIMITS.md), and the readings are in
`INF-09`. ⛔ **They are not repeated here**: one fact, one home.

---

## What this session did

**2026-08-28.**

1. ⛔ **`INF-09` corrected for the third time**, by repeating the one control the
   whole answer rested on. Three new experiments, each varying one thing:
   `44` two ext2 filesystems one `mke2fs -b` apart, `45` the shipped root's own
   bytes as a data disk and the real root as the reference, `46` the install
   without `pkg_add`.
2. ⭐ **The compiler goes into the guest in 46 seconds without `pkg_add`**, and
   `pkg_info` finds it afterwards. A pkgsrc binary package is an archive with a
   known layout and every step of it is measured.
3. ⛔ **And then the compile failed on a defect nobody had looked for.** The
   build guest has no `/usr/bin/as`, no `sys/cdefs.h` and no `libc.a`. ⭐ **The
   `comp` set fixes it in about a minute**, and that gap was already written down
   under `PERF-01` for a cross sysroot with nobody connecting the two.
4. ⭐ **`INF-08` and `INF-10` closed together**, both halves of the console
   driver, with the defect planted first in both languages.
   ⚠ **The two halves had different answers**, which is the argument for testing
   both.
5. ⛔ **`README.md` and `docs/LIMITS.md` amended** where they told a consumer the
   build variant was closer to usable than it is.
6. ⛔ **Two rules the operator ruled on, and a command that enforces one of
   them.** `RULES.md` decisions 9 and 10, an end protocol with a step 0, and
   [`../scripts/common/reap.sh`](../scripts/common/reap.sh), which was seen to
   refuse on its first run because a guest was still going.

---

## ⭐ The work order

### 1. ⭐ `IMG-02`, and it is now assembly rather than research

⛔ **Every step is measured and none of it is in the image.** Bake into
[`../images/netbsd/Containerfile`](../images/netbsd/Containerfile):

1. the `comp` set, fetched and digest-checked by
   [`../scripts/sources`](../scripts/sources) and written into the guest root the
   way the package already is;
2. a provision stage that runs the `tar` recipe from
   [`../experiments/46-install-without-pkg-add.sh`](../experiments/46-install-without-pkg-add.sh)
   instead of `pkg_add`;
3. ⚠ **a bigger `SMOL_BUILD_SIZE`.** The root is at 81 percent with both in.

⛔ **And rule on the version, do not absorb it.** The guest is
`smolBSD 11.0_STABLE`, the `comp` set used is NetBSD **11.0**, and
`scripts/sources` pins NetBSD **10.1** for the OCI userlands. Two versions for
two purposes is defensible and is written down nowhere.

### 2. ⭐ `PERF-01`, which unblocks the moment 1 lands

⛔ **The Linux side is measured and the guest side has never had a compiler to
run.** [`../scripts/bench-compile`](../scripts/bench-compile) runs both against
the same bytes and both time themselves from the inside.
[`../experiments/47-comp-set-and-compile.sh`](../experiments/47-comp-set-and-compile.sh)
is the same workload with the toolchain carried in on a second disk, so the
number can be taken before the image is rebuilt.

⭐ **And user A is a named command, not an idea.** `apt install clang lld`, plus
the BSD's own `base` and `comp` sets as a sysroot, plus about seventy lines of
glue. ⛔ **No BSD host, no VM.** `usable.md`, the `R29` and `R30` sections.
⚠ **`scripts/sources` fetches `base` and `etc` and not `comp`**, the same gap
as 1, for a different consumer.

### 3. ⚠ `INF-09` is narrowed and not closed

⛔ **Do not rebuild the filesystem.** Four controls say it is not the problem.
⭐ **What would close it** is reading which loop the kernel is in after the
unpack: `ktrace(2)` is not in this kernel, so that means a kernel with
`options KTRACE` or reading `pkg_install`'s source for what happens between the
last extracted file and the pkgdb write. ⚠ Neither has been done.

⚠ **And decide what a consumer is told**, because `pkg_add` is in the image and
does not work on anything large.

### 4. ⛔ `PERF-02` then `PERF-03`, and design them against the variance

⚠ **Read [`../docs/LIMITS.md`](../docs/LIMITS.md) section 1b before designing
either.** A free runner moves by 42 percent between jobs and under 1 percent
within one, which is eight times the gate `PERF-03` has to measure. ⛔ **Both
sides in the same job, repeated, or the number means nothing.** `R30` has the
matrix already built and puts its two sides in two jobs, which is the one thing
to change about it.

⛔ **And every runner number this repository has taken is an emulated number**,
because a **rootless container** on a runner cannot open `/dev/kvm`. ⭐ **A QEMU
process on the runner itself DOES get KVM**, so the highest-value unknown is
specific: can a container on a free runner be given a usable one? `usable.md`'s
`R17` and `R31` sections. ⛔ **And there is a trap waiting on the day it works**:
`guest.py` asks for `-cpu host,+invtsc`, and a NetBSD guest on a host CPU with
AMX jumps to address 0 while starting init. The mask is in `R31`.

### 5. ⚠ `IMG-03`, `INF-04`, `INF-06`, and the `OPT-*` levers

⛔ **Do not pull an `OPT` lever before `PERF-02` says which layer is stuck.**
⚠ `OPT-02` now has numbers rather than an impression: the interpreter is bigger
than the emulator binary and exists to run 15 KB of driver.

---

## ⭐ Two rules were ruled on, and one gap is left behind them

⛔ **[`RULES.md`](RULES.md) decisions 9 and 10**, both ruled 2026-08-28: a
direction-changing control is run twice, and a session leaves the **machine** as
it found it rather than only the tree. ⚠ The second came out of a measurement:
435 images, 37.27 GB, 100 percent reclaimable, carrying this repository's own
labels.

⛔ **The gap that is left, and it is one line of Containerfile.**
[`../scripts/common/reap.sh`](../scripts/common/reap.sh) can prove 14.1 GB of
that is this project's and cannot prove the rest, because the `fetch` stage of
[`../images/netbsd/Containerfile`](../images/netbsd/Containerfile) sets no label
before it is discarded. ⭐ **Give every stage the source label** and the reaper
can account for all of it; ⛔ **do not loosen the match instead**, because the
machine runs other projects.

---

## ⭐ Open questions: none new. Four were answered on 2026-08-27

⛔ **They are settled and recorded in [`RULES.md`](RULES.md), which persists
where this file is rewritten.** Restated here as pointers only, so the two
cannot fork.

| the question | the ruling |
| --- | --- |
| what the first published image ships, and what it is called | ⭐ **NetBSD, named `netbsd`.** ⭐ **Shipped** |
| what the performance baseline is measured against | ⛔ **a free GitHub runner**, both users in the same job |
| what base the container uses | ⛔ **build towards `scratch`.** Alpine is a stepping stone |
| what if 5 percent cannot be met | ⛔ **keep optimising.** The entry does not close by repositioning the project |

⚠ **One constraint from those answers reaches every entry**, and it is the one
most likely to be forgotten: ⛔ **there is no cloud VM and there never will be,
and no BSD host exists.** A design that needs either is refused rather than
scheduled. [`RULES.md`](RULES.md).

---

## ⚠ How much a session takes on

⭐ **As many entries as it can finish properly**, not one, and not one per
`L` estimate. ⛔ The gate, the test suite and the mandatory reviews are what
hold quality. ⚠ Stop at roughly five, or when the operator interrupts.
[`RULES.md`](RULES.md).
