# TODO: measurement

⭐ **What this repository claims and has not measured.** Every entry here
converts a sentence in [`../docs/LIMITS.md`](../docs/LIMITS.md) that currently
says "not measured" into a number.

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.

⛔ **An entry closes with a number, not with a conclusion.** "It seems fine" is
what this file exists to prevent.


### ⭐ Prior art already read, and it is in this repository

⛔ **37 projects have been mined, in four sweeps, with their trackers.**
[`../HISTORY/references/findings.md`](../HISTORY/references/findings.md) has the
verdicts and the ranking;
[`../HISTORY/references/usable.md`](../HISTORY/references/usable.md) has the
commands. ⚠ **A session that designs before reading the sections named below is
re-deriving work that is already on disk**, which has happened here at least
once and is recorded under `INF-09`.

| the entry | read, by section |
| --- | --- |
| ⛔ **`PERF-01`, the OTHER side of the ratio** | ⭐ `usable.md`, the `R29` `ppkg` section. It **cross-compiles for all three BSDs from Linux with stock clang and the BSD's own published sets**, and `R30` runs it on a free runner with `apt install clang lld`. That is user A, built and working, and this repository does not have it |
| `PERF-01`, anything timing a guest | ⭐ `findings.md`, the `R18` `anyvm` verdict. It is the only reference here that has **measured** the Windows hypervisor, and it is the engine under `vmactions` |
| `PERF-01`, acceleration | ⛔ `usable.md`, the `R17` section: the `udev` rule that makes a **CI runner's `/dev/kvm` writable**, and the `R31` section, which shows a QEMU process on a free runner **using KVM in production**. ⛔ `R31` also carries the CPU feature mask without which **a NetBSD guest on a host CPU with AMX jumps to address 0** |
| `PORT-01`, other hosts | `usable.md`, the `R8` `vmactions` section: a library of `qcow2` guests for four BSDs across four architectures, and the most used BSD CI action there is |
| `PORT-01`, arm64 | ⚠ `usable.md`'s `R7` line records `evbarm-aarch64` images exist upstream. ⛔ Nothing here has run one |

---

## PERF-01. What does real work cost inside the guest

**Source** The operator, 2026-08-27: "if so, what performance penalties?"
**Category** measurement · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **Nothing in this repository has measured throughput of any kind.** Every
published number is time-to-a-prompt, and a boot time says nothing about a
compile.

⚠ **The one adjacent number is a warning rather than a guide.** A stock
general-purpose kernel spent **108 seconds** probing devices on one route,
accelerated, which says IO through that path is expensive and does not say what
work costs. ⛔ Extrapolating a compile time from it would be inventing a number.

### Approach

⭐ **One workload, three configurations, one ratio.** The workload is a real
compile of something small and CPU-bound, not a benchmark suite.

| configuration | what it isolates |
| --- | --- |
| on the host directly | the baseline |
| in the guest, with `/dev/kvm` | the cost of virtualisation |
| in the guest, unaccelerated | ⛔ the cost of **interpretation**, which is the case a consumer with no device gets |

⛔ **Report the ratio, not the seconds alone.** Seconds are about the machine;
the ratio is about the route, and the ratio is what transfers.

⚠ **And report IO separately from CPU.** They are the two costs and they are
not the same multiple: the 108-second probe suggests IO is the worse one.


### ⭐ MEASURED 2026-08-28: the guest side has a route, and it needed two fixes

⛔ **This entry has been blocked on "the guest side needs a compiler in the
image" and that was only half of the blocker.**

| what was in the way | state |
| --- | --- |
| `pkg_add` never returns on the staged package | ⛔ **still true.** `INF-09`. ⭐ Worked around: `tar` puts the package in, in about half a minute, and `pkg_info` finds it |
| ⛔ **the guest has no assembler and no system headers** | ⛔ **nobody had looked.** `/usr/bin/as`, `/usr/include/sys/cdefs.h` and `/usr/lib/libc.a` are all absent, so `gcc -c` stops at the first `#include` |

⭐ **The second one is the `comp` set, which is the same gap this file already
recorded for the CROSS sysroot above**, and the two were filed apart. NetBSD
11.0's `comp.tar.xz` extracts into the guest root in about a minute and all
three appear.
[`../experiments/47-comp-set-and-compile.sh`](../experiments/47-comp-set-and-compile.sh)
does both and then runs the workload.

⚠ **The workload is unchanged and deliberately so**: `cc -O2 -c sqlite3.c`, the
same bytes on both sides, with each side timing itself from the inside.
[`../scripts/bench-compile`](../scripts/bench-compile) is the harness and the
Linux half of the number is already in
[`../docs/LIMITS.md`](../docs/LIMITS.md).

⛔ **`bench-compile` will need one edit when the image ships this.** It runs
`/usr/pkg/gcc14/bin/gcc` in the guest, which is right, and it has never had a
guest that could answer.

### ⛔ AND THEN THE COMPILE DID NOT FINISH IN AN HOUR

⭐ **The entry has half a number and it is the important half.** With the
toolchain in place, `cc -O2 -c sqlite3.c` ran inside the guest and **did not
return within 3,600 seconds**, against **27 s** for the same bytes on Linux. The
seconds are in [`../docs/LIMITS.md`](../docs/LIMITS.md).

⛔ **So this entry cannot close as written.** Its Prove line asks for three wall
times and two ratios, and one of the three configurations does not terminate.
⚠ **A ratio with no numerator is not a ratio**, and "more than 130x" is a floor
rather than a measurement.

⭐ **What to do about it, in order:**

1. ⛔ **Find out whether it EVER finishes.** Rerun with
   [`../experiments/43-siginfo-the-stuck-guest.sh`](../experiments/43-siginfo-the-stuck-guest.sh)
   pressing Ctrl-T at it. ⚠ If user time climbs, it is slow and a longer budget
   answers the question; if user time freezes the way `pkg_add`'s does, this is
   `INF-09` again in a second program and the entry's whole shape changes.
2. ⚠ **Shrink the workload rather than the question.** A quarter of a million
   lines was chosen because it is real; a smaller real file gives a finite
   number on the unaccelerated path and the ratio still transfers.
3. ⛔ **Do not publish an accelerated number as the headline.** The case a
   consumer with no device gets is the unaccelerated one, and it is this.

### Prove

A table in [`../docs/LIMITS.md`](../docs/LIMITS.md) with the workload named, the
three wall times, and the two ratios. ⛔ It replaces the section that currently
says this is unknown; it does not sit beside it.

---

## PORT-01. Does route 1 work anywhere other than the one host it was measured on

**Source** The operator, 2026-08-27: "does this work everywhere? even on linux?
even on CI?"
**Category** measurement · **Priority** P1 · **Effort** S · **Status** open

### Problem

⛔ **Route 1 is measured on exactly one path**: a container inside a WSL2 Linux
machine on one Windows laptop.
[`../docs/LIMITS.md`](../docs/LIMITS.md) marks native Linux, CI and macOS as
**inferred**, and arm64 as expected to fail.

⚠ **The inference is reasonable and it is still an inference.** The container is
a Linux container either way, so a native Linux host is the same code path with
one layer removed. Nothing has run it.

### Approach

⭐ **The experiment already exists and takes one command.**
[`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh)
needs only a container engine and prints a machine-readable RESULT line.

⛔ **Run it, unchanged, on each host and record the line.** Do not adapt it per
host: if it needs adapting, that difference **is** the finding.

| host | why it matters |
| --- | --- |
| native Linux, `x86_64` | ⭐ the most likely consumer, and the cheapest gap to close |
| GitHub CI, `x86_64` | ⭐ decides whether this can be used in anybody's pipeline |
| macOS, Apple Silicon | ⚠ a container there is already inside a Linux VM, and the guest is `amd64` |
| any arm64 | ⛔ expected to fail. Recording **how** it fails is the point |

⭐ **CI is the one to automate.** A job that runs it on every push turns this
entry into a standing guarantee instead of a one-off measurement.

### Prove

A row per host in [`../docs/LIMITS.md`](../docs/LIMITS.md)'s portability table,
each carrying the RESULT line the experiment printed, ⛔ **and each labelled
measured rather than inferred**, or the row says why it could not run.
