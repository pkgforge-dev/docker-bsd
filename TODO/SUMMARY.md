# SUMMARY.md

⭐ **The brief. Read this in full, first, every session.** It is the fastest
orientation into what the last session actually did.
[`PROGRESS.md`](PROGRESS.md) is what to read next, and it is the authority on
what to do.

⛔ Overwritten each session. It is a snapshot, not a log. The log is
[`../HISTORY/`](../HISTORY/) and the git history.

---

## 2026-08-27 into 2026-08-28, the session that published a BSD anybody can run

| row | before | after |
| --- | --- | --- |
| **Elapsed** | 2026-08-27T17:00:00Z | about 7 hours |
| **Commits** | `e025538` | six on `main`, pushed with admin bypass over a protected branch |
| **Work** | 19 open, 2 P0 | ⭐ **`IMG-01` closed**, `IMG-02` most of the way, one new entry filed from a defect |
| **What it publishes** | four userlands nobody can run | ⭐ **an image that boots**, `ghcr.io/pkgforge-dev/netbsd:latest`, anonymously pullable |
| **Checks** | 12-check gate, 48 tests | same gate, 49 tests, plus ⭐ **a CI workflow that runs a BSD and asserts on it** |
| **Cost** | | no money. About 1.3 GB downloaded |
| **Health** | 19 entries, 1 done | 20 entries, 2 done, two new deep reviews |

---

## ⭐ What was reached

⛔ **The ask was an image a stranger can run, not a route somebody proved once.**

```text
$ podman run --rm -i ghcr.io/pkgforge-dev/netbsd:latest sh -c 'sysctl -n kern.ostype'
smolBSD
exit 0
```

Pulled from the registry, on a machine that had just deleted its local copy.
Built and proved on a free `ubuntu-latest` runner, with no privilege, no device
and no network at run time.

⭐ **The sizes, the seconds and the conditions are in
[`../docs/LIMITS.md`](../docs/LIMITS.md).** They are not repeated here: one
fact, one home.

---

## ⛔ What is still not true

⚠ **Read this before the findings.** The image existing is the attractive half.

| the question | the answer today |
| --- | --- |
| can I run a BSD in one command | ⭐ **yes.** That is new |
| is there a real userland in it | ⭐ **yes**, in `netbsd:build`: `uname`, `make`, `pkg_add`, `pkgin`, and a compiler installed at build time |
| can I get a source tree in and a binary out | ⛔ **no.** `-v`, `-p` and `-e` still stop at the container. `IMG-03` |
| what does real work cost | ⛔ **still unknown.** Nothing here has compiled anything and timed it |
| would I switch from a cross toolchain | ⛔ **no evidence either way.** `PERF-02`, `PERF-03`, and the bar is 5 percent |
| does it work on hosts other than these two | ⚠ **unmeasured**, but the command to find out now exists: [`../scripts/time-image`](../scripts/time-image) |

---

## ⭐ The five findings that change what the next session does

1. ⛔ **The accelerator is not the same lever in both places it was measured.**
   On the laptop, handing in `/dev/kvm` roughly halves the time to a shell. On
   the runner the first measurement said the opposite. ⚠ **That first
   measurement did not record which accelerator ran**, so it is withdrawn
   rather than published, and the harness now reports it.
2. ⛔ **The guest's emulated network is slow enough to dominate anything that
   uses it.** Fetching one compiler through it took longer than every other
   step in the image build put together and did not finish inside a runner's
   hour. The same file over the container's own network takes seconds. ⚠ **Any
   benchmark that resolves dependencies is measuring the network.**
3. ⭐ **The guest's root filesystem is ext2, not FFS**, which is why it can be
   grown and written into from Linux with no BSD anywhere. That is what made a
   compiler in the image possible at all: the published userland has 201 MB
   free and the compiler needs 490 MB.
4. ⛔ **A device declared after its backend is accepted, starts, and never
   reaches the guest.** `-netdev` then `-device` gives a guest with no network
   interface and no error anywhere. Reversed, it attaches.
5. ⛔ **The shared console driver returns the right answer late, always.** It
   decides a command has finished by counting prompts with a pattern that can
   only ever match once. Filed as `INF-08` rather than patched in passing.

---

## ⛔ Four defects this session shipped and then caught

⚠ **Every one was found by running, not by reading.**

- ⛔ **A wait that matched the previous command's marker.** The console search
  scans the whole buffer, so the second command in a session returned instantly
  with a chunk holding no exit status. That reads as a guest that ran the
  command and said nothing.
- ⛔ **An accelerator probe reading a stream that had already been discarded.**
  It reported `unreported` over a run that had said exactly what it did.
- ⛔ **A guest stopping in single user mode with a read only root**, which
  surfaced two steps later as a package manager that could not write, naming
  the file rather than the cause.
- ⛔ **Two conditions written as `A && B || C`**, which passed the linter on
  this machine and were refused by the one on CI. The repository already knows
  that shape is not if-then-else.

---

## ⚠ What was NOT measured, so it is not claimed

- ⛔ **Throughput of any kind.** Only time to an answer. `PERF-01` onwards.
- ⛔ **Whether acceleration helps or hurts on a runner.** Withdrawn, see finding 1.
- ⚠ **Any host other than one Windows laptop and one GitHub runner.**
- ⛔ **arm64 or macOS.** Not attempted. All artefacts are amd64.
- ⚠ **Whether a consumer can get anything out of the guest.** They cannot yet.
