# 11. Somebody who mined 28 projects and watched nobody read them

⛔ **The lens: a person who spent a day reading other people's trackers for this
repository, and wants to know whether that day bought anything.** They are not
asking whether the files are good. They are asking whether the work reached the
work.

⚠ **This review exists because the operator asked the question on 2026-08-28 and
the answer was no.**

---

## 1. ⛔ The measurement, because "nobody read it" is a claim

Reads leave no trace. **Writes and citations do**, and both were checked.

| what was checked | result |
| --- | --- |
| commits touching `HISTORY/references/findings.md` or `usable.md` since they landed | ⛔ **none.** Both files are exactly as they arrived in `ac22a39` |
| citations to them in `README.md`, `docs/AGENTS.md`, `docs/vendored.md`, `TODO/bsd.md` | ⛔ **every one arrived in `ac22a39` itself**, as part of the same import |
| citations written by a **later** session | ⭐ **one.** `TODO/performance.md`, in `657de62`, the `OPT-03` row citing the 2022 reverse syscall translator |
| citations to `findings.md` written by a later session | ⛔ **zero** |

⭐ **So 1,634 lines were carried for four sessions and drawn on once.**

---

## 2. ⛔ The routing was the defect, and it is a specific one

[`../../docs/AGENTS.md`](../../docs/AGENTS.md) routed to `HISTORY/references/`
from exactly one row: **"Studying another project"**.

⛔ **No session has had that task.** Every session since the import has been
building, measuring or fixing this repository, and the router's own rule is
"find the row for the work in front of you and read what it names". ⚠ **The
research was filed under a verb nobody had.**

⭐ **Two things were wrong at once**, and only fixing both helps:

1. the row was reachable only by a task nobody was doing;
2. ⛔ **no `TODO/` entry named a section of it.** An entry that says "read the
   28-reference sweep" is a pointer at 1,634 lines and is not actionable; an
   entry that says "read `usable.md`'s `R7` section before designing this" is.

### What was changed

- ⭐ a new row, **"Designing ANYTHING before writing it"**, above the old one;
- ⭐ a paragraph in **"Start here, every session"**, because the router's rows
  are read by task and this one has to be read by everybody;
- ⭐ **every `TODO/` file now carries a `Prior art already read` table**, naming
  sections against the entries they bear on. `bsd.md`, `images.md`,
  `measurement.md` and `performance.md`. `infrastructure.md`'s pointer lives
  inside `INF-09`, where the cost was paid.

---

## 3. ⛔ What it actually cost, measured rather than asserted

⚠ **The operator's charge was that this session would have "solved it hours ago"
with the research.** ⛔ **That is not true and it should not be recorded as
true.** `INF-09`'s cause is a NetBSD ext2 filesystem with 1 KB blocks; neither
file contains the words `ext2`, `pkg_add`, `pkgsrc` or `block size`. The sweep
was about **getting a BSD to run**, and it succeeded at that: smolBSD, which
this repository now ships, is `R7`, ranked second.

⭐ **What it WOULD have changed is real and is smaller:**

- `usable.md`'s `R7` section records that smolBSD ships **`smoler.sh`, a
  Dockerfile-shaped builder in which `RUN` works inside the guest**. ⛔ **This
  repository hand-wrote a serial-console provisioner instead**, and that
  provisioner is what `INF-09` is about. The fault would still exist; the
  project would have met it inside somebody else's supported mechanism, with a
  tracker to report it to.
- `findings.md`'s `R7` verdict records **83 tracker items and 51 threads, of
  which two were read**. ⚠ That is the first place a smolBSD fault should be
  looked for, and no entry said so.
- `usable.md`'s `honest-limit` row on `mount_psshfs` describes **a parallel
  build reading back truncated object files** over a shared filesystem. ⛔ That
  is `IMG-03`'s and `PERF-02`'s problem in advance, and neither entry mentioned
  it.

⛔ **So the honest cost is: one avoidable reimplementation, and three entries
that were going to walk into recorded traps.** Not a day.

---

## 4. ⚠ The second half of the same defect, which is not fixed

⛔ **`docs/methodology/references.md` is binding on any task whose verb is
clone, mine, survey or investigate, and no session has had one of those verbs
either.** The method is written, correct and unexercised since the import.

⚠ **The sweep is also a year-old snapshot the day it was taken.** Its own
provenance section says so: "a later session re-reads rather than trusting it".
⛔ **Nothing schedules that re-read**, and `INF-02` is about noticing when
upstream moves for **artefacts**, not for references.

⭐ **That is a filed gap and not a fix**, and it is named here rather than
invented as an entry, because an entry filed from a review that nobody asked for
is how a backlog fills with work nobody chose.

---

## 5. ⚠ A drift check on the citations that were added

⛔ **Every section named in the new tables was opened and read**, not cited from
the sweep's own index. Three were adjusted after reading:

- `R17`'s value was cited as "the official BASIC-CI images"; the line that
  matters for `PERF-01` is the **`udev` rule that makes a runner's `/dev/kvm`
  writable**, which is what `docs/LIMITS.md` section 1b has an open question
  about. The pointer names that.
- `R26` `bsdkrun` was nearly cited under `IMG-01`; ⛔ it is macOS and Linux
  only, so on this host it is nesting. It is cited under `OPT-03`, where the
  shape question lives.
- `R28` `lsf` was nearly cited as "a BSD userland on Linux was tried". ⚠ The
  useful part is narrower: **the conclusion holds and the published reason must
  change.** "Nobody has tried" is false.

---

## ⛔ What this review did NOT look at

- **Whether the 28 verdicts are correct.** Not one reference was re-fetched.
  Every claim about them here is a claim about what the files say.
- **`HISTORY/references/usable.md` past its BSD sections.** The FreeBSD-host
  half was skimmed and not read against the entries it might serve.
- **`TODO/infrastructure.md`'s other nine entries.** Only `INF-09` and `INF-10`
  were given prior-art pointers; the rest have none and may deserve them.
- **`README.md` and `docs/consumers.md`**, which cite the sweep and were not
  re-read against it this session.
- **Whether any of the 28 projects has moved.** The sweep is dated 2026-08-27
  and nothing re-checked a single one.
