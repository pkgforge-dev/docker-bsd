# 10. Somebody who has to trust this session's instruments

⛔ **The lens: every conclusion this session published came out of a tool this
session wrote, on the same day, against a fault it did not understand.** That is
the worst possible provenance. This pass asks one question of each instrument:
**could it have produced this answer if the answer were false?**

⚠ It does **not** ask whether the conclusion is pleasing. Two of the four
instruments below were wrong and are recorded as wrong.

---

## 1. ⛔ The instrument that failed, and how it failed matters more than that it failed

[`../../experiments/42-probe-pkg-add-inside-guest.sh`](../../experiments/42-probe-pkg-add-inside-guest.sh)
sampled the guest by typing a command at its console every forty seconds.

⛔ **Its failure mode was indistinguishable from the fault it was measuring.**
A silent console over a busy emulator is exactly what `INF-09` looks like from
outside. The probe hung for ten minutes with one `ps` outstanding, and a reader
of that log would have concluded the guest was dead.

⭐ **What makes it a finding rather than an embarrassment**: the guest was not
dead. Killed and rerun with nothing typed at it, the same guest ran a driver
script to completion. ⛔ **So the instrument was manufacturing the symptom**, and
a session that had trusted it would have published "the guest hangs" over a
guest that answers.

⚠ **Filed as `INF-10`, not patched.** `console.py` is the single POSIX copy of
two measured tty rules and `tests/run.sh` asserts its twin carries the same two.

### ⛔ The defect class, named

**An instrument whose failure mode is the same shape as the fault is worse than
no instrument**, because no instrument at least reports nothing.

---

## 2. ⛔ The instrument that reported success over a command that never ran

The second version wrote a driver script into the guest, ran it once, and read
the record back. ⛔ **Two consecutive runs produced a pid, no output, no CPU and
no disk growth**, which is precisely what the fault produces.

⭐ **It was not the fault.** `os.environ.get("PROBE_CMD", default)` over a
variable the wrapper had set to the **empty string**: the name is present, so
the default never applies, and the driver came out holding `exec` with no
command. In `sh` that applies the redirections and returns 0.

⛔ **Nothing in the harness could tell those apart**, and that is the review
finding. Two fixes went in and both are guards rather than fixes:

- the driver file is **read back and printed** before it is run;
- the driver **confirms the process is running** with a `ps` twenty seconds in,
  because `$!` is a pid the shell hands out before anything has executed.

⚠ **Cost of not having them: two runs, about seventy minutes.**

---

## 3. ⭐ The instrument that survived, and why it was chosen

[`../../experiments/43-siginfo-the-stuck-guest.sh`](../../experiments/43-siginfo-the-stuck-guest.sh)
presses Ctrl-T and reads what the **kernel** prints.

⭐ **It is the only instrument here that does not need userland to be
scheduled**, which is the exact property the fault removes. And ⛔ **it proves
itself before it is trusted**: it presses Ctrl-T over a plain `sleep 30` on an
idle guest first, and says in the log whether SIGINFO answered at all.

```text
[  43.78] load: 0.04  cmd: sleep 2920 [nanoslp] 0.00u 0.01s 0% 1256k
```

⚠ **Without that self-test a later silence would mean nothing**, because a tty
with `nokerninfo` set answers Ctrl-T with nothing and looks identical to a
wedged kernel.

### ⚠ What this pass could NOT clear about it

⛔ **The two `tar` control runs answered Ctrl-T with a bell, not a status
line**, while the `pkg_add` run answered every time. ⚠ **That asymmetry is
unexplained and it is recorded rather than explained.** A bell is what the tty
emits on input-queue overflow, and the queue on this console is 1,024 bytes,
but nothing sent 1,024 bytes.

⭐ **It does not weaken the controls' conclusion**, which rests on whether the
extraction completed and not on the presses. ⛔ **It does mean the presses in
those two runs measured nothing**, and anybody reading those logs should know
that before quoting them.

---

## 4. ⭐ The conclusion, checked against the instrument that produced it

| the claim | the instrument | could it produce this if false |
| --- | --- | --- |
| `pkg_add` spins in the kernel and executes no userland | SIGINFO, self-tested | ⛔ **no.** `15.78u` frozen across 1,356 s is a kernel counter, not the process's own report |
| it is the filesystem, not `pkg_add` | plain `tar`, same bytes, same guest | ⛔ **no.** `tar` does no bookkeeping and does not finish either |
| it is the filesystem, not the guest | the same `tar` into a tmpfs | ⛔ **no.** Same kernel, same emulated CPU, same archive: it finished |
| it is not memory | a rerun with 3 GB, and the guest's own `top` | ⚠ **it could be weakened.** 2,881 MB free is the guest's view before the run, and no reading was taken **during** it |
| 1 KB blocks are the cause | ⛔ **nothing.** `dumpe2fs` establishes the geometry and nothing establishes causation | ⛔ **YES, trivially.** This is labelled as a narrowing and not a mechanism, and the control that would test it has not been run |

⛔ **The last row is the one to carry forward.** The entry says so, `PROGRESS.md`
says so, and a session that reads "it is the block size" as settled has read the
headline and not the caveat.

---

## ⛔ What this review did NOT look at

- **The `bench-compile` harness**, which produced the 27-second Linux figure.
  It was read and not run this session, and its guest side has never run at all.
- **`time-image`**, which produced every published boot number. Untouched here.
- **The gate's own checks**, other than the two changed. `check-twins` was run
  and its content not read.
- **Whether the emulated CPU makes any of this an artefact of TCG.** ⛔ Nothing
  here has run this workload accelerated, and a fault that only appears under
  interpretation would look exactly like this.
- **The Windows host itself.** Every number is from one laptop and one podman
  machine.
