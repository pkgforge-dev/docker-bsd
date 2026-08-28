# RULES.md

⛔ **Standing policy and settled decisions.** Unlike
[`PROGRESS.md`](PROGRESS.md), which is rewritten every session, this file
persists. ⛔ **Do not reopen anything here without the operator.**

[`INDEX.md`](INDEX.md) is the entry list; [`PROGRESS.md`](PROGRESS.md) is the
order.

---

## ⛔ The constraints every decision is made under

⚠ **These are facts about this project's situation, not preferences.** A design
that ignores one of them is not a design for this project.

| | |
| --- | --- |
| ⛔ **there is one developer and one machine** | a Windows laptop. No fleet, no lab |
| ⛔ **there is no cloud VM, and there never will be** | a design that needs one is refused |
| ⭐ **free GitHub CI is the target environment** | it is where this will be built, tested **and used**. If it does not work there, it does not work |
| ⛔ **no BSD host is available** | anything requiring one to be provisioned is blocked, not scheduled |
| ⚠ every published number is from one machine | until `PORT-01` closes, portability is inferred |

⭐ **The consequence that catches people out: the benchmark runs on a free
runner.** Not on the developer's laptop, not on dedicated hardware. ⛔ A number
that cannot be reproduced by a stranger pushing to a fork is not a number this
project can publish.

---

## ⭐ Decisions already made. Do not reopen.

### 1. ⭐ The first published image is NetBSD, and it is named for what it is

**Ruled** 2026-08-27 by the operator.

⛔ **Not `freebsd`.** The microvm that boots in seconds is NetBSD's; FreeBSD has
no published equivalent today. Publishing a fast image under the FreeBSD name
would be the single most misleading thing this project could do.

⭐ **Ship it now rather than waiting.** It unblocks `IMG-01`, gives `PERF-02`
something to measure, and gives `PORT-01` something to run. FreeBSD follows when
`IMG-02` has a full root filesystem.

### 2. ⛔ The performance baseline is measured on a free GitHub runner

**Ruled** 2026-08-27 by the operator.

⛔ **Not on a BSD host, and not on the developer's laptop.** Both users in
`PERF-02` run in the same CI job on the same runner:

| | |
| --- | --- |
| **A** | a Linux cross toolchain, on the runner |
| **B** | this project's image, on the same runner |

⭐ **That is a fairer comparison than the one first proposed** and it removes a
blocker: it needs no hardware anybody has to own. ⚠ It also means the numbers
carry the runner's variance, so a result is a median over several runs and never
a single one.

### 3. ⭐ The container base builds towards `scratch`

**Ruled** 2026-08-27 by the operator.

⛔ **The destination is a purpose-built emulator on `scratch`**, not a
distribution base. `OPT-02` is the direction of travel and not an optional
optimisation.

⚠ **A base with no shell cannot be debugged in place, and that is accepted.**
The consumer experience should feel native; ⭐ **when it does not, they open an
issue** rather than being handed a shell to investigate with. That is a
deliberate trade of debuggability for size and speed.

⚠ **Alpine is a stepping stone.** It is what the measurement was taken on. It is
not the answer.

### 4. ⛔ 5 percent is a hard gate

**Ruled** 2026-08-27 by the operator.

⛔ **Keep optimising until it is met.** `PERF-03` does not close by publishing a
worse ratio and repositioning the project.

⚠ **The honest consequence, stated so nobody is surprised by it:** this may
consume more than one session, and the levers in `OPT-01` to `OPT-03` exist for
it. ⛔ **It does not license optimising before `PERF-02` says which layer is
stuck.**

### 5. ⛔ A BSD userland on a Linux kernel is closed forever

**Measured**, not decided. It exits 139 on its first syscall.
[`../docs/traps.md`](../docs/traps.md) row 1. ⛔ No `binfmt_misc` or `qemu-user`
configuration reaches it, and a proposal that assumes otherwise has not read the
measurement.

### 6. ⛔ This repository does not rebuild what upstream publishes correctly

FreeBSD publishes its own OCI images. They are verified and loaded here, never
rebuilt.

### 7. ⛔ Three BSDs, not four. DragonFly is dropped

**Ruled** 2026-08-28 by the operator.

⛔ **The targets are FreeBSD, OpenBSD and NetBSD.** Everything else is either a
derivative of one of those or too niche to carry.

⚠ **DragonFly was not dropped because the route failed.** It worked: the disk
image is HAMMER2 and unreadable on Linux, and the ISO is ISO9660 and readable
anywhere. ⛔ It was dropped because it was the only target needing a **third
acquisition method**, an ISO9660 reader, and a tool dependency neither other BSD
needs, for the least maintained of the four.

⭐ **The code and the three traps it paid for are kept**, verbatim, in
[`../HISTORY/dragonfly.md`](../HISTORY/dragonfly.md), so reversing this is a
restore rather than a rewrite.

### 8. ⛔ The cross toolchain, when one is needed, is `mussel`

**Ruled** 2026-08-28 by the operator.

⚠ **For Linux targets only**, which is what it does: it builds a cross compiler
targeting `musl`. ⛔ **It has no BSD target and is not the answer to
`PERF-02`'s user A.** [`../HISTORY/references/usable.md`](../HISTORY/references/usable.md),
the `R37` section, has the command and what it covers.

### 9. ⛔ A control that changes the direction of an entry is run TWICE

**Ruled** 2026-08-28 by the operator.

⛔ **Not every measurement.** A rule that doubles every run is a rule that gets
ignored. ⭐ **The ones a conclusion turns on**: a control that decides which of
two things is at fault, that closes a route, or that becomes a section heading.

⚠ **This repository already had the rule for benchmarks** and applied it in one
place: decision 2 says a result is a median over several runs and never a single
one, because a free runner moves. ⛔ **Nothing said it about a diagnosis**, and a
diagnosis is where a single reading does the most damage: a benchmark that is
40 percent out publishes a wrong number, and a control that is wrong publishes a
wrong **direction**.

⛔ **It has been paid for once.** "The destination filesystem decides whether a
490 MB write finishes" rested on one `tar` that was recorded as not finishing.
It was the headline of four documents for a session, and the next session's
first task was to rebuild a filesystem because of it. ⭐ **Repeating that one
control took the whole answer away**, and the fix that was about to ship would
have worked without being understood.
[`../HISTORY/inf-09.md`](../HISTORY/inf-09.md) has the wording;
[`../HISTORY/reviews/15-somebody-who-started-building-on-last-sessions-answer.md`](../HISTORY/reviews/15-somebody-who-started-building-on-last-sessions-answer.md)
is the review that asked for this rule.

⚠ **The second run is a run, not a re-read.** Same command, same artefact, a
fresh process. ⭐ **A different instrument is better than the same one**, because
the two failure modes rarely overlap: the withdrawn control was repeated through
the plain driver and through the instrument that had produced the original
reading, and they agreed.

### 10. ⛔ A session leaves the MACHINE as it found it, not just the tree

**Ruled** 2026-08-28 by the operator, after 37 GB of this project's own build
layers were found on the development machine with nobody having pruned them.

⛔ **"Leave the tree clean" was the only teardown rule and it is not enough.**
A session that commits, pushes and walks away having left a running emulator, a
stopped container or forty dangling 2.3 GB image layers has not finished.

| what | the rule |
| --- | --- |
| ⛔ **a running guest** | ⛔ **the session is not over.** A booted guest is either work in flight, in which case finish it, or it is abandoned, in which case stop it |
| a container | ⭐ **`--rm`, always.** Every `podman run` in this repository already has it and that is why no exited container was ever left |
| ⛔ **image layers** | ⛔ **prune what this project built.** A `podman build` of a 2.3 GB image leaves 2.3 GB of dangling layers on every run |
| ⚠ anything else on the machine | ⛔ **leave it alone.** Another project's volumes, images and containers are not this session's to reap |

⭐ **[`../scripts/common/reap.sh`](../scripts/common/reap.sh) is the command**,
and it refuses while a guest is still running rather than tidying up around a
measurement in progress.

---

## ⛔ How work is done here

⚠ Restated as pointers only. The rules live where they are linked.

| | |
| --- | --- |
| a negative result is committed | [`../experiments/README.md`](../experiments/README.md) |
| measured, or labelled. Never estimated | [`../docs/conventions/prose.md`](../docs/conventions/prose.md) |
| one fact, one home | [`../docs/conventions/docs.md`](../docs/conventions/docs.md) |
| exit codes read unpiped | [`../docs/conventions/shell.md`](../docs/conventions/shell.md) |
| two deep reviews before a session ends | [`../docs/methodology/reviews.md`](../docs/methodology/reviews.md) |
| no tool is credited in a commit | [`../docs/conventions/git.md`](../docs/conventions/git.md) |
| ⛔ a direction-changing control is run twice | decision 9 above |
| ⛔ the machine is left as it was found | decision 10 above, and `sh scripts/common/reap.sh` |

---

## ⛔ Ending a session, including one that is interrupted

⛔ **The same protocol either way.** An interrupted session owes exactly what
a finished one owes, minus what it was explicitly told to skip. ⚠ "I ran
out of room" is a reason to record less work, never a reason to leave the tree
in a state the next agent has to reconstruct.

### ⛔ Step 0. A session with work in flight has not reached step 1

⛔ **A measurement that is still running is not a task that can be paused.**
An emulated compile takes tens of minutes and there is nothing to checkpoint:
stopping it discards it, and it has to be started again from the beginning by
somebody who does not know that it was nearly done.

⛔ **So: HOLD. Do not write a summary while a guest is running.** ⚠ A message
that reads like an ending, sent while an experiment is mid-run, is worse than
silence, because the operator reasonably reads it as "finished" and the process
is still on their machine consuming a CPU.

⭐ **Holding is work, not waiting.** Do something that does not touch the
running measurement: the reviews, the record, a document, the next entry's
reading. ⛔ **A session that has nothing left to do but wait says exactly that,
and keeps the turn**, rather than closing and leaving a process behind.

⚠ **This is written from an incident.** A session left an emulated compile
running, wrote its wrap-up, and did not print a resume prompt, because "I have
nothing more to type" was treated as "the session is over". They are not the
same thing.

**Then, in this order:**

1. ⛔ **Finish the task in flight if it cannot be paused.** A half-applied
   refactor or a half-written document costs the next session more than the
   whole task would have. ⚠ If it CAN be paused, pause it cleanly and say
   where.
2. ⭐ **Checkpoint.** Rewrite [`PROGRESS.md`](PROGRESS.md) and reconcile
   [`INDEX.md`](INDEX.md)'s counts, in the same change as the work. ⛔ The
   record is part of the change, not a report about it.
3. ⛔ **Two deep reviews, minimum, each a different lens**, each ending with
   what it did **not** look at. They go in
   [`../HISTORY/reviews/`](../HISTORY/reviews/), named for the reader they
   imagine. ⚠ **If and only if the operator explicitly says to skip them**,
   file them as the **first entry** for the next session rather than dropping
   them.
4. ⛔ **Run the gates and read every exit code unpiped.**

```bash
sh scripts/common/check-gate.sh
```

```bash
sh tests/run.sh
```

5. ⛔ **Reap the machine, and read the exit code.** Decision 10. It refuses
   while a guest is still running, which is step 0 asserting itself rather than
   being remembered.

```bash
sh scripts/common/reap.sh
```

6. ⛔ **Commit and push**, unless told not to. ⚠ A session that ends with
   uncommitted work has produced nothing a next session can build on.
7. ⭐ **Print a resume prompt in chat**, and only in chat. It says what is
   done, what is in flight, and what to do next, so a **new independent
   session** can continue with no memory of this one.

⛔ **The resume prompt is the last thing, and it is not optional.** ⚠ A summary
of what happened is not a resume prompt: the test is whether an agent with no
memory of this session could paste it and carry on. ⭐ **If the last message of
a session does not contain one, the session did not end. It stopped.**

⛔ **Leave the tree clean and the machine clean.** Steps 5 to 7 are what make an
interruption survivable.

---

## ⚠ How much a session takes on

⭐ **As many entries as it can finish properly**, not one. ⛔ **Quantity is not
the goal and it is not the constraint either**: the gate, the test suite and the
mandatory reviews are what hold quality, so an agent that clears five entries
has cleared five gated, reviewed entries.

⚠ **Stop at roughly five, or when the operator interrupts.** ⛔ Stopping early
because an entry "looks big" is how a backlog stops moving; an `L` estimate here
is a guess and no entry has been attempted yet.
