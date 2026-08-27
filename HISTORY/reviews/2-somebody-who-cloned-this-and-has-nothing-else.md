# Review 2: somebody who cloned this and has nothing else

⭐ **The lens.** A person or an agent with **this repository and nothing else**.
No sibling checkout, no memory of how it got here, no access to the machine it
was built on. Can they orient, run the gate, and reproduce a published number?

⛔ **This is the lens the whole restructuring was for**, so it is the one most
likely to flatter itself. It was run against the tree, not against the
intention.

**Run** 2026-08-27, over the tree that became the first commit.

---

## ⛔ What it found

### 1. ⛔ A stale document contradicted its own replacement

`TOOLKIT.md` sat in the root saying, in detail, which scripts this repository
**must copy** from another one **before it can stand alone**.

⛔ **That had just been done**, and `docs/vendored.md` records it. So the tree
carried two documents about one subject, disagreeing about whether the work was
finished, and the stale one was in the root where it is read first.

⚠ **It was also linked from nowhere**, which is the state every stale document
passes through. ⭐ **Removed**, because `docs/vendored.md` supersedes it
completely.

### 2. ⛔ A compiled artefact was tracked, carrying an absolute path

`experiments/lib/__pycache__/console.cpython-313.pyc` was in the index. It is a
build product of the machine it was made on and **contains that machine's
absolute paths**.

⛔ **Two defects at once**: a generated file under version control, and one that
leaks the author's directory layout into a public repository. ⭐ Removed, and
`__pycache__/` and `*.py[cod]` added to `.gitignore`.

⚠ **Nothing caught it**, because it arrived as a side effect of running the
console driver rather than as an edit.

### 3. ⚠ Four files pointed at another repository for a document that now lives here

Three experiments and the experiments README named `BSD-01` as living in
`Azathothas/ToolKit`. ⛔ **It lives in `TODO/bsd.md` in this tree.** A reader
following that pointer would leave the repository to find something they already
had.

⭐ Fixed. ⚠ The remaining mentions of that repository are correct and stay: the
vendoring record, the session record in `HISTORY/`, and the one pinned reference
this repository still fetches.

---

## ⚠ What it checked and found sound

| question | answer |
| --- | --- |
| is there one obvious entry point | ⭐ yes, `docs/AGENTS.md`, and a test asserts there is exactly one |
| does the gate run from this tree alone | ⭐ yes, all 12 checks, nothing fetched |
| does the test suite run | ⭐ yes, 46 assertions |
| can a published number be traced to a command | ⭐ yes, `docs/reproducing.md` maps each one |
| is the machine every number came from stated | ⭐ yes, once, in `docs/environment.md` |
| does anything need credentials to read | no |
| is there a runnable starting point | ⭐ yes, `examples/03-what-can-this-host-do.sh` needs nothing and says what this host can do |

---

## ⛔ What this review did NOT look at, and one of them matters

⚠ Stated so the next reader does not assume coverage.

- ⭐ **It DID clone into a fresh directory and run there**, after this
  section first said it had not. The gap was named, and then closed rather than
  left for somebody else:

```text
git clone --branch initial-experiments <this repo> /tmp/freshclone
89 files
sh scripts/common/check-gate.sh --fast   ->  11 passed, 1 skipped
sh tests/run.sh                          ->  46 passed, 0 failed
```

  ⚠ A file that is present but **untracked** would have passed the
  in-place inspection and been missing from the clone. Nothing was.
- **It did not run the gate on a Linux host**, so the `.sh` halves are checked
  by `check-twins` and by CI rather than by this review.
- **It did not verify any of the upstream URLs still resolve.** CI has a job for
  that, deliberately allowed to fail without failing the gate, because an
  upstream outage is not a defect in this code.
- ⚠ **It did not read the vendored `docs/conventions/` and `docs/methodology/`
  pages line by line** for sentences written about the other repository. That
  debt is named in [`../../docs/vendored.md`](../../docs/vendored.md) and is
  real.
