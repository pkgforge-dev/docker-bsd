# 16. Somebody who pulled the build variant to compile something

⛔ **The lens: a developer who read the README's two-variant table, saw "a real
userland: `uname`, `make`, `pkg_add`, `pkgin`, a network, and a compiler package
staged inside it ready to install", and went to install it.** They are not
reading `TODO/`. They are reading the image.

⭐ **Everything below was found by running the image today**, not by reading it.
That matters here, because the sentence a consumer trusts is the one this
repository has been most wrong about.

---

## 1. ⛔ Three walls, in the order they hit them, and only one was documented

| what they do | what happens | documented? |
| --- | --- | --- |
| `pkg_add -U /guest-package.tgz`, the one thing the staged package is for | ⛔ **never returns.** No output, no error, no exit | ⭐ **yes**, in the README and in `docs/LIMITS.md`, and the reason given was wrong until today |
| work out that `tar` puts it in instead | ⭐ **works, in 46 seconds**, and `pkg_info` finds it afterwards | ⛔ **no.** Nothing anywhere told them this was possible |
| `gcc -O2 -c anything.c` | ⛔ **fails in under two seconds**: `sys/cdefs.h: No such file or directory` | ⛔ **NO. Nothing in this repository said the guest has no headers and no assembler** |

⛔ **The third wall is the finding of this review.** The image ships a package
manager, a network, `make`, and a staged compiler, and calls itself a real
userland. ⚠ **It cannot compile a C file even when the compiler installs
correctly**, because `/usr/bin/as` is not in it and neither is `/usr/include/sys`.

⭐ **Read out of the guest rather than inferred:**

```text
ls: /usr/bin/as: No such file or directory
ls: /usr/include/sys/cdefs.h: No such file or directory
ls: /usr/lib/libc.a: No such file or directory
```

---

## 2. ⛔ The gap was already written down, for a different reason, and nobody joined them

⚠ **`TODO/measurement.md` has carried this since the fourth reference sweep:**

> ⛔ **`comp` is not optional and this repository does not fetch it.**
> `scripts/sources` takes `base.tar.xz` and `etc.tar.xz` for NetBSD; the headers
> and static libraries a cross build needs are in **`comp`**.

⛔ **That was filed as a fact about a CROSS SYSROOT for `PERF-02`'s user A.** It
is the same set, the same missing files, and the same consequence inside the
guest, and the two were never connected because they live under different
entries. ⭐ **The reference sweep found the answer to a question nobody had asked
yet**, which is the strongest argument for the sweeps that this repository has
produced, and it took two sessions to land.

⚠ **The fix is measured now**: the set extracts into the guest in about a minute
and `as`, `sys/cdefs.h` and `libc.a` are all there afterwards. `INF-09` and
`IMG-02` carry it.

---

## 3. ⚠ What the consumer-facing pages should say, and what they say now

⛔ **Three sentences are now wrong or incomplete**, and none of them is wrong
because somebody was careless. Each was true when it was written.

| where | the sentence | the problem |
| --- | --- | --- |
| `README.md` | "a real userland: `uname`, `make`, `pkg_add`, `pkgin`, a network, and a compiler package staged inside it ready to install" | ⛔ **"ready to install" is doing a lot of work.** It installs and then cannot compile |
| `README.md` | "The compiler is staged, not installed. Installing it at build time was tried and does not finish" | ⚠ **true, and it now has a cause and a workaround**, and neither is here |
| `docs/LIMITS.md` | "the build variant has a package manager, a network and no compiler" | ⚠ **narrower than the truth.** It also has no assembler and no system headers, which is what actually stops a build |

⭐ **All three are amended in this change** rather than left for the next
session, because a consumer-facing page is the one place this repository has
said it will not carry a stale claim.

---

## 4. ⭐ What the image gets right, and it is worth saying

⛔ **A review that only finds faults is a review that was pointed at the faults.**

- ⭐ **The staged package is the right design.** Fetching 107 MB through the
  guest's emulated network was measured to be slower than every other build step
  put together; the file is written in from Linux with a version in its URL and a
  digest beside it. ⚠ **That decision survives all of today's corrections
  untouched.**
- ⭐ **`--network none` still reaches a shell.** Nothing is fetched at run time,
  and that is proved by a run rather than asserted.
- ⭐ **The guest reports its own accelerator**, so a consumer who hands in
  `/dev/kvm` and gets emulation anyway is told, in the image's own words.
- ⭐ **The root label design absorbed a change nobody planned for.** Attaching a
  second disk moves the root's device number from `ld0` to `ld2`, and nothing
  broke, because the kernel is told `root=NAME=buildroot` and finds its wedge by
  GPT label. ⚠ **That was a comment in `grow-rootfs.sh` about a trap; it turned
  out to be load bearing for a use nobody had in mind.**

---

## ⛔ What this review did NOT look at

- **The rescue variant.** It is published, it is what a consumer actually pulls
  today, and this lens is about the one that is not.
- **Whether the `comp` set's version is right.** The guest says
  `smolBSD 11.0_STABLE` and the set used is NetBSD 11.0, which matches what the
  guest reports and is **not** the 10.1 that `scripts/sources` pins for the OCI
  userlands. ⚠ **That skew is named in `IMG-02` and not resolved**, and a
  header set that is close enough to compile `sqlite3.c` is not evidence it is
  close enough for anything else.
- **Anything a consumer would hit after a successful compile.** Linking, running
  the result, getting it out of the guest: `IMG-03` owns all of it and none was
  exercised.
- **The size cost.** The `comp` set is 86 MB compressed and this review did not
  ask what it does to a 2.3 GB image or whether `OPT-02` should care.
- **Whether `pkgin` works.** The image ships it, the guest has a user-mode
  network, and nothing here has ever run it. ⚠ If it uses the same code path as
  `pkg_add`, it is stuck too, and that is a guess rather than a measurement.
