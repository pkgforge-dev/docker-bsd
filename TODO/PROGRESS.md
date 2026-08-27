# PROGRESS.md

⭐ **The only file that carries a work order.** Where the work is, what is next,
and why. [`INDEX.md`](INDEX.md) is the list of entries; the **order lives here
and nowhere else**. [`SUMMARY.md`](SUMMARY.md) is the brief, read first and in
full, and it is a snapshot rather than an authority.

⛔ Rewritten at the beginning and the end of every session. It carries no
history: the history is the git log, [`../HISTORY/`](../HISTORY/) and the
entries themselves. Do not add a "previous sessions" section.

⛔ Edited in the same change as the work, never as a report afterwards.

---

## State

```text
session started 2026-08-27T12:54:52Z
baseline        this repository became standalone in this session
entries         total 19  open 18  blocked 0  done 1
```

⚠ The counts above are checked against [`INDEX.md`](INDEX.md)'s rows by
`scripts/common/check-record.sh`, which runs as a gate. ⛔ Do not edit them by
hand to make a check pass; fix whichever file is wrong. ⭐
`scripts/common/set-record.mjs` moves them for you.

| fact | value |
| --- | --- |
| repository | `pkgforge-dev/docker-bsd`, public, 0BSD |
| work model | todo. [`../docs/methodology/work-todo.md`](../docs/methodology/work-todo.md) |
| publishes | OCI images for four BSDs to `ghcr.io`. ⚠ Not yet anything bootable |
| the local gate | ⭐ `sh scripts/common/check-gate.sh --fast`, then `sh tests/run.sh` |
| CI | `.github/workflows/ci.yml`, static only. ⛔ It cannot run a BSD image and does not pretend to |

---

## ⭐ The headline, and it is measured

⛔ **A FreeBSD userland runs on a Windows host with no nesting**, on the
machine's own hypervisor, from an unelevated shell. A container runs inside it.

The commands, the numbers and the conditions are in
[`../docs/LIMITS.md`](../docs/LIMITS.md) and the experiments that produced them
are in [`../experiments/`](../experiments/README.md). ⛔ **They are not repeated
here**: one fact, one home.

---

## What this session did

**2026-08-27. Two things, and the second was not planned.**

1. ⭐ **Nine experiments**, run rather than written, covering every route
   from a Windows host to a booted BSD. Each is committed with its result,
   including the two that failed and the one that printed a false success.
2. ⭐ **This repository became standalone.** It was developed beside
   `Azathothas/ToolKit` and borrowed that tree's checks, conventions and
   methodology. Those are now vendored here, adapted, and the record that
   tracked this work moved with them.

⚠ **What that second half changed, concretely:** the gate, the conventions, the
methodology and the security rules are this repository's own copies. ⛔ **One
reference remains deliberately**, and it is pinned:
[`../docs/vendored.md`](../docs/vendored.md) records it.

---

## ⭐ The work order

⛔ **The largest defect in this project is invisible from the inside: it
works, and nobody can use it.** A route to a BSD shell that needs nothing but a
container engine is measured, and no published image does it.

⛔ **The second largest is that the project cannot justify itself.** Nothing
here has compiled anything, so a developer with a cross toolchain has no
evidence to switch on.

Everything below is ordered by those two.

### 1. ⛔ `IMG-01`, then `IMG-02`. The only P0s

`IMG-01` is the promise in one command:

```bash
podman run --rm -it ghcr.io/pkgforge-dev/freebsd:latest sh
```

`IMG-02` is that promise being worth keeping: a real userland with a package
manager, rather than the 20 MB rescue shell the measured route boots today.

⛔ **In that order.** Shipping `IMG-02` first builds a development
environment nobody can start.

### 2. ⛔ `PERF-02`, then `PERF-03`. The entries that can end this project

Two users, one program, one matrix: a developer cross-compiling on Linux against
a developer using this image, over a real C, C++, Go and Rust project.
⛔ **The bar is 5 percent**, and failing it publishes the ratio rather than
quietly dropping the bar.

⚠ `PERF-01` is the smaller version of the same question and comes first
only because it is cheaper.

### 3. ⚠ `IMG-03`, `INF-04`, `INF-06`. The three that decide whether it is usable

- `IMG-03`: ⛔ `-v`, `-p` and `-e` reach the container and stop there.
- `INF-04`: ⛔ every route starts with a network fetch, so an air-gapped
  consumer has nothing at all.
- `INF-06`: ⛔ everything consumed here belongs to somebody else, and a
  fetch that returns an error page must not be imported as a root filesystem.

### 4. ⭐ `PORT-01` and `INF-05`. Turning one datapoint into a guarantee

Every portability claim is inferred from one Windows laptop. `PORT-01` is one
command per host; `INF-05` is the matrix that makes it a standing guarantee
instead of a one-off.

### 5. ⚠ `INF-07`, and it is partly done

The consumer-facing pages have had one tightening pass. ⛔ They still carry
narrative that belongs in [`../HISTORY/`](../HISTORY/README.md), and the entry
stays open until a page can be read as a manual.

### 6. The `OPT-*` entries, which are levers and not goals

⛔ **Do not pull one before `PERF-02` says which is stuck.** Optimising a
workload that was already fine is how a month is spent for nothing.

### 7. ⚠ `BSD-01`, which was the headline and is not any more

⭐ The container route overtook it: more hosts, less privilege, faster to a
shell. It stays open because its acceptance command has not returned 0.

⛔ **Its blocker is a guest fault, not a client one.** `podman system
service`, a long-running multithreaded Go daemon, panics the FreeBSD kernel in
`_umtx_op`, which is what a Go scheduler parks threads on. Everything underneath
it works.

---

## ⭐ Open questions: none. Four were answered on 2026-08-27.

⛔ **They are settled and recorded in [`RULES.md`](RULES.md), which persists
where this file is rewritten.** Restated here as pointers only, so the two
cannot fork.

| the question | the ruling |
| --- | --- |
| what does the first published image ship, and what is it called | ⭐ **NetBSD, named `netbsd`.** Ship now rather than waiting for FreeBSD |
| what is the performance baseline measured against | ⛔ **a free GitHub runner**, both users in the same job. Not a BSD host, not the developer's laptop |
| what base does the container use | ⛔ **build towards `scratch`.** Alpine is a stepping stone. A consumer who cannot debug it opens an issue |
| what if 5 percent cannot be met | ⛔ **keep optimising.** The entry does not close by repositioning the project |

⚠ **One constraint from those answers reaches every entry**, and it is the
one most likely to be forgotten: ⛔ **there is no cloud VM and there never will
be, and no BSD host exists.** A design that needs either is refused rather than
scheduled. [`RULES.md`](RULES.md).

---

## ⚠ How much a session takes on

⭐ **As many entries as it can finish properly**, not one, and not one per
`L` estimate. ⛔ The gate, the test suite and the mandatory reviews are what
hold quality, so an agent that clears five entries has cleared five gated,
reviewed entries. ⚠ Stop at roughly five, or when the operator interrupts.
[`RULES.md`](RULES.md).
