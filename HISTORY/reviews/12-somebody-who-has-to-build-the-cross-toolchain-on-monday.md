# 12. Somebody who has to build the cross toolchain on Monday

⛔ **The lens: a person who has read the fourth sweep and now has to produce
`PERF-02`'s user A.** They are not asking whether the write-up is good. They are
asking whether they can act on it without re-cloning anything, which is the one
job [`../../docs/methodology/references.md`](../../docs/methodology/references.md)
gives the `usable.md` half.

⚠ **This pass tests the write-up, not the references.**

---

## 1. ⭐ Can they start? Walk the commands and find what is missing

The `R29` section claims a cross toolchain in two apt packages and a sysroot
from published sets. ⛔ **Walking it as a stranger, four things are underspecified
and one is wrong by omission.**

| step | can they act | what is missing |
| --- | --- | --- |
| `apt install clang lld` | ⭐ yes | nothing |
| fetch `base.txz` / `base`+`comp` | ⭐ yes, the URLs are literal | ⚠ **`$SYSROOT` is never defined.** It is an obvious variable and it is still undefined |
| the `INPUT(...)` stubs | ⭐ yes, verbatim | ⛔ **they are written into `$SYSROOT/usr/lib` for OpenBSD and into an unstated path for FreeBSD.** `ppkg` writes FreeBSD's into the sysroot AND a per-package `lib/` dir; the write-up shows only one |
| the `.so` symlink loop | ⭐ yes | ⚠ it is shown for OpenBSD only. `ppkg` runs it for OpenBSD only too, so this is faithful, but a reader may assume NetBSD needs it and it is not said either way |
| `--target=amd64-unknown-freebsd` | ⚠ **partially** | ⛔ **`ppkg` normalises `x86_64` to `amd64` for the BSDs and the write-up does not say so.** A reader who writes `x86_64-unknown-freebsd` gets a triple clang may not resolve against that sysroot |

⛔ **The last row is the one that would cost a morning.** It is recorded here
rather than fixed in the write-up, because fixing it means asserting a triple
nobody here has run, and this repository does not publish unrun commands.

### ⚠ And one thing the write-up cannot tell them

⛔ **Nothing in this sweep was executed.** The provenance section says so, and
the `usable.md` half opens by saying so. ⭐ **That is honest and it is still a
gap**: a reader acting on it is running these commands for the first time, and
the first person to do so should record what actually happened.

---

## 2. ⛔ The claim most likely to be wrong, and how it would fail

⭐ **"`comp` is not optional and this repository does not fetch it."**

⚠ **The second half is verified**: `scripts/sources` fetches `base.tar.xz` and
`etc.tar.xz` for NetBSD, and nothing else. Read directly.

⛔ **The first half is inference from two references agreeing**, not a
measurement. `R29` fetches `base` and `comp`; `R32` fetches `base` and `comp`.
Neither says what breaks without `comp`. ⭐ **Two independent projects doing the
same thing is good evidence and it is not the same as a failure observed here.**

⚠ **How it would fail if wrong**: a session adds `comp` to `scripts/sources`,
the images grow, and nothing else changes, because the images this repository
publishes are **userland tarballs for consumers**, not sysroots for a cross
build. ⛔ **`comp` belongs in whatever builds user A, which may not be this
repository at all.**

---

## 3. ⭐ The mechanism most worth stealing, tested against our own code

`wrapper-target-cc.c` rewrites an absolute `/path/libfoo.so` to `.a` **and
`stat`s it before committing to the rewrite**.

⛔ **This repository has the same shape of bug available to it right now.**
`images/netbsd/grow-rootfs.sh` writes files into the guest with `debugfs` and
then reads them back with `debugfs -R stat`, checking for `Inode:`, precisely
because `debugfs` exits 0 on failure. ⭐ **Same discipline, arrived at
independently, and the sweep confirms it rather than teaching it.**

⚠ **Where we do NOT do it**: `scripts/bench-compile` hardcodes
`GUEST_CC="/usr/pkg/gcc14/bin/gcc"` and does not check the path exists before
timing. ⛔ **A missing compiler exits non-zero in well under a second**, and the
script does guard on `rc=0` before recording a sample, with a comment saying
exactly that. ⭐ **So it is already handled**, and this pass confirms it rather
than finding a hole.

---

## 4. ⚠ A claim in the write-up that overreaches, corrected here

⛔ **The `R30` section says "Two apt packages is the whole cross toolchain."**

⚠ **That is true for what `ppkg` builds and it is not a general statement.**
`clang` and `lld` give you a compiler and a linker; the sysroot is a separate
fetch, and `ppkg` also needs `bsdtar`, `curl` and its own 11,916-line driver to
assemble the thing. ⭐ **The honest version is "two apt packages is the whole
COMPILER"**, and the write-up should not be read as promising more.

⚠ **Left as a finding rather than an edit**, because the sentence is accurate in
its own paragraph, which is about what the `cross` job installs.

---

## ⛔ What this review did NOT look at

- **Whether any of these commands work.** Nothing was run. This is a read of a
  write-up against its own sources.
- **`ppkg`'s formula repository**, which is where the per-package build logic
  lives and which was not cloned at all.
- **The C branch of `ppkg`**, which the README says is a parallel
  implementation. Only `master` was read.
- **Whether `ppkg` itself builds on this Windows laptop.** It is POSIX shell and
  the laptop has Git Bash; that is an assumption, not a test.
- **`R36`'s downstream repositories.** `nextbsd-kernel` and
  `nextbsd-freebsd-compat` are named in its workflows and were not fetched.
- **Licence compatibility of anything.** Not one licence file was read for
  suitability, only noted where the README stated it.
