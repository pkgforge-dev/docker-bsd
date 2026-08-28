# SUMMARY.md

⭐ **The brief. Read this in full, first, every session.** It is the fastest
orientation into what the last session actually did.
[`PROGRESS.md`](PROGRESS.md) is what to read next, and it is the authority on
what to do.

⛔ Overwritten each session. It is a snapshot, not a log. The log is
[`../HISTORY/`](../HISTORY/) and the git history.

---

## 2026-08-28, the session that stopped guessing at `INF-09` and measured it

| row | before | after |
| --- | --- | --- |
| **Elapsed** | 2026-08-28T03:40:00Z | about 8 hours |
| **`INF-09`** | ⛔ six dead explanations, all inferred from outside the guest | ⭐ **answered.** Two controls, and a reading taken by the kernel |
| **Work** | 21 entries, 2 done | 22 entries, 2 done, one new defect filed |
| **`TODO/bsd.md`** | ⛔ 893 lines of corrections to corrections | ⭐ **155 lines of current facts**, with the reasoning moved verbatim to `HISTORY/` |
| **The 28-reference sweep** | ⛔ reachable only from a routing row nobody had reason to take | ⭐ **named, by section, from every `TODO/` file** |
| **Checks** | 12-check gate, 50 tests | same, and ⭐ **two guards tightened, both seen to fail** |
| **Experiments** | 9 | 11, one of them a committed negative result |

---

## ⭐ What was reached

⛔ **`pkg_add` was never the problem, and neither was the guest.** Two controls,
the same 490 MB, the same 1,664 files, in the same image, minutes apart:

```text
tar xpf /guest-package.tgz -C /var/tmp     onto the ext2 root   still running at 900 s
tar xpf /guest-package.tgz -C /mnt/t       into a tmpfs          TMPFS-EXTRACT-DONE
```

⭐ **It is the filesystem.** The guest root is ext2 with **1 KB blocks over
2 GB and no features at all**, because this repository grows a small published
image with `resize2fs`, and `resize2fs` cannot change a block size.

⭐ **The sizes, the seconds and the geometry are in
[`../docs/LIMITS.md`](../docs/LIMITS.md)** and the readings are in `INF-09`.
They are not repeated here: one fact, one home.

---

## ⭐ The five findings that change what the next session does

1. ⛔ **`ktrace` is not usable on this guest, and the binary is right there.**
   `ktrace(2)` is not compiled into the smolBSD kernel. ⚠ `INF-09`'s own
   approach section asked for a ktrace, so an entry can name an instrument that
   does not exist and nothing catches it. ⭐ **A tool being present is not an
   instrument being available.**
2. ⭐ **SIGINFO is the instrument for a guest whose userland has stopped**,
   because the kernel answers it. Ctrl-T over 1,404 seconds of `pkg_add`:
   **user time frozen at 15.78 s while system time climbed to 1,382 s**, and
   resident size never moved. ⛔ Not blocked on IO, not working in userland: in
   the kernel, burning a whole CPU, not coming back.
3. ⛔ **The guest's whole userland stops being scheduled, not just the writer.**
   A shell builtin `echo` produced nothing for 300 seconds, twice; thirty forked
   `sleep 30` calls took over 1,500 seconds of wall clock. ⚠ **Every instrument
   that is a program is unusable here**, which is why the first probe was
   starved out twice and is committed as a negative result.
4. ⛔ **It is not memory.** Rerun with three times the RAM and 2,881 MB free by
   the guest's own `top`: no output in 2,700 seconds. ⚠ The working set is about
   a gigabyte either way.
5. ⛔ **The 28-reference sweep in `HISTORY/references/` was never reachable from
   the work.** Every citation to it outside `HISTORY/` arrived in the first
   commit; exactly one later session drew on it. ⚠ **A session hand-wrote a
   provisioning mechanism that smolBSD already ships** as `smoler.sh`.

---

## ⛔ Four defects this session shipped and then caught

⚠ **Every one was found by running, not by reading.**

- ⛔ **A probe whose failure mode was the same shape as the fault.** It sampled
  by typing at the console, the guest stopped draining its input, and
  `Console.send()` blocked on the write with no timeout. Ten minutes, one `ps`
  outstanding, no output. Filed as `INF-10` rather than patched.
- ⛔ **`os.environ.get(name, default)` over a variable that is SET AND EMPTY.**
  The wrapper passed `-e PROBE_CMD=`, so the default never applied and the
  driver ran `exec` with no command, which in `sh` applies the redirections and
  returns 0. ⚠ **A run that forks a job, prints a pid, writes nothing and uses
  no CPU is indistinguishable from the frozen guest being investigated.**
- ⛔ **A driver that parsed and did not say what was meant.** Nothing read the
  file back. It does now, and the command is confirmed running before anything
  is believed.
- ⛔ **A guard with an exemption for the one file most likely to break it.**
  `tests/run.sh` excluded `TODO/bsd.md` from the measured-numbers check. The
  exemption is gone and the check was seen to fail with the number planted.

---

## ⚠ What was NOT measured, so it is not claimed

- ⛔ **Which loop inside NetBSD's `ext2fs` is spinning.** What is measured is
  that the destination filesystem decides the outcome, that all the time is
  kernel time, and what the geometry is. ⛔ **The mechanism is not read**, and
  this repository has twice published one invented to fit a number.
- ⛔ **That a 4 KB block size fixes it.** That is the next control and it has
  not been run.
- ⛔ **Throughput of anything.** The Linux side of the compile comparison is
  27 seconds and the guest side still needs a compiler in the image.
- ⚠ **Any host other than one Windows laptop and one GitHub runner.**
- ⛔ **arm64 or macOS.** Not attempted. All artefacts are amd64.
