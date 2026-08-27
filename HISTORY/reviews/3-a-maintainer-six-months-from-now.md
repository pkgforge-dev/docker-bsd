# Review 3: a maintainer six months from now

⭐ **The lens.** Somebody who has forgotten everything, opens the backlog, and
has to pick something up and finish it. They do not want the argument; they want
to know what to do, what "done" looks like, and why it is next.

**Run** 2026-08-27, over the eight entries filed from
[`../../docs/LIMITS.md`](../../docs/LIMITS.md).

---

## ⛔ What it found

### 1. ⛔ The published boot time quoted the fastest of three runs

[`../../docs/LIMITS.md`](../../docs/LIMITS.md) headlined a single figure for the
Windows route. ⛔ **Three boots were measured and they were not that close
together.** The phase table underneath was the breakdown of the fastest one.

⚠ **That is how a benchmark becomes a claim.** Nothing was fabricated and the
number was real; it was the best real number, presented as the number.

⭐ **Fixed.** The range is quoted, the phase table says which run it breaks down,
and it says why the range is quoted rather than the best.

### 2. ⚠ One closed entry states its acceptance in a different shape from the rest

`BSD-02` carries `**Prove.**` inline where every other entry carries a
`### Prove` heading. ⛔ **A maintainer scanning for acceptance criteria will
miss it**, and a check that looked for the heading would report it as missing.

⚠ **Left as it is, deliberately.** It is a closed entry and
[`../README.md`](../README.md) says `HISTORY/` and closed work keep their
wording. ⭐ **Recorded here instead**, so the next person who writes that check
knows it is one exception and not a defect.

---

## ⭐ What it checked and found sound

| question a maintainer asks | answer |
| --- | --- |
| does every open entry say where it came from | ⭐ yes, all ten carry a `Source`, and eight name the operator's own question |
| does every open entry have a runnable acceptance | ⭐ yes, a command with an expected exit code and expected output |
| is the order argued, not just asserted | ⭐ yes, [`../../TODO/INDEX.md`](../../TODO/INDEX.md) closes with the argument, including why the old headline entry was demoted |
| can I tell a P0 from a P2 without asking | ⭐ yes, defined once in `INDEX.md` and meant |
| does an entry tell me what NOT to do | ⭐ `IMG-01` does, which is the one most likely to be built wrong |
| is there a number behind each entry | ⭐ yes. Every one traces to a row in `LIMITS.md` |

⭐ **The strongest single thing here is that `IMG-02` says "measure before
building"** and names the measurement that decides the design, rather than
assuming one image can serve both cases.

---

## ⛔ What this review did NOT look at

- **It did not attempt any entry.** An acceptance command that reads well and
  cannot actually be run would pass this review.
- ⚠ **It did not check the effort estimates.** Two entries are marked `L` on no
  evidence at all; that is a guess and it is not labelled as one.
- **It did not read the vendored methodology pages**, which describe how entries
  are authored and still speak in another repository's terms in places.
- ⛔ **It did not ask whether the eight entries are the RIGHT eight.** They are
  all filed from measurements, which makes each defensible; it does not prove the
  set is complete. ⚠ The most likely gap is anything about the other three BSDs,
  which have images here and one closed entry between them.
