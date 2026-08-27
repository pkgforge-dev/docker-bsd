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
entries         total 2  open 1  blocked 0  done 1
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

**1. `BSD-01`, the only open entry, and the goal it was written around is met.**
⛔ **What is left is its acceptance command, not its purpose.**

Its `Prove` clause names one command:

```bash
podman -c freebsd run --rm IMAGE /bin/sh -c 'uname -sr'
```

⚠ **Everything underneath that command works.** A key installed over the serial
console, the empty-password ssh door closed before any port is forwarded, the
port bound to loopback, ssh authenticating from Windows, and
`podman system connection add` returning 0.

⛔ **What stops it is a guest fault.** `podman system service`, a long-running
multithreaded Go daemon, panics the FreeBSD kernel in `_umtx_op`, which is what
Go's scheduler parks threads on. The stack, the conditions and the withdrawn
explanation are in [`bsd.md`](bsd.md).

⭐ **So the next question is not a command, it is:** can a multithreaded Go
daemon stay alive in a FreeBSD guest under the Windows hypervisor.
[`bsd.md`](bsd.md) lists what is untried.

**2. ⛔ Then read [`../docs/LIMITS.md`](../docs/LIMITS.md) and file from it.**
That document is the honest account of what this project cannot do yet, and it
is meant to shrink. ⚠ An entry filed from a measurement in it carries that
measurement; an entry filed from an opinion is how a backlog stops meaning
anything.

---

## Open questions for the operator

⛔ These block work. Each carries a recommendation, so agreeing costs nothing.

### 1. ⭐ Should this repository publish something bootable?

⭐ **Recommendation: yes, and the measurement now says so.** This repository
publishes a root filesystem, and for three of its four BSDs nothing exists that
can run one. ⛔ **A raw disk image with a stock kernel boots on an ordinary
Windows host with no installer**, which is what this session measured. Two
projects already distribute exactly that: `smolBSD` pushes a raw bootable disk
to a registry through `oras`, and `acj` publishes a kernel and a root filesystem
as release assets.

⚠ **It is a shape decision with a retention policy attached**, which is why it
is a question rather than a task.

### 2. ⚠ How many releases per BSD, and for how long?

Today it is one release per BSD, pinned in [`../scripts/sources`](../scripts/sources).
**Recommendation: keep one until the bootable question above is answered**,
because the answer changes what a release even is here.

### 3. ⚠ Architectures beyond `amd64`?

Today it is `amd64` only. ⛔ **The measured blocker is not the build**: FreeBSD
publishes `aarch64` and `riscv64` already. It is that arm64 CI runners have no
`/dev/kvm`, so nothing on them can boot what they build.
**Recommendation: not yet**, and revisit when there is a runner that can.
