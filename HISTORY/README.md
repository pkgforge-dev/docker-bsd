# HISTORY

⭐ **What happened, in its original wording.** Every measurement this repository
has taken, every premise a later measurement disproved, and every reference it
mined.

⛔ **Append, never edit.** A premise a measurement disproves **keeps its
wording** and gets the correction written underneath it. That is not politeness
about the past: a silently corrected document teaches nobody, and the reader who
needs this directory is the one about to make the same mistake.

⚠ **This is not the work order.** That is [`../TODO/PROGRESS.md`](../TODO/PROGRESS.md),
and it is the only file that carries one.

---

## What is here

| path | what it is |
| --- | --- |
| [`poc.md`](poc.md) | ⭐ the proof of concept. Every measurement behind the image-building half, with the commands that produced it |
| [`dragonfly.md`](dragonfly.md) | ⛔ **why DragonFly was dropped on 2026-08-28, and the working route that went with it**, kept verbatim so reversing the decision is a restore rather than a rewrite |
| [`inf-09.md`](inf-09.md) | ⛔ **`INF-09`'s withdrawn wording, kept verbatim.** The entry has published a confident explanation nine times; this is where each one lives with the measurement that took it away, including the control that named a culprit and then would not reproduce |
| [`bsd-entries.md`](bsd-entries.md) | ⛔ **how `BSD-01` and `BSD-02` reached their current answers**, in the original wording: the ranking table, the ruling that reopened it, the contradiction, and six sections headed `Correction:`. Moved out of `../TODO/bsd.md` on 2026-08-28 so that file could carry current facts |
| [`misc/`](misc/) | session records and the orientation prompt |
| [`references/`](references/) | ⭐ 37 external projects mined across four sweeps, with verdicts, a ranking, and the commands worth stealing |
| [`reviews/`](reviews/) | ⭐ deep reviews, **numbered by the reader each one imagines**. Each says what it swept, what it found, and ⛔ what it did NOT look at |

---

## ⭐ The reviews

⛔ **Each is named for the reader it imagines**, not for the area it covers. A
review named after an area finds what that area's author was already thinking
about; a review named after a person finds what that person would trip over.

| review | the lens |
| --- | --- |
| [`reviews/1-somebody-checking-whether-the-numbers-are-real.md`](reviews/1-somebody-checking-whether-the-numbers-are-real.md) | a reader who does not trust this repository and is hunting the sentence with no artefact behind it |
| [`reviews/2-somebody-who-cloned-this-and-has-nothing-else.md`](reviews/2-somebody-who-cloned-this-and-has-nothing-else.md) | ⭐ a person or agent with this repository and **nothing else** |
| [`reviews/3-a-maintainer-six-months-from-now.md`](reviews/3-a-maintainer-six-months-from-now.md) | somebody who has forgotten everything, opening the backlog to pick something up |
| [`reviews/4-a-consumer-who-read-only-the-limits-page.md`](reviews/4-a-consumer-who-read-only-the-limits-page.md) | ⭐ somebody deciding whether to use this at all, asking whether it will waste their afternoon |
| [`reviews/5-somebody-wiring-this-into-their-ci.md`](reviews/5-somebody-wiring-this-into-their-ci.md) | a platform engineer asking whether it is deterministic and whether it will still work unattended |
| [`reviews/6-an-air-gapped-consumer.md`](reviews/6-an-air-gapped-consumer.md) | ⭐ somebody with no route to a registry, who can only carry files in |
| [`reviews/7-does-this-project-deserve-to-exist.md`](reviews/7-does-this-project-deserve-to-exist.md) | ⛔ a skeptic who already has a cross toolchain and is asking why they would switch |
| [`reviews/8-somebody-who-runs-the-published-image-and-nothing-else.md`](reviews/8-somebody-who-runs-the-published-image-and-nothing-else.md) | ⭐ a developer who ran one command and will never open this repository. Everything they learn, they learn from the image's behaviour |
| [`reviews/9-somebody-auditing-what-this-image-pulls-in.md`](reviews/9-somebody-auditing-what-this-image-pulls-in.md) | ⛔ a person approving this for a team, asking what it downloads and whom it trusts |
| [`reviews/10-somebody-who-has-to-trust-this-sessions-instruments.md`](reviews/10-somebody-who-has-to-trust-this-sessions-instruments.md) | ⛔ a reader who notices that every conclusion came out of a tool written the same day, against a fault nobody understood |
| [`reviews/11-somebody-who-mined-28-projects-and-watched-nobody-read-them.md`](reviews/11-somebody-who-mined-28-projects-and-watched-nobody-read-them.md) | ⛔ the person who spent a day reading other people's trackers, asking whether that day bought anything |
| [`reviews/12-somebody-who-has-to-build-the-cross-toolchain-on-monday.md`](reviews/12-somebody-who-has-to-build-the-cross-toolchain-on-monday.md) | ⭐ a reader acting on the fourth sweep, asking whether they can start without re-cloning anything |
| [`reviews/13-somebody-checking-that-dropping-a-bsd-broke-nothing.md`](reviews/13-somebody-checking-that-dropping-a-bsd-broke-nothing.md) | ⛔ the door sweep applied to a REMOVAL, where nothing fails loudly |
| [`reviews/14-the-skeptic-again-now-that-clang-cross-compiles-for-all-three.md`](reviews/14-the-skeptic-again-now-that-clang-cross-compiles-for-all-three.md) | ⛔ review 7 re-run against evidence it did not have. The alternative got cheaper |
| [`reviews/15-somebody-who-started-building-on-last-sessions-answer.md`](reviews/15-somebody-who-started-building-on-last-sessions-answer.md) | ⛔ a reader who believed yesterday's answer and spent the day on it. What a single unrepeated control costs |
| [`reviews/16-somebody-who-pulled-the-build-variant-to-compile-something.md`](reviews/16-somebody-who-pulled-the-build-variant-to-compile-something.md) | ⭐ a developer reading the image rather than the repository, walking into three walls of which one was documented |

⛔ **Every review ends with what it did not look at.** A pass that reports
nothing means the pass was too shallow, and three passes reporting nothing is a
weaker result than one pass reporting a real defect.

---

## ⭐ How to read `references/`

Two halves, and they are not interchangeable.

- [`references/findings.md`](references/findings.md) carries the **verdicts and
  the argument**: what each project is worth, ranked, and why. Read it when
  deciding what to try.
- [`references/usable.md`](references/usable.md) carries the **commands and the
  outputs**. Read it when doing the thing.

⭐ **The single most repeated lesson in both is: read the tracker, not the
README.** The cost of a project is in its issues. Two sweeps in a row found
that the decisive fact, the one that changed a plan, was in an issue comment and
in no README anywhere.

---

## ⛔ Five corrections this repository has published about itself

⚠ Listed here because a reader who trusts a document without checking this page
will trust five sentences that are wrong.

1. **"There is no counterpart presenting BSD syscalls on a Linux kernel."**
   One was built and abandoned in 2022. ⭐ The conclusion holds and the
   reasoning changed. [`references/usable.md`](references/usable.md).
2. **"Under the Windows hypervisor, these CPU models wedge the emulator."**
   ⛔ Did not reproduce here on current software. The sources measured older
   software on other hardware and are not falsified; the prediction about this
   machine was. [`references/usable.md`](references/usable.md).
3. **"The guest's clock is why Go binaries die."** ⛔ Withdrawn inside the same
   session that published it. The clock measurably works and the fault is
   elsewhere. [`bsd-entries.md`](bsd-entries.md).
4. **"Installing a compiler into the guest is slow because of X."** ⛔ Eight
   values of X, published and withdrawn one at a time. It is none of them: the
   destination filesystem decides whether the write finishes at all.
   `INF-09` in [`../TODO/infrastructure.md`](../TODO/infrastructure.md).
5. ⛔ **Correction 4 is itself withdrawn.** "The destination filesystem decides"
   was the headline of four documents for one session, and the single `tar`
   control it rested on does not reproduce: the same command onto the same ext2
   root finishes in about half a minute, through two different instruments.
   ⭐ The eighth value of X, `pkg_add`'s own work, is the one left standing.
   [`inf-09.md`](inf-09.md).

⛔ **Five corrections, and the fifth is a correction to a correction.** ⚠ Notice
what that costs to catch: numbers 1 to 4 were caught by a review or a later
measurement, and number 5 needed **the same control run a second time**. ⭐ That
is the argument for [`../docs/methodology/reviews.md`](../docs/methodology/reviews.md)
and for repeating a diagnosis, in one sentence each.
