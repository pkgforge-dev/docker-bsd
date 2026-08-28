# 14. The skeptic again, now that clang cross-compiles for all three

⛔ **The lens: [`7-does-this-project-deserve-to-exist.md`](7-does-this-project-deserve-to-exist.md),
re-run against evidence it did not have.** That review asked why somebody with a
cross toolchain would switch. ⚠ **It could not answer, because nobody had
measured what the alternative costs.**

⭐ **The fourth sweep measured the alternative, in somebody else's repository,
and it is cheaper than this project assumed.** This review is the claim audit
that follows.

---

## 1. ⛔ The alternative, stated as precisely as the sweep supports

⭐ **A developer on Linux can cross-compile for FreeBSD, OpenBSD and NetBSD
with:**

| what | cost |
| --- | --- |
| the compiler | `apt install clang lld`. ⭐ **Two packages** |
| the sysroot | the BSD's own published `base` and `comp` sets, extracted |
| the glue | about seventy lines: `--target`, `--sysroot`, and a handful of `INPUT(...)` linker scripts |
| a BSD host | ⛔ **none** |
| a VM | ⛔ **none** |
| an emulator | ⛔ **none** |

⛔ **That is `PERF-02`'s user A, and it is not hypothetical**: `R29` implements
it, `R30` runs it on a free `ubuntu-latest` runner, and `R36` independently does
the same thing for FreeBSD's own kernel toolchain.

⚠ **All three read, none run here.** This review does not claim it works; it
claims three projects ship it.

---

## 2. ⛔ So what is left for this project? Three answers, and only two survive

### ⭐ Survives: running what you built

⛔ **A cross toolchain produces a binary and cannot execute it.** Every test
suite, every `configure` script that runs a compiled probe, every generated
tool that the build then invokes, needs a machine that runs BSD binaries.
⭐ **That is the gap, and it is the whole justification.**

⚠ **And the competition is real**: `R31` runs the binary in a full BSD VM on a
free runner, KVM-accelerated. ⛔ **This project's answer is an emulator in a
container with no privilege at all**, and the difference is privilege and
portability, not capability.

### ⭐ Survives: needing nothing from the host

⛔ **`R31` needs a runner that gives QEMU `/dev/kvm`.** This project needs a
container engine. ⚠ **On a free GitHub runner both are available**, so on the
target environment `RULES.md` names, this advantage is worth ⭐ **nothing**.
It is worth something on a machine where a nested VM is not available and a
container is.

### ⛔ Does NOT survive: "building for a BSD is hard"

⚠ **That was never written down here as a claim, and it was the unstated
premise under several entries.** ⛔ **It is false.** Building for a BSD from
Linux is two apt packages and a tarball. ⭐ **Running on a BSD is the hard
part**, and the entries should say so.

---

## 3. ⛔ Which published sentences this changes

| sentence | where | verdict |
| --- | --- | --- |
| "a developer with a cross toolchain still has no evidence to switch" | `PROGRESS.md` | ⭐ **stands, and is now sharper**: we know what their toolchain costs |
| "within 5 percent of not using us" | `TODO/performance.md` | ⚠ **the denominator is now known.** "Not using us" is `clang --target` on the runner, which has no VM overhead at all. ⛔ **A 5 percent gate against a native cross compile is a very hard gate** |
| "`PERF-02`: A cross-builds for the BSD on the host" | `TODO/performance.md` | ⭐ **now implementable.** It was an unspecified "cross toolchain" and it is now a named command |
| the four rows in `LIMITS.md` on why route 1 is a demonstration | `docs/LIMITS.md` | ⭐ **unchanged and still honest** |

⛔ **The second row is the uncomfortable one and it is the reason this review
exists.** ⚠ **`PERF-03`'s gate compares an emulated guest against a native
compile.** `LIMITS.md` already records that a free runner's container cannot use
`/dev/kvm`, so side B is interpreted and side A is native. ⭐ **Nothing in the
sweep makes that gate easier, and one thing makes it harder: the alternative got
cheaper.**

⚠ **This is not a recommendation to move the gate.** `RULES.md` decision 4 says
it does not close by publishing a worse ratio, and that is the operator's.
⛔ **It is a statement that the gate's difficulty is now quantified where before
it was assumed.**

---

## 4. ⭐ The one thing the sweep found that helps the ratio

⛔ **A free runner's QEMU can use KVM.** `R31` does it in production. ⚠ **This
repository measured that a ROOTLESS CONTAINER on a runner cannot open the
device**, which is a narrower fact and was published as the broader one until
today.

⭐ **So the single highest-value unknown for `PERF-03` is now specific**: can a
container on a free runner be given a usable `/dev/kvm`? ⛔ **If yes, side B
stops being interpreted and the gate becomes a different question entirely.**
⚠ `R17`'s `udev` rule is the nearest published answer and has not been tried
here.

---

## ⛔ What this review did NOT look at

- **Any number.** Nothing was compiled, timed or run. Every cost above is read
  from somebody else's repository.
- **Whether `ppkg`'s cross builds actually produce working BSD binaries.**
  `ppkg#17` says the tool does not verify its own `--static` claim, which is
  adjacent and not the same question.
- **Rust and Go**, which `PERF-02` names. The sweep's cross evidence is C and
  C++; `R32` is Rust-specific and its BSD targets have a standing defect list,
  which cuts the other way and was not pursued.
- **The consumer who is not a CI runner.** Everything here is about a free
  GitHub runner, because that is what `RULES.md` decision 2 names. A developer
  on a laptop has different constraints and this review ignored them.
- **`IMG-03`.** If nothing can get out of the guest, the whole comparison is
  academic, and that entry was not re-examined here.
