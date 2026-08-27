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
session started 2026-08-27T17:00:00Z
baseline        this repository published its first image that boots
entries         total 21  open 19  blocked 0  done 2
```

⚠ The counts above are checked against [`INDEX.md`](INDEX.md)'s rows by
`scripts/common/check-record.sh`, which runs as a gate. ⛔ Do not edit them by
hand to make a check pass; fix whichever file is wrong. ⭐
`scripts/common/set-record.mjs` moves them for you.

| fact | value |
| --- | --- |
| repository | `pkgforge-dev/docker-bsd`, public, 0BSD |
| work model | todo. [`../docs/methodology/work-todo.md`](../docs/methodology/work-todo.md) |
| publishes | ⭐ **`ghcr.io/pkgforge-dev/netbsd`, which boots**, plus OCI images for four userlands |
| the local gate | ⭐ `sh scripts/common/check-gate.sh --fast`, then `sh tests/run.sh` |
| CI | `ci.yml` static, and ⭐ **`image-netbsd.yml`, which builds a BSD, runs it and asserts on it** |

---

## ⭐ The headline, and it is measured

⛔ **A stranger with a container engine and nothing else can now run a BSD**, in
one command, from a public registry.

```bash
podman run --rm -it ghcr.io/pkgforge-dev/netbsd:latest sh
```

Built and proved on a free `ubuntu-latest` runner. The seconds, the sizes and
the conditions are in [`../docs/LIMITS.md`](../docs/LIMITS.md). ⛔ **They are
not repeated here**: one fact, one home.

---

## What this session did

**2026-08-27 into 2026-08-28.**

1. ⭐ **`IMG-01` closed.** The measured route is packaged, pinned, published and
   anonymously pullable. ⛔ **Its guard was seen to fail**: CI asks the guest to
   `exit 3` and requires exactly 3 back, so the acceptance is not theatre.
2. ⭐ **A second variant with a real userland**, `netbsd:build`, carrying
   `uname`, `make`, `pkg_add` and `pkgin`, with a root filesystem grown from
   Linux and a compiler installed at build time.
3. ⭐ **A timing harness this project did not have.**
   [`../scripts/time-image`](../scripts/time-image) runs anywhere, reports a
   median over several runs, and ⛔ **says which accelerator actually ran**
   rather than which flag was passed.
4. ⛔ **Four defects found by running rather than by reading**, each recorded
   where it was found: a console wait that matches the previous command's
   marker, a network device that is accepted and never attaches when its two
   arguments are ordered the other way, an accelerator probe reading a stream
   that had already been discarded, and a guest that stops in single user mode
   with a read only root and no obvious sign of either.

---

## ⭐ The work order

⛔ **The largest remaining defect is that this project still cannot justify
itself.** Anybody can run it now. Nothing here has compiled anything and timed
it, so a developer with a cross toolchain still has no evidence to switch on.

### 1. ⛔ `PERF-01`, then `PERF-02`, then `PERF-03`. The entries that can end this project

⭐ **They are now unblocked and they are first.** `IMG-01` gave them something
to run and the build variant gave them something to compile with.

⚠ **Two facts from this session change how they must be approached**, and both
are in [`../docs/LIMITS.md`](../docs/LIMITS.md):

- ⛔ **A free runner cannot use `/dev/kvm`, and handing it in looks like it
  can.** The node reaches the container owned by a group the container is not
  in, the image falls back to emulation correctly and silently, and the run is
  half a second slower for a device nothing used. ⭐ **So every number a runner
  produces is an emulated number** until somebody makes the group work.
- ⛔ **The emulated guest is slow at small operations, not at bytes.** It writes
  100 MB in 2.5 seconds and takes tens of minutes to unpack half a gigabyte of
  files. ⚠ A benchmark whose workload is thousands of small files is measuring
  syscalls, not the compiler.
- ⛔ **The emulated network is slower still.** Fetching one package through it
  took longer than every other step in the build put together, and `pkgin` did
  not finish at all in fifteen minutes. ⭐ Nothing in a benchmark should touch
  it.

### 2. ⛔ `IMG-02`, which is close, is not closed, and has one thing in flight

The userland is real and the package manager works: it was watched fetching
from its repository, and it was watched filling a 201 MB filesystem with a
490 MB compiler, which is why the root is grown now.

⛔ **What is in flight, so the next session does not rediscover it:** the build
that installs the compiler into the guest had run for over forty minutes of
emulated CPU when this session ended, both locally and on a runner. ⚠ It is not
stuck: the emulator is at 100 percent the whole time. `INF-09` owns finding out
why, and ⛔ **that job may be red on `main`**. The rescue variant and the
published image are unaffected: the matrix is not fail-fast and each variant is
its own job.

⭐ **What to do first with it.** Do not start by fixing the build. Run the three
measurements `INF-09` asks for, because a fix chosen before them is the fourth
guess after three dead ones.

### 2a. ⭐ `PERF-01`, and half of it is already measured

⛔ **The Linux side of the comparison is done: 27 seconds**, three runs, for
`cc -O2 -c sqlite3.c` in a container on the laptop, Alpine's GCC 14.2.
[`../scripts/bench-compile`](../scripts/bench-compile) runs both sides and
[`../docs/LIMITS.md`](../docs/LIMITS.md) is where the pair belongs when there is
a pair.

⚠ **The guest side needs the image above.** Everything else for it exists: the
source is inside the guest, the same bytes are inside the container, and both
sides time themselves from the inside.

### 3. ⚠ `IMG-03`, `INF-04`, `INF-06`. The three that decide whether it is usable

- `IMG-03`: ⛔ `-v`, `-p` and `-e` reach the container and stop there. ⭐ **It
  moved up in value this session**: nothing a consumer builds inside the guest
  can come out, which makes the build variant a demonstration rather than a
  tool.
- `INF-04`: ⛔ every route still starts with a network fetch.
- `INF-06`: ⛔ two artefacts sit behind moving pointers, and one build-time
  package fetch has no digest at all.
  [`../HISTORY/reviews/9-somebody-auditing-what-this-image-pulls-in.md`](../HISTORY/reviews/9-somebody-auditing-what-this-image-pulls-in.md).

### 4. ⭐ `PORT-01`, which is now one command

[`../scripts/time-image`](../scripts/time-image) is that command. It takes an
image reference, runs anywhere, and prints a comparable figure. ⚠ The entry
closes when somebody has run it somewhere that is neither this laptop nor a
GitHub runner.

### 5. ⚠ `INF-08`, filed this session and deliberately not fixed

`Console.run()` counts prompts with a pattern that can only ever match once, so
every call burns its whole timeout and returns the right answer late. ⛔ **Not
patched in passing**, because that file is the single copy of two measured tty
rules and its twin has to move with it.

### 6. The `OPT-*` entries, which are levers and not goals

⛔ **Do not pull one before `PERF-02` says which is stuck.** ⚠ `OPT-02` now has
evidence behind it: the image is 155 MB to provide a shell, and most of that is
an emulator built to run anything.

⭐ **`INF-09` is the one to do first and it is not an `OPT`.** Installing a
compiler by booting the guest costs more than everything else in the build put
together, and the guest does not have to be involved at all: its filesystem is
ext2 and Linux can write into it.

### 7. ⚠ `BSD-01`, which was the headline and is not any more

⭐ The container route overtook it. It stays open because its acceptance command
has not returned 0, and its blocker is a guest kernel fault rather than a client
one.

---

## ⭐ Open questions: none. Four were answered on 2026-08-27.

⛔ **They are settled and recorded in [`RULES.md`](RULES.md), which persists
where this file is rewritten.** Restated here as pointers only, so the two
cannot fork.

| the question | the ruling |
| --- | --- |
| what does the first published image ship, and what is it called | ⭐ **NetBSD, named `netbsd`.** ⭐ **Shipped** |
| what is the performance baseline measured against | ⛔ **a free GitHub runner**, both users in the same job |
| what base does the container use | ⛔ **build towards `scratch`.** Alpine is a stepping stone |
| what if 5 percent cannot be met | ⛔ **keep optimising.** The entry does not close by repositioning the project |

⚠ **One constraint from those answers reaches every entry**, and it is the
one most likely to be forgotten: ⛔ **there is no cloud VM and there never will
be, and no BSD host exists.** A design that needs either is refused rather than
scheduled. [`RULES.md`](RULES.md).

---

## ⚠ How much a session takes on

⭐ **As many entries as it can finish properly**, not one, and not one per
`L` estimate. ⛔ The gate, the test suite and the mandatory reviews are what
hold quality, so an agent that clears five entries has cleared five gated,
reviewed entries. ⚠ Stop at roughly five, or when the operator interrupts.
[`RULES.md`](RULES.md).
