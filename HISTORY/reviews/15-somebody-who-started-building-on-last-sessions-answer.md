# 15. Somebody who started building on last session's answer

⛔ **The lens: a person who read `TODO/PROGRESS.md` this morning, believed it,
and spent the day.** It told them `INF-09` was answered, that the destination
filesystem decides, and that the fix was to stop growing a 1 KB filesystem and
make a 4 KB one instead. ⭐ **It was wrong**, and this review asks what that
would have cost them and what in this repository could have stopped it sooner.

⚠ **This is not a review of the previous session's honesty.** Every number it
published was taken. It is a review of what this repository lets a single
reading become.

---

## 1. ⛔ What they would have built, and it would have "worked"

⭐ **Follow the instruction as written.** `PROGRESS.md` said: `debugfs -R rdump`
the tree out, `mke2fs -b 4096 -d` a new one, write the package in from Linux.
⛔ **That is a real day's work**: a rewrite of
[`../../images/netbsd/grow-rootfs.sh`](../../images/netbsd/grow-rootfs.sh) into
a make-rootfs, a way to preserve the device nodes `rdump` does not carry, a new
splice into the GPT partition, and a rebuild of a 2 GB image to test it.

⛔ **And at the end of it, the `tar` would have finished in about half a
minute**, because it finishes in about half a minute on the 1 KB filesystem
too. ⚠ **They would have shipped it, published the fix, and closed the entry.**
⭐ The tenth explanation would have been the first one that was never even
tested against a control, because it appeared to work.

⛔ **`pkg_add` would still not finish**, and the next session would have opened
an entry about a package manager that hangs on a freshly rebuilt filesystem.

---

## 2. ⭐ What DID stop it, and it was one instruction

⛔ **The work order said "prove the block size is the lever before rebuilding
anything."** That sentence is the whole reason this session did not spend the
day. ⚠ It is also the sentence most likely to be skipped, because the entry
above it read as settled: a headline, a table, a kernel reading and an upstream
source line all pointing the same way.

⭐ **The instruction that saved the day is not in any convention.**
[`../../docs/conventions/prose.md`](../../docs/conventions/prose.md) has
"measured, or labelled", and every number here was measured.
[`../../docs/methodology/authoring.md`](../../docs/methodology/authoring.md)
has "measure before building, when the plan describes what the code does", and
the plan described a filesystem rather than code.

⛔ **The missing rule is about repetition, and this repository already has it in
one place and applies it in one place.** `TODO/RULES.md` decision 2 says a
benchmark result is "a median over several runs and never a single one",
because a free runner moves. ⚠ **Nothing said the same about a diagnosis**, and
a diagnosis is exactly where a single reading does the most damage: a benchmark
that is 40 percent out publishes a wrong number, and a control that is wrong
publishes a wrong *direction*.

---

## 3. ⛔ Where else a single reading is currently load bearing

⭐ **Swept for it, rather than asserted.** These are conclusions in this
repository that rest on one run of one thing, found by reading
[`../../docs/LIMITS.md`](../../docs/LIMITS.md) and the entries:

| the conclusion | what it rests on | risk |
| --- | --- | --- |
| ⛔ **the FreeBSD `podman system service` panics the guest kernel** | one panic, one trace, one guest | ⚠ **high.** It is a `docs/LIMITS.md` section 5 headline and it closes a route |
| ⚠ a different guest timecounter moves `podman run` to `rc=0` | one run, and the entry already says it is not a fix and the cause is not known | ⭐ **labelled.** This is the good case |
| ⛔ **NetBSD's microvm never attaches its paravirtual bus under WHPX** | a boot that reached a kernel and no disk | ⚠ **medium.** It is in the closed-routes table |
| the guest writes 100 MB in 2.5 seconds | one run, quoted in `INF-09`'s dead-guess table | ⚠ **medium.** It is a premise under three other rows |
| ⭐ the 42 percent between-job spread on a free runner | **two runs**, and the page says two samples is not a distribution | ⭐ **honest, and labelled as such** |

⛔ **The pattern is that the labelled ones are fine and the headline ones are
not.** A number that carries "one run" beside it can be read carefully. A
conclusion promoted to a section heading loses that qualifier on the way up.

---

## 4. ⭐ What this session changed, and what it did not

| | |
| --- | --- |
| ⭐ **changed** | `INF-09` now says what is measured and what is not, and the withdrawn wording is in [`../inf-09.md`](../inf-09.md) rather than deleted |
| ⭐ **changed** | three controls exist as committed experiments, each varying one thing, so the next reader repeats them with one command instead of trusting a paragraph |
| ⭐ **changed** | `experiments/README.md`'s finding 9 carries "run the control twice" as a rule with the incident under it |
| ⛔ **NOT changed** | `TODO/RULES.md` still says nothing about repeating a diagnosis. ⚠ **That is the operator's file and this review does not edit it**, per `docs/AGENTS.md`: name it, say what would change, offer |
| ⛔ **NOT changed** | the four single-reading conclusions in section 3 are still single readings. None was re-run today |

⭐ **The offer, stated concretely so the operator can rule on it in one line:**
add to `TODO/RULES.md`, under "how work is done here", a row saying **a control
that changes the direction of an entry is run twice before it is published**,
linking to `experiments/README.md` finding 9. ⚠ Not every measurement: only the
ones a conclusion turns on, because a rule that doubles every run is a rule that
gets ignored.

---

## ⛔ What this review did NOT look at

- **Whether the previous session's reading was real.** Nobody can tell from
  here, the console log was not kept, and this review deliberately does not
  speculate about the machine that day. ⚠ **It is the one question that would
  actually explain it**, and it is unanswerable.
- **Re-running the four single-reading conclusions in section 3.** They are
  named and left standing. Two of them close routes, which is the expensive
  kind of wrong.
- **The console fixes.** `INF-08` and `INF-10` closed in the same change and
  this lens has nothing to say about them; review 16 takes the instruments.
- **Whether `pkg_add` is genuinely the fault or merely the last suspect
  standing.** ⛔ It is the last suspect standing, which is not the same thing,
  and `INF-09` says so in as many words.
- **Anything about the cost of the day that was NOT spent.** The counterfactual
  in section 1 is reasoning, not measurement, and it is written as reasoning.
