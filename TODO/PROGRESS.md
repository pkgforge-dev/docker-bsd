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
session started 2026-08-28T03:40:00Z, continued after an operator redirect
baseline        an image that boots, and a provisioning step nobody could explain
entries         total 22  open 20  blocked 0  done 2
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

## ⭐ The headline: `INF-09` is answered, and the answer moves three entries

⛔ **Installing a compiler into the guest does not fail because of `pkg_add`.**
Two controls settle it, same bytes, same guest, minutes apart:

| the same 490 MB, the same 1,664 files | result |
| --- | --- |
| `tar` onto the guest's **ext2 root** | ⛔ still running at 900 s |
| `tar` into a **tmpfs** in that guest | ⭐ finished |

⭐ **It is the filesystem.** 1 KB blocks over 2 GB with no features. ⛔ **And the
fourth reference sweep found why, in upstream's own source**: smolBSD writes
ext2 only when the BUILD HOST is Linux, and only for the BUILDER image, which is
the image this repository ships as its runtime root. The seconds and the
geometry are in [`../docs/LIMITS.md`](../docs/LIMITS.md) and the readings are in
`INF-09`. ⛔ **They are not repeated here**: one fact, one home.

---

## What this session did

**2026-08-28.**

1. ⭐ **`INF-09` found, then CORRECTED by reading upstream.** Two controls said
   the destination filesystem decides whether a 490 MB write finishes; the
   fourth reference sweep then found the reason in smolBSD's own `mkimg.sh`:
   ⛔ **ext2 is what it falls back to when the BUILD HOST is Linux, and only for
   the BUILDER image**, which is the image this repository ships as its runtime
   root.
2. ⭐ **A fourth reference sweep, nine projects**, taking the total to 37. ⛔ **It
   was run because the first three were never being read**: every citation to
   them outside `HISTORY/` had arrived in the first commit.
3. ⛔ **DragonFly dropped**, `RULES.md` decision 7. The working route and its
   three traps are kept verbatim in
   [`../HISTORY/dragonfly.md`](../HISTORY/dragonfly.md).
4. ⛔ **`TODO/bsd.md` was 893 lines of corrections to corrections**, now 155
   lines of current facts, with the reasoning moved verbatim to
   [`../HISTORY/bsd-entries.md`](../HISTORY/bsd-entries.md).
5. ⛔ **A claim in `docs/LIMITS.md` narrowed for the third time.** "A free
   runner cannot use `/dev/kvm`" is wrong; **a rootless container on one cannot
   open it** is what was measured. Somebody else runs BSD guests on free runners
   with KVM in production.
6. ⭐ **Two guards tightened and both seen to fail**, and one new defect filed
   as `INF-10`.

---

## ⭐ The work order

### 1. ⛔ `INF-09`, which is answered and not closed

⛔ **Start with the question the sweep raised, not with the filesystem.**
Upstream treats `build-amd64.img` as a **build environment** and this repository
ships it as a product. ⭐ **The cheapest fix may be to stop doing that**, and it
costs no filesystem work.

⭐ **Then, if the image is still the right one:** the guest root is ext2 and
Linux owns it completely. `debugfs -R rdump` the tree out, `mke2fs -b 4096 -d` a
new one at the size wanted, write the package in from Linux. ⛔ **No guest, no
emulator and no provisioning step.**

⛔ **Prove the block size is the lever before rebuilding anything.** Repeat the
two controls against a 4 KB filesystem. A fix that works and is not understood
is the ninth guess, and eight are already dead.

⚠ **Read `usable.md`'s `R34` section first.** It carries `mkimg.sh:155`, which
is where the filesystem is chosen, and `smoler/build.sh:245`, which is upstream
provisioning with a **chroot** rather than a booted guest. ⛔ That tracker holds
83 items and 51 threads and two have been read.

### 2. ⭐ `PERF-01`, which unblocks the moment 1 lands

⛔ **Half of it is measured: the Linux side is 27 seconds** for
`cc -O2 -c sqlite3.c`, three runs, in a container on this laptop.
[`../scripts/bench-compile`](../scripts/bench-compile) runs both sides against
the same bytes and both time themselves from the inside. ⚠ **The guest side
needs a compiler in the image**, which is 1.

⭐ **And user A is now a named command rather than an idea.** `apt install clang
lld`, plus the BSD's own `base` and `comp` sets as a sysroot, plus about seventy
lines of glue. ⛔ **No BSD host, no VM.** `usable.md`, the `R29` and `R30`
sections. ⚠ **`scripts/sources` fetches `base` and `etc` and not `comp`**, and
`comp` is where the headers and static libraries are.

### 3. `IMG-02` closes on 2

⭐ Its acceptance is a working `pkg_add` **plus a recorded build time**. The
first comes from 1 and the second is 2.

### 4. ⛔ `PERF-02` then `PERF-03`, and design them against the variance

⚠ **Read [`../docs/LIMITS.md`](../docs/LIMITS.md) section 1b before designing
either.** A free runner moves by 42 percent between jobs and under 1 percent
within one, which is eight times the gate `PERF-03` has to measure. ⛔ **Both
sides in the same job, repeated, or the number means nothing.**

⛔ **And every runner number this repository has taken is an emulated number**,
because a **rootless container** on a runner cannot open `/dev/kvm`: the node
arrives owned by `nobody`, `test -r` and `test -w` answer yes anyway, and the
emulator's `open` fails. ⚠ **That is narrower than what was published before.**
⭐ **A QEMU process on the runner itself DOES get KVM**, and somebody runs BSD
guests that way in production. ⛔ **So the highest-value unknown is now
specific**: can a container on a free runner be given a usable `/dev/kvm`?
`usable.md`'s `R17` and `R31` sections.

⛔ **And there is a trap waiting on the day it works.** With KVM the guest sees
the host CPU, `guest.py` asks for `-cpu host,+invtsc`, and **a NetBSD guest on
a host CPU with AMX jumps to address 0 while starting init**. The mask that
fixes it is in the `R31` section.

### 5. ⚠ `INF-08` and `INF-10`, which are one file and should move together

`Console.run()` returns the right answer late; `Console.send()` never returns at
all against a guest that has stopped draining its console. ⛔ **Both are a
missing bound, and `console.ps1` has to move with `console.py`.**

### 6. ⚠ `IMG-03`, `INF-04`, `INF-06`, and the `OPT-*` levers

⛔ **Do not pull an `OPT` lever before `PERF-02` says which layer is stuck.**
⚠ `OPT-02` now has numbers rather than an impression: the interpreter is bigger
than the emulator binary and exists to run 15 KB of driver.

---

## ⭐ Open questions: none. Four were answered on 2026-08-27.

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
