# 13. Somebody checking that dropping a BSD broke nothing

⛔ **The lens: the door sweep from
[`../../docs/methodology/reviews.md`](../../docs/methodology/reviews.md), applied
to a removal.** DragonFly was one of four targets and is now gone. The question
is not "was it a good decision": that is
[`../../TODO/RULES.md`](../../TODO/RULES.md) decision 7 and the operator's.
⭐ **The question is: what else reached it, and did every one of those doors get
closed?**

⚠ **A removal is the case where a door sweep pays most**, because nothing fails
loudly. A leftover reference to a deleted thing is a silent trap.

---

## 1. ⭐ Enumerate the doors, then grep for the ones not enumerated

**Enumerated from memory before grepping**, which is the point of the exercise:

1. `scripts/sources`, the matrix
2. `scripts/build-bsd`, the `iso` method
3. `README.md`, the matrix table
4. `docs/AGENTS.md`, the opening sentence
5. `.github/workflows/build-deploy.yml`, the build matrix
6. `tests/run.sh`, the method coverage check

**Then grepped.** ⛔ **The list was missing two**, which is the expected result
and the reason the rule exists:

| door | found by | state |
| --- | --- | --- |
| `docs/LIMITS.md` | ⛔ **grep, not memory** | a "what is not measured" bullet naming OpenBSD **and DragonFly** together. Fixed |
| `HISTORY/` (four files) | ⛔ **grep, not memory** | ⭐ **correctly left alone.** `HISTORY` is append-only and its DragonFly text was true when written |

⭐ **The `HISTORY` hits are the interesting ones**, because the instinct is to
"clean them up" and that would be the defect. `poc.md`, `misc/PROMPT.md`,
`bsd-entries.md` and both `references/` files describe a past in which
DragonFly was a target. ⛔ **They stay exactly as they are.**

---

## 2. ⛔ Can the guards still fail? Both were mutated

⭐ **`tests/run.sh` has a check whose whole job is to catch a BSD in
`scripts/sources` with no branch in `build-bsd`.** Removing a method could have
made it vacuous. ⚠ **It was tested, not assumed:**

```text
sh scripts/sources --method dragonfly   ->  sources: unknown id: dragonfly
exit 2
```

⭐ **Before the change this answered `iso` and exited 0.** ⛔ **So the removal is
observable from the outside**, and a workflow or script still passing
`dragonfly` gets a hard failure rather than a silent one. That is the behaviour
this repository wants and it was checked rather than believed.

⚠ **The method-coverage check itself is now weaker in one specific way**: with
only `oci` and `sets` left, and both handled, it cannot fail until somebody adds
a fourth BSD. ⛔ **That is fine, it is a check for a future edit**, but it
means the check passing today says less than it did yesterday, and that is worth
knowing before trusting it.

### ⛔ One guard NOT mutated, and it should have been

⚠ **`.github/workflows/build-deploy.yml` carries a DragonFly comment** and reads
its matrix from `sources --json`, which no longer emits DragonFly. ⭐ **The
workflow is therefore correct by construction** and its comment is stale.
⛔ **It was left**, because editing a workflow comment without running the
workflow is the kind of tidy change this repository's own conventions warn
about, and the matrix is data-driven so nothing behaves wrongly.

⚠ **Recorded as a known-stale comment**, not as a defect that was fixed.

---

## 3. ⭐ Was the knowledge preserved, or just the code?

⛔ **The rule that matters here is "a negative result is a result".** DragonFly
was not a negative result, the route worked, which makes it a **positive
result being retired**, and there is no rule for that.

⭐ **What was kept**, in [`../dragonfly.md`](../dragonfly.md):

- the mechanism, verbatim: `build_iso()` and the two matrix rows;
- ⭐ **the three traps**, which are the part that generalises: accept either
  reader, bare filenames for native Windows binaries, normalise ownership when
  repacking;
- ⛔ **why HAMMER2 closes the obvious route**, which is the single most
  expensive thing anybody would rediscover.

⚠ **One character-level change is declared in that file**: the section banner
was box-drawing characters, which this repository's document check refuses
outside a script. ⭐ **Declaring it is the difference between a record and a
claim of a record.**

### ⚠ What was NOT preserved, and it is a real loss

⛔ **The 748 MB extraction was never run**, so nobody knows whether the route
actually produces a working image. ⭐ **That was true before the removal too**,
and `README.md` said so; it now says the same thing in the past tense. ⚠ **The
loss is that nobody will ever find out**, which is the honest cost of the
decision.

---

## 4. ⚠ The claim in the new record that is weakest

⭐ **`dragonfly.md` says "It is the least maintained of the four, in the
operator's judgement."**

⛔ **That is attributed and unmeasured, and it is written that way on purpose.**
⚠ **This review checked whether anything in the tree contradicts it and found
one thing that cuts the other way**: `cross-platform-actions/action` supports a
DragonFly guest and maintains a CPU-feature workaround specifically for it,
which is evidence of somebody actively carrying it. ⭐ **That is now recorded in
`dragonfly.md` itself**, under a heading saying it is not flattering, to the
decision, not to DragonFly.

---

## ⛔ What this review did NOT look at

- **Whether `build-deploy.yml` still runs.** It was read and not executed. No
  workflow was dispatched this session.
- **The published images.** `ghcr.io` may still carry a DragonFly image from a
  previous run; nothing checked, and nothing untagged one.
- **`HISTORY/poc.md`'s DragonFly measurements** for accuracy. They were left
  untouched on the append-only rule and not re-read.
- **Whether OpenBSD, now one of three rather than one of four, has any of the
  same problems.** Its route is `sets`, same as NetBSD, and that was not
  re-examined.
- **The `iso` string in `tests/run.sh`'s accepted-method whitelist**, which is
  now unreachable. It is harmless and was left.
