# 17. Somebody deciding whether to fund another month

⛔ **The lens: [`7-does-this-project-deserve-to-exist.md`](7-does-this-project-deserve-to-exist.md)
and [`14-the-skeptic-again-now-that-clang-cross-compiles-for-all-three.md`](14-the-skeptic-again-now-that-clang-cross-compiles-for-all-three.md),
re-run now that the number exists.** Review 7 could not answer because nobody
had measured the alternative. Review 14 measured the alternative and could not
measure this project. ⭐ **Both halves are now on the table**, and this review
exists to say what they add up to before another month is spent.

⚠ **It is not a recommendation to stop.** It is the argument written down, so
the operator rules on evidence rather than on momentum.

---

## 1. ⛔ The two numbers, side by side

| | |
| --- | --- |
| **A**, the developer who does not use this project | `apt install clang lld`, a sysroot from the BSD's own sets, `clang --target=amd64-unknown-netbsd`. ⭐ **27 s** for `cc -O2 -c sqlite3.c` |
| **B**, this project's image, unaccelerated | ⛔ **did not finish in 3,600 s**, at 100 percent of a CPU |

⛔ **`PERF-03`'s gate is 5 percent.** The measured floor is more than **130x**
and the top was not reached. ⚠ **That is not a tuning problem.** `OPT-01` is an
allocator, `OPT-02` is a smaller emulator binary, `OPT-03` is a different
container runtime; those are percentage levers, and the gap is two orders of
magnitude.

⭐ **One lever has the right order of magnitude and it is the only one:
hardware acceleration.** `R31` runs BSD guests on free runners with KVM in
production, so the capability exists; this repository has measured that a
**rootless container** on a runner cannot open the device, which is a narrower
statement and an unanswered question rather than a closed door.

---

## 2. ⭐ What survives the number, and it is not nothing

⛔ **Two of this project's claims are untouched by the compile result**, because
they were never claims about speed.

- ⭐ **A BSD shell in 2.6 seconds with nothing but a container engine.** No
  privilege, no device, no host emulator, no `binfmt_misc`. That is shipped,
  published, anonymously pullable, and measured on two hosts. ⚠ **Nobody else in
  the 37-project sweep does it with no privilege at all.**
- ⭐ **Running a BSD binary at all.** A cross toolchain produces a binary and
  cannot execute it. Every `configure` probe, every generated tool a build then
  invokes, every test suite needs a machine that runs BSD code. ⛔ **That is the
  gap, and it is real.**

⚠ **But the second one is now damaged by the same number.** If a quarter of a
million lines does not compile in an hour, a test suite of any size is not going
to run in a job budget either. ⛔ **"You can run it" and "you can run it in
CI" are different products**, and only the first is currently demonstrated.

---

## 3. ⛔ The honest positions, and only one of them is dishonest

⚠ **Written as options for the operator rather than a conclusion**, because
`RULES.md` decision 4 is theirs and it says keep optimising.

| position | what it costs | what it claims |
| --- | --- | --- |
| ⭐ **answer the KVM question first** | one CI experiment, `R17`'s `udev` rule, days not weeks | ⛔ **nothing yet.** It is the only path that could move the ratio by two orders of magnitude, and it is unanswered rather than refuted |
| ⭐ **narrow the product to what is measured** | a documentation change | "a BSD shell anywhere a container runs, with no privilege". ⚠ True today, useful today, and much smaller than what `PERF-02` describes |
| ⚠ **keep the 5 percent gate and keep optimising** | ⛔ open-ended, against a two-order-of-magnitude gap with no lever of that size except one that is unanswered | that a fix exists. ⛔ **Not supported by anything measured** |
| ⛔ **publish a ratio and reposition** | nothing | ⛔ **refused already**, `RULES.md` decision 4, and this review does not reopen it |

⭐ **The first two are compatible and the third depends on the first.** ⛔ **The
sequencing is the recommendation**: answer the KVM question before spending
another session on any `OPT-*` lever, because if the answer is yes the levers
are aimed at the wrong layer, and if it is no then the gate needs the operator
rather than more engineering.

---

## 4. ⚠ What would change this review's mind, stated in advance

⭐ **So that the next session can falsify it rather than argue with it.**

- ⛔ **A container on a free runner opening `/dev/kvm`.** Then side B is
  virtualised rather than interpreted, and the whole calculation is re-run.
- ⚠ **The compile turning out to be STUCK rather than slow.** If its user time
  is frozen the way `pkg_add`'s is, the hour says nothing about emulation speed
  and this review's central number is measuring a bug instead of a cost. ⛔ **No
  SIGINFO reading was taken during it**, so this is genuinely open.
- ⚠ **A smaller real workload finishing.** A finite unaccelerated number, even a
  bad one, is worth more than a floor, because a ratio transfers and a floor
  does not.

---

## ⛔ What this review did NOT look at

- **Anything on an accelerated path.** Every number in it is unaccelerated,
  because that is the case a consumer with no device gets, and it is the only
  case this project has measured on a runner.
- **Rust and Go**, which `PERF-02` names. The compile evidence is one C file.
- **The consumer who is not a CI runner.** A developer on a laptop who wants a
  BSD shell for ten minutes is served well by what already ships, and this
  review is about the build story.
- **Whether the 27-second Linux figure is a fair side A.** It is Alpine's gcc
  compiling for Linux, not `clang --target` compiling for NetBSD, and those are
  not the same work. ⚠ **Side A as `PERF-02` defines it has never actually been
  run here**, which is a real hole in the comparison this review is built on.
- **Any cost other than time.** Image size, network, and the maintenance of a
  vendored guest are all real and none is examined.
