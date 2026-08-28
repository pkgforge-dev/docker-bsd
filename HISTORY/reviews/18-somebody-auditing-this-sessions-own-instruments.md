# 18. Somebody auditing this session's own instruments

⛔ **The lens: [`10-somebody-who-has-to-trust-this-sessions-instruments.md`](10-somebody-who-has-to-trust-this-sessions-instruments.md),
turned on the session that corrected review 10.** That review audited a
session's tools and got two rows wrong. ⚠ **This session withdrew a headline,
published a new one, and wrote four new instruments in a day.** The same
question applies with more force: could these tools produce these answers if the
answers were false?

⭐ **Four defects in this session's own instruments were found by running them.**
All four are below, including the two that were caught only because something
downstream looked wrong.

---

## 1. ⛔ The four, and what each nearly cost

| the instrument | the defect | how it was caught | what it would have published |
| --- | --- | --- | --- |
| ⛔ **the hold loop** | its done-condition was `grep -q 'BENCH rc='`, and the log carries the **command** that will print `BENCH rc=$R` as well as its output | ⚠ **by the answer being absurd**: it declared a fifty-minute compile complete on its first tick | "the compile finished", with no seconds, over a compile still running |
| ⛔ **editing a running script** | a `# shellcheck disable` line was inserted into `47-comp-set-and-compile.sh` forty minutes into its run; a shell resumes at a byte offset | ⚠ **by the exit code**: `line 270: -c: command not found`, exit 127, **after** the result had printed | ⛔ **a correct measurement reported as a failed run.** The exit code lied about work that had succeeded |
| ⚠ **a patch script** | asserted an anchor **after** it had already mutated the text, so a failed assert left the file with half the change | ⚠ **by a later check disagreeing**: the reaper reported 0 dangling where `podman` reported 7 | a reaper that silently under-reports, which is the failure mode a reaper must not have |
| ⚠ **the reaper's attribution** | matched labels and env only, and the layers with no label were the majority | ⭐ **by reading them** rather than accepting the number | 14.1 GB reclaimed out of 22.5 GB, reported as "done" |

⛔ **Three of the four are the same defect wearing different clothes: a check
that matched something other than the thing it was checking.** The echo instead
of the output, the assert after the mutation, the label instead of the origin.
⭐ **This repository already has that class written down twice**, for a tty echo
and for a piped exit code, and it happened three more times in one day.

---

## 2. ⭐ Could this session's ANSWERS be false and still look like this

⚠ **The row-by-row question review 10 asked, asked of the answers that replaced
review 10's.**

| the claim | the instrument | could it produce this if false |
| --- | --- | --- |
| ⭐ `tar` onto the ext2 root finishes in about half a minute | two drivers, one of them the instrument that took the original reading, each with its own completion marker | ⛔ **no.** A marker-bracketed driver reports a status or reports a timeout; it cannot report a finish that did not happen. ⭐ **And it was run twice, on two instruments**, which is `RULES.md` decision 9 |
| ⭐ block size is not the lever | two filesystems one `mke2fs -b` apart, one guest each | ⛔ **no**, and the disks were identified by a marker file rather than by device number, because the device numbers move |
| ⭐ `pkg_add` does not finish | SIGINFO, self-tested on a healthy `sleep` first | ⛔ **no.** User time frozen across three samples is a kernel counter |
| ⚠ `pkg_add` stops AFTER the unpack | `pkg_add -v` printed every path and reached the last one | ⚠ **it could be weakened.** The listing proves the archive was read; it does not prove every file was written. ⛔ **Nothing checked the filesystem afterwards**, and that check was available and cheap |
| ⛔ **the guest compile takes more than 130x** | one run, one workload, no reading taken during it | ⛔ **YES.** ⚠ If the compile is STUCK rather than slow, this number measures a bug and not a cost, and `INF-09` is the standing proof that this guest can stop being scheduled |

⛔ **The last row is the one to carry forward**, and it is deliberately written
in the same shape as review 10's last row, which was the one review 10 got
right. ⚠ **A number is not safe because the session that took it was careful
about a different number.**

---

## 3. ⭐ What is now mechanical rather than remembered

⛔ **A rule this session wrote is worth exactly as much as the check under it.**

| what happened | what now enforces it |
| --- | --- |
| a console driver that never returned | ⭐ [`../../tests/console-bounds.py`](../../tests/console-bounds.py) and [`../../tests/console-bounds.ps1`](../../tests/console-bounds.ps1), **both seen to fail first**, both in `tests/run.sh` |
| a session that walked away from a running guest | ⭐ [`../../scripts/common/reap.sh`](../../scripts/common/reap.sh), **seen to refuse on its first run** |
| a control believed on one reading | ⚠ `RULES.md` decision 9. ⛔ **Prose. Nothing checks it** |
| a script edited while running | ⚠ a row in `forbidden-patterns.md`. ⛔ **Prose. Nothing checks it** |
| a done-condition matching an echo | ⚠ a row in `forbidden-patterns.md`. ⛔ **Prose. Nothing checks it** |

⛔ **Three of the five are prose**, and this repository's own standard is that a
guard never seen to fail is theatre. ⚠ **Two of the three are about how an agent
behaves rather than what the tree contains**, which is genuinely hard to check
from inside the tree, and saying so is better than pretending a row in a table
is a control.

---

## ⛔ What this review did NOT look at

- **The four instruments' code, line by line.** It audits what they produced and
  how they failed, not their implementations.
- **Whether the `comp` set is the right one.** NetBSD 11.0 headers against a
  `smolBSD 11.0_STABLE` userland compiled one file; that is not evidence of
  correctness, and `IMG-02` carries the question unresolved.
- **Whether the 27-second Linux figure is comparable at all.** ⭐ **Checked, and
  the first version of this review was wrong about it**: it is a best of three,
  not a single run, so decision 9 is satisfied. ⛔ **What the check found
  instead is worse and is this session's doing.** The "three runs" qualifier was
  dropped when `docs/LIMITS.md` and `PROGRESS.md` were rewritten today, so a
  three-run figure was on its way to being read as one. ⚠ **That is exactly the
  failure [`15-somebody-who-started-building-on-last-sessions-answer.md`](15-somebody-who-started-building-on-last-sessions-answer.md)
  named, a qualifier lost on the way up to a headline, committed by the
  session that wrote the review.** Restored, with the compiler caveat beside it.
- **`experiments/44` and `45`'s own exit codes.** ⭐ **Checked: both `exited 0`**,
  so neither was edited while executing and only `47` was. ⚠ Recorded because
  the first version of this review left it as an open question when one command
  answered it.
- **Anything about the reviews themselves.** Review 10 was wrong and this review
  uses its method. ⚠ **That is not a defence of the method**, and a third pass
  would be the honest test of it.
