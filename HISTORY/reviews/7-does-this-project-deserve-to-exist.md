# Review 7: does this project deserve to exist

⭐ **The lens.** A skeptic who already has a way to build for a BSD: a cross
toolchain on their Linux box, or somebody else's project. They are not asking
whether this works. They are asking **why they would switch.**

⛔ **It is the review most likely to be answered with enthusiasm instead of
evidence**, so it is written as a list of what is not known.

**Run** 2026-08-27.

---

## ⛔ What it found

### 1. ⛔ The project cannot currently answer its own justification

| the question | what this repository knows |
| --- | --- |
| is it faster than a cross toolchain | ⛔ **nothing.** No build of any kind has been timed |
| is it faster than the alternatives | ⛔ nothing. No other project has been benchmarked |
| does it cost more memory | ⛔ nothing |
| does it scale to a real source tree | ⛔ nothing |

⭐ **Every published number is time-to-a-prompt.** That is a real measurement
of a real thing, and it is not the thing a developer is choosing on.

⚠ **A boot time is a good headline and a bad argument.** Filed as `PERF-02` and
`PERF-03`, with an explicit bar rather than an aspiration, because a bar somebody
wrote down can be failed and an aspiration cannot.

### 2. ⛔ The honest answer today is that it does not deserve to exist yet, and that is fine

⚠ **On the evidence in this repository, a developer with a working cross
toolchain has no reason to switch.** What this project has is a property the
alternatives do not: ⭐ **it needs nothing from the host.** No toolchain to
install, no target to configure, no BSD machine, no privilege.

⛔ **That property is worth something only if the tax is small.** `PERF-03` sets
the tax at 5 percent and says what happens if it cannot be met: the number gets
published anyway.

### 3. ⚠ The comparison targets are named nowhere

`PERF-02` compares against a cross toolchain. ⛔ **It does not name which one**,
and "a cross toolchain" is several very different things. ⚠ A comparison whose
baseline is unnamed is not reproducible, and this one is the project's own
justification.

---

## ⭐ What it checked and found sound

| | |
| --- | --- |
| is the weakness admitted in consumer-facing docs | ⭐ yes. `docs/LIMITS.md` says it is a demonstration and not a development environment |
| is there a bar, written down | ⭐ yes, 5 percent, in `PERF-03` |
| does failing the bar have a defined outcome | ⭐ yes: publish the ratio and what was tried |
| are the optimisation levers identified before being pulled | ⭐ yes, and deliberately ranked below the measurement that says which one is stuck |

---

## ⛔ What this review did NOT look at

- ⛔ **It measured nothing.** It is an argument about what is missing, which is
  the weakest kind of review in this directory and the reason `PERF-02` exists.
- **It did not survey the alternatives.** "Somebody else's project" is a
  placeholder; nobody has listed who they are or what they cost.
- ⚠ **It did not question the 5 percent.** The operator set it; nothing here
  establishes that 5 is the right number rather than 2 or 20, and a bar nobody
  can hit is as useless as no bar.
