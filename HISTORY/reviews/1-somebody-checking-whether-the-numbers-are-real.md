# Review 1: somebody checking whether the numbers are real

⭐ **The lens.** A reader who does not trust this repository and is looking for
the sentence that is not backed by an artefact. They do not run anything; they
read what is published and ask "where did that come from".

**Run** 2026-08-27, over the tree that became the first commit.

---

## What it swept

Every number, count and causal claim in `README.md`, `docs/LIMITS.md`,
`docs/traps.md`, `TODO/PROGRESS.md`, `TODO/SUMMARY.md`, `CHANGELOG.md` and
`experiments/README.md`, checked against the experiment output that produced it.

---

## ⛔ What it found

### 1. ⛔ Three documents claimed three different experiment counts

`CHANGELOG.md` said nine, `TODO/PROGRESS.md` said eight, `TODO/SUMMARY.md` said
eight. The tree had nine.

⚠ **The cause is ordinary and worth naming**: a ninth experiment was added late
and two of the three sentences were not revisited. ⛔ **A number written in prose
is a number that drifts**, and nothing was checking it.

⭐ **Fixed twice over.** The prose was corrected, and
`tests/run.sh` now asserts that every document claiming an experiment count
claims the **same** one and that it matches the tree. ⚠ The check compares the
**value**, not the spelling, so "9" and "Nine" agree: rejecting one of them
would be a house-style rule wearing a correctness check's clothes.

### 2. ⛔ A measured number had escaped into a second document

`CHANGELOG.md` carried a timing that `docs/LIMITS.md` also carried.

⛔ **That is the "one fact, one home" rule broken by the document that announces
the rule's repository.** Two copies of a number are two numbers, and the one a
reader trusts is the wrong one.

⭐ **Fixed**, and `tests/run.sh` now fails if any of the measured seconds appear
in a `.md` outside `docs/LIMITS.md`. ⚠ `experiments/`, `HISTORY/` and
`TODO/bsd.md` are exempt on purpose: an experiment prints its own measurement,
and the other two are records of when it was taken.

### 3. ⛔ A "what was not measured" list named something that had just been measured

`TODO/SUMMARY.md` said nothing had been measured about a host with only a
container engine. ⚠ **That had been measured an hour earlier**, and it is the
most useful result in the repository.

⭐ **This is the failure mode the lens exists for.** A caveat is written once
and then outlives the gap it described, and it is more dangerous than a missing
caveat because it reads as diligence.

---

## ⚠ What it checked and found sound

- Every timing traces to a specific experiment's output.
- Every causal claim about the hypervisor is stated as measured, and the one
  that was not is explicitly withdrawn under the claim rather than over it.
- The CPU-model result says which published reports it does and does not
  falsify.
- The two FreeBSD boot times are explicitly labelled as **not** a hypervisor
  comparison, because the kernels differ.

---

## ⛔ What this review did NOT look at

⚠ Stated so the next reader does not assume coverage.

- **It did not run anything.** Every number was checked against a recorded
  output, not re-measured. A recorded output that was wrong when it was
  recorded would pass this review.
- **It did not check the vendored documents** in `docs/conventions/`,
  `docs/methodology/` and `docs/security/` for claims about this repository.
  Those came from another tree and still speak in its terms in places, which is
  a debt named in [`../../docs/vendored.md`](../../docs/vendored.md).
- **It did not check `HISTORY/`**, which is append-only by rule and is allowed
  to contain claims that were true when written and are not now.
