# TODO: performance

⭐ **The entries that decide whether this project deserves to exist.**

⛔ **The bar is explicit: within 5 percent of not using us.** A developer who
can cross-compile for a BSD on their Linux box, or use somebody else's project,
has an alternative. If running inside our image costs materially more than that
alternative, the image is a convenience with a tax, and a convenience with a tax
does not get adopted.

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.


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
| `OPT-02`, a purpose-built emulator | ⭐ `findings.md`, the `R18` `anyvm` verdict: which QEMU accelerator paths exist per host, and ⛔ that **Windows QEMU ships WHPX in `qemu-system-x86_64.exe` only**. ⭐ For the toolchain to build a static one, `usable.md`'s `R37` section and [`RULES.md`](RULES.md) decision 8 |
| `OPT-03`, is a VM the right shape | ⭐ `usable.md`, the `R26` `bsdkrun` section, which is an OCI image booted as a microVM on `libkrun` and the closest published thing to this repository's shape, plus `R11` and `R13` for Firecracker. ⛔ And `findings.md`'s `R28` verdict, which is why "no virtual machine at all" is already a dead row here |
| ⭐ **`PERF-02`, the whole matrix** | `usable.md`, the `R30` section. ⛔ **The A-versus-B workflow already exists**: one file, a `cross-compiling` input, `apt install clang lld` on one side and a real BSD VM on the other, both on `ubuntu-latest`. ⚠ **They are in two different JOBS**, which this repository's own 42 percent between-job variance makes unusable as a ratio. Take the shape, put both in one job |
| `PERF-02`, a real build in a guest | ⛔ `usable.md`'s `honest-limit` row on `mount_psshfs`: a parallel build over it reads back **truncated object files**. Any benchmark that shares a source tree that way is measuring corruption |

---

## PERF-02. Two users, one program, one matrix

**Source** The operator, 2026-08-27.
**Category** performance · **Priority** P1 · **Effort** L · **Status** open

### Problem

⛔ **Nothing here has compiled anything.** Every published number is
time-to-a-prompt, and a boot time says nothing about a build.

### Approach

⭐ **Two users, and they are the comparison.**

| | who they are | what they do |
| --- | --- | --- |
| **A** | a developer on Linux with a cross toolchain | cross-builds for the BSD on the host, no virtual machine anywhere |
| **B** | a developer using this project's image | installs or updates a compiler inside it and builds the same program |

⛔ **RULED 2026-08-27: both run in the same job on a free GitHub runner.**
Not on a BSD host, not on the developer's laptop. [`RULES.md`](RULES.md)
decision 2.

⭐ **That is fairer than comparing against hardware nobody has**, and it
removes a blocker: it needs no machine anybody must own, and it measures the
environment this will actually be used in.

⚠ **It also means the numbers carry the runner's variance**, so a published
result is a **median over several runs** and never a single one. ⛔ A one-shot
number from a shared runner is noise with a decimal point.

### ⭐ Four languages, four real projects

⛔ **Well known ones, not microbenchmarks.** A microbenchmark measures the thing
it was written to measure; a real project measures what a developer will feel.

| language | the shape it stresses |
| --- | --- |
| C | many small translation units, heavy IO, process churn |
| C++ | ⚠ the worst case. Long single compilations, large memory, template instantiation |
| Go | a self-contained toolchain that forks aggressively and is IO heavy |
| Rust | long link steps and a large dependency graph |

⚠ **Name the project and the version in the result**, not just the language. A
number without a subject cannot be reproduced.

### Prove

A matrix in [`../docs/LIMITS.md`](../docs/LIMITS.md): one row per language, and
for each, A's wall time, B's wall time, and the ratio. ⛔ Plus the machine, and
whether B had `/dev/kvm`, because those change the answer and a number without
its conditions is not a measurement.

---

## PERF-03. Be within 5 percent. It is a hard gate.

**Source** The operator, 2026-08-27: "we must be about 5% or less penalties".
**Category** performance · **Priority** P1 · **Effort** L · **Status** open

### Problem

⛔ **A ratio is not a target until somebody writes the number down.** `PERF-02`
produces the ratio. This entry is what the project does about it.

### Approach

⛔ **Do not tune until `PERF-02` says which of the four is worst**, and do not
tune the one that is easiest to move. Optimising a workload that was already
fine is how a project spends a month and gains nothing.

⚠ **The likely costs, in the order worth suspecting**, and none of this is
measured:

1. **IO through the guest's virtual disk.** The one adjacent number here is a
   device probe that dominated a boot, which points at IO before anything else.
2. **The allocator.** See `OPT-01`.
3. **The emulator itself**, when there is no `/dev/kvm`. See `OPT-02`.
4. **The container runtime underneath.** See `OPT-03`.

### ⛔ What a hard gate means

⛔ **RULED 2026-08-27: keep optimising until it is met.**
[`RULES.md`](RULES.md) decision 4. ⚠ **This entry does NOT close by
publishing a worse ratio and repositioning the project.** That was proposed and
refused.

⚠ **It may take more than one session**, and the `OPT-*` entries exist for
it. ⛔ It does not license optimising before `PERF-02` says which layer is
stuck.

⛔ **The current ratio is published at every stage** in
[`../docs/LIMITS.md`](../docs/LIMITS.md). A bar being worked towards is not a
reason to publish nothing.

### Prove

⛔ Every row of `PERF-02`'s matrix within **5 percent** of A, as a median over
several runs on a free GitHub runner. ⚠ Until then the entry stays open with
the current ratio published.

---

## OPT-01. The allocator, because the default one is slow

**Source** The operator, 2026-08-27.
**Category** performance · **Priority** P2 · **Effort** M · **Status** open

### Problem

⚠ **The container base is Alpine, whose libc allocator is known to be slow
under allocation-heavy loads**, and a compiler is exactly that. ⛔ Nothing here
has measured it, so this entry begins with a measurement and not a swap.

⚠ **And it is the wrong layer to look at first.** The allocator that matters is
whichever one is on the hot path: the emulator's, in the container, and the
guest's, inside the virtual machine. ⛔ Changing the one that is not hot is
effort with a number that does not move.

### Approach

1. ⛔ **Establish which layer is hot** before replacing anything.
2. Compare the base allocator against `jemalloc` and `mimalloc`, preloaded, on
   the workload `PERF-02` found worst.
3. ⚠ **Consider a base that is not musl** if the allocator turns out to be the
   floor rather than the choice. That is `OPT-02`.

### Prove

A row in [`../docs/LIMITS.md`](../docs/LIMITS.md) per allocator, on one named
workload, ⛔ with the loser kept in the table. A comparison that publishes only
the winner cannot be checked.

---

## OPT-02. An emulator image built to do one thing

**Source** The operator, 2026-08-27.
**Category** performance · **Priority** P2 · **Effort** L · **Status** open

### Problem

⚠ **The image ships a distribution's emulator package**, built for generality:
every target architecture, every device, every feature, and a libc chosen for a
whole distribution rather than for this.

⛔ **This image has exactly one job.** It emulates one architecture, boots one
kind of guest, and runs no other program.

### ⭐ It is measured now, and the largest single item is not the emulator

⛔ **Only a fifth of the image is the BSD.** The full breakdown is in
[`../docs/LIMITS.md`](../docs/LIMITS.md) section 1b and is not repeated here.
The two facts that decide this entry's order of work:

- ⛔ **The interpreter is bigger than the emulator binary**, and it exists to
  run **15 KB** of driver source.
- ⚠ **A `scratch` base removes `/bin/sh` as well as `python3`**, so
  `entrypoint.sh`, `guest.py` and `console.py` become **one static binary or
  none of them ship**. That is a rewrite, not a base change.

⛔ **And it has a cost that is not size.**
[`../experiments/lib/console.py`](../experiments/lib/console.py) is this
repository's single POSIX copy of two measured tty rules, and `tests/run.sh`
asserts its PowerShell twin carries the same two. A third implementation is a
third place for a rule that has already been got wrong once.

### Approach

⭐ **Build the emulator for this and nothing else**, and measure each step so it
is known which one paid:

| step | what it removes |
| --- | --- |
| one target architecture only | most of the binary and its dispatch |
| only the devices the guest actually uses | probe time and code paths |
| optimised for the host baseline, not the oldest CPU | ⚠ **and a portability decision arrives here**, so it needs a ruling |
| a minimal base, or nothing at all | the distribution's constraints, including its libc |

⛔ **RULED 2026-08-27: `scratch` is the destination, not an option.**
[`RULES.md`](RULES.md) decision 3. Alpine is a stepping stone and is what the
first measurement was taken on.

⚠ **A base with no shell cannot be debugged in place, and that is
accepted.** ⭐ The consumer experience should feel native; when it does not,
they open an issue rather than being handed a shell. A deliberate trade of
debuggability for size and speed.

### Prove

⛔ **The same workload as `PERF-02`, before and after**, plus the image size,
plus a statement of which hosts the optimised build no longer runs on.

---

## OPT-03. Is a virtual machine even the right shape

**Source** The operator, 2026-08-27.
**Category** performance · **Priority** P2 · **Effort** L · **Status** open

### Problem

⚠ **This project chose "an emulator in a container" because it worked, not
because it was compared.** It reaches a BSD shell needing nothing from the host,
which is a strong property, and it may not be the fastest shape.

### Approach

⭐ **Compare shapes on the same workload**, and keep the losers in the table.

| shape | what it might buy |
| --- | --- |
| the current one | the baseline, and the only one measured |
| a microvm monitor rather than a full emulator | far less device emulation, so a faster boot and cheaper IO |
| a library that makes a virtual machine a process | no daemon, and the container runtime does less |
| an alternate container runtime under the same image | ⚠ the runtime is on the IO path and has never been varied |
| ⛔ no virtual machine at all | a reverse syscall translator was attempted in 2022, crashes, and is recorded in [`../HISTORY/references/usable.md`](../HISTORY/references/usable.md). ⛔ Listed so it is not rediscovered as an idea |

⚠ **Each shape must be judged on the same four questions**, not on speed alone:
what it needs from the host, what privilege it needs, which hosts it runs on,
and what it costs.

### Prove

A table in [`../docs/LIMITS.md`](../docs/LIMITS.md) with one row per shape and
those four columns, ⛔ **including the shapes that lost**, and a stated
recommendation with its reason.
