# CHANGELOG.md

What shipped, when, and where the evidence is. One entry per shipped unit of
work, pointing at the record that carries the detail.

Four rules, and
[`scripts/common/check-changelog.sh`](scripts/common/check-changelog.sh) holds
all four:

1. ⛔ **Newest first.** A new entry goes at the top of its section.
2. ⛔ **Every heading carries a date**, as an ISO 8601 UTC stamp.
3. ⛔ **Every entry names its record**, the entry or commit carrying the
   evidence.
4. ⛔ **Every entry says whether it deployed.** "No deploy" is a complete and
   common answer. Silence is not.

⛔ Do not tidy this file while shipping something else, and do not delete an
entry. A superseded one is amended in place with a dated note.

---

## 2026-08-28

### 2026-08-28T05:30:00Z: the slow step has a cause, and the research nobody read now reaches the work

**Record:** `INF-09` in [`TODO/infrastructure.md`](TODO/infrastructure.md), with
the two controls and the kernel's own reading; the seconds and the geometry in
[`docs/LIMITS.md`](docs/LIMITS.md).
**Deployed:** ⛔ **no.** Nothing was published. The image is unchanged and the
fix that follows from this has not been built.

⛔ **Eight explanations for `INF-09` were dead and every one was inferred from
outside the guest.** Two controls settle it: the same 490 MB written by plain
`tar` does not finish on the guest's ext2 root and does finish in a tmpfs in the
same guest, so it is neither `pkg_add` nor the guest.

- ⭐ **The kernel was asked, because userland had stopped answering.** SIGINFO
  over 1,404 seconds: user time frozen at 15.78 s while system time climbed to
  1,382 s. ⛔ Spinning in the kernel, not waiting on IO.
- ⛔ **`ktrace` is not usable on this guest.** The binary is in the userland and
  `ktrace(2)` is not in the kernel, and the entry's own approach had asked for
  it.
- ⛔ **`TODO/bsd.md` was 893 lines of corrections to corrections.** The
  reasoning moved verbatim to
  [`HISTORY/bsd-entries.md`](HISTORY/bsd-entries.md); the entry file is 155
  lines of current facts.
- ⛔ **The 28-reference sweep was reachable only from a routing row nobody had
  reason to take.** Every `TODO/` file now names the sections that bear on its
  entries, and the router sends you there before you design anything.
- ⭐ **Two guards tightened and both seen to fail**: `tests/run.sh` lost its
  `TODO/bsd.md` exemption, and its count check no longer fails a correct
  document over a spelling it cannot read.
- ⛔ **One new defect filed, `INF-10`**: `Console.send()` blocks forever against
  a guest that has stopped draining its console, which is the fault this
  session was investigating wearing the instrument's clothes.

---

### 2026-08-28T00:40:00Z: an image that boots, published, and a second one with a compiler in it

**Record:** `IMG-01` in [`TODO/images.md`](TODO/images.md), closed in place with
its acceptance command and output; the timings and sizes in
[`docs/LIMITS.md`](docs/LIMITS.md).
**Deployed:** ⭐ **yes.** `ghcr.io/pkgforge-dev/netbsd:latest` on ghcr.io,
anonymously pullable, built and proved on a free `ubuntu-latest` runner.

⛔ **This repository could prove a BSD shell was reachable from nothing but a
container engine, and could not hand anybody the image that does it.** That gap
was invisible from the inside, because the experiment worked.

- ⭐ **The route is packaged.** The emulator, the guest kernel and the guest
  root filesystem are in layers, so nothing is fetched at run time. Proved by a
  CI run with `--network none` reaching the same shell.
- ⛔ **The guard was seen to fail.** CI asks the guest to `exit 3` and requires
  exactly 3 back, so the acceptance is not an entrypoint that always exits 0.
- ⭐ **A second variant with a real userland**, `netbsd:build`, carrying
  `uname`, `make`, `pkg_add` and `pkgin`. Its root filesystem is ext2, so it is
  grown from Linux with no BSD anywhere, and a compiler is installed at build
  time rather than left for a consumer to install and lose on the next `--rm`.
- ⭐ **A timing harness**, [`scripts/time-image`](scripts/time-image), which
  reports a median over several runs and ⛔ **says which accelerator actually
  ran** rather than which flag was passed.
- ⛔ **One measurement was withdrawn inside the same session.** The first runner
  numbers appeared to say acceleration made the boot slower. That run could not
  say which accelerator it used, so it is not published.
  [`docs/LIMITS.md`](docs/LIMITS.md) carries what is known and what is not.
- ⚠ **`INF-08` filed rather than fixed**: the shared console driver always
  returns the right answer late, and its twin has to move with it.

---

## 2026-08-27

### 2026-08-27T16:00:00Z: the limits are written down, and the backlog comes from them

**Record:** [`docs/LIMITS.md`](docs/LIMITS.md) is the account;
[`TODO/INDEX.md`](TODO/INDEX.md) carries the eight new entries filed from it.
**Deployed:** ⛔ **no deploy.** No image was published in this change.

⛔ **The largest defect in this project is that it works and nobody can use
it.** A route to a BSD shell needing nothing but a container engine is measured,
and no published image does it. Everything below follows from writing that down
honestly rather than from anybody's idea of what ought to be built.

- ⭐ **[`docs/LIMITS.md`](docs/LIMITS.md) now answers the five questions a
  consumer actually asks** about that route: how it works, whether it works
  anywhere else, whether the usual flags apply, whether it is better than a toy,
  and what real work costs. ⛔ **Three of the five answers are "no" or "not
  measured"**, and they are written that way.
- ⛔ **`-v`, `-p` and `-e` reach the container and stop there.** The guest is
  a virtual machine inside it. That gap was not documented before and is now
  `IMG-03`.
- ⛔ **A developer cannot install a compiler and build a BSD binary today.**
  The measured route boots a 20 MB rescue userland with no package manager, and
  it is NetBSD rather than FreeBSD. That is `IMG-02`, and it is P0.
- ⚠ **Every portability claim is an inference from one Windows laptop.**
  Native Linux, CI and macOS are all marked inferred rather than measured, and
  `PORT-01` is the one command per host that would fix it.
- ⭐ **Eight entries filed**, two of them P0, each carrying the measurement
  it came from and an acceptance command. [`TODO/PROGRESS.md`](TODO/PROGRESS.md)
  carries the order and the argument for it.
- ⭐ **`main` is protected**, with both gate jobs required, linear history,
  no force pushes and no deletions. ⚠ Administrator bypass is deliberately
  left on.

- ⛔ **Eleven more entries** after the operator set a bar: within **5 percent**
  of not using this project, measured over a real C, C++, Go and Rust build, two
  users side by side. ⛔ **A project that cannot meet its own bar publishes the
  ratio rather than dropping the bar.**
- ⛔ **`INF-04` through `INF-07`**, each closing a gap a consumer meets rather
  than a maintainer: no registry-free route for an air-gapped host, no CI that
  boots a guest, no resilience to an upstream changing its mind, and
  consumer-facing pages that read as a biography.
- ⚠ **`OPT-01` to `OPT-03`** are levers rather than goals: the allocator,
  a purpose-built emulator image, and whether a virtual machine is the right
  shape at all. ⛔ None is to be pulled before the measurement says which is
  stuck.
- ⭐ **Seven deep reviews**, each named for the reader it imagines, each
  ending with what it did **not** look at. Between them they found a cherry-picked
  boot time, a stale document contradicting its replacement, a tracked build
  artefact carrying absolute paths, three documents disagreeing about one count,
  and a project that cannot currently justify its own existence.
- ⭐ **Two more checks in the suite**, both from defects found in this
  session: no measured number in two documents, and the index agreeing with each
  entry about priority and effort.

⚠ **What did not change:** no code, no image, and no measurement was
retaken. This entry is the honest account of a tree that already existed.

### 2026-08-27T15:10:00Z: this repository became standalone, and a BSD boots in a container

**Record:** [`TODO/SUMMARY.md`](TODO/SUMMARY.md) is the brief;
[`docs/LIMITS.md`](docs/LIMITS.md) carries every measurement; `BSD-01` in
[`TODO/bsd.md`](TODO/bsd.md) carries the entry and its five corrections.
**Deployed:** ⛔ **no deploy.** No image was published in this change.

⚠ **`main` is one root commit from here.** Everything before it was development
history in another repository's shadow, and the split is the reason.
[`docs/vendored.md`](docs/vendored.md) records what was copied, from where, and
what changed on the way in.

- ⭐ **A BSD shell inside an unprivileged container in a couple of seconds**,
  with no acceleration, no `/dev/kvm`, no capabilities and no emulator on the
  host, because the emulator ships inside the image. ⛔ **The route is measured
  and not yet packaged**, which is the highest-value open task. The timing is in
  [`docs/LIMITS.md`](docs/LIMITS.md) and nowhere else.
- ⭐ **A full FreeBSD 15.1 userland on a Windows host's own hypervisor**,
  unelevated, with no nesting, and a container running inside it on `ocijail`.
- ⛔ **A long-running Go daemon panics that guest's kernel** in `_umtx_op`, so
  the podman client cannot reach it yet. Everything underneath that works.
- ⛔ **Eleven experiments**, each committed with its result, including the two
  that failed, the one that reported a false success, and an explanation that
  was published and withdrawn in the same session.
  ⚠ **Amended 2026-08-28**: it said nine, which was true when it was written.
  ⛔ **This bullet is not a historical claim, it is a live count**, checked
  against the tree by `tests/run.sh`, so it moves whenever an experiment is
  added. The tenth and eleventh belong to a later session and not to this one,
  and a live count living inside a dated entry is the defect underneath this
  note.
- ⭐ **The gate, the conventions, the methodology and the record are this
  repository's own**, adapted rather than fetched, so a clone reproduces every
  measurement with nothing else checked out.

⚠ **What is deliberately still missing**, and is in
[`docs/LIMITS.md`](docs/LIMITS.md) rather than hidden: no published image boots
itself, no Linux host was measured, no arm64 anything, and no steady-state
performance number exists for any route.
