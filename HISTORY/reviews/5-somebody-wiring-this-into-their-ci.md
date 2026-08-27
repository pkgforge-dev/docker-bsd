# Review 5: somebody wiring this into their CI

⭐ **The lens.** A platform engineer who wants BSD builds in a pipeline. They do
not care how it works. They care whether it is deterministic, whether it fails
loudly, and whether it will still work in six months without them watching it.

**Run** 2026-08-27, over the workflows, the experiments and the new entries.

---

## ⛔ What it found

### 1. ⛔ CI proves the repository, not the product

`.github/workflows/ci.yml` runs a static gate on two hosts and a reachability
probe. ⛔ **Nothing in CI boots a guest.** The one thing this project exists to
do is untested on every push, on every host, forever.

⚠ **The experiment that would test it already exists** and prints a
machine-readable result line, so this is a wiring gap rather than a missing
capability. ⭐ Filed as `INF-05`, P1, with the matrix it needs.

### 2. ⛔ Nothing is pinned by digest yet

The experiments fetch a kernel, a root filesystem and an image from moving tags,
and the container base is a floating tag. ⛔ **A pipeline that pins nothing is a
pipeline whose output changes without a commit.**

⚠ **This is deliberate for an experiment and fatal for a product.** `IMG-01`
carries the requirement explicitly; this review is why it says "pinned by
digest" rather than "pinned".

### 3. ⚠ There is no story for a machine with no registry

Everything assumes a pull. ⛔ An air-gapped runner, a proxy that blocks the
registry, or an organisation that mirrors internally has no route at all. Filed
as `INF-04`.

---

## ⭐ What it checked and found sound

| | |
| --- | --- |
| does a failure fail loudly | ⭐ yes, every check reads its exit code unpiped, and a skip is reported as a skip |
| is the publish path separate from the test path | ⭐ yes, and publishing already defaults to off |
| can a run be reproduced locally | ⭐ yes, CI runs the same scripts a developer runs, not a second copy |
| are third-party actions pinned | ⭐ yes, to a commit, with the tag in a trailing comment |
| are permissions least-privilege | ⭐ yes, `contents: read` at the top |

---

## ⛔ What this review did NOT look at

- **It did not run CI.** These workflows have never executed in this repository's
  new shape, so "the gate passes locally" is the whole evidence.
- ⛔ **It did not check that the required status check names match the job
  names.** Branch protection now requires two contexts by string, and a rename
  would silently stop gating. ⚠ That is a real trap and nothing tests it.
- **It did not consider cost.** A matrix over five axes is expensive, and
  nothing here has costed it.
