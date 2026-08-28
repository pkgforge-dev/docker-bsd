# SUMMARY.md

⭐ **The brief. Read this in full, first, every session.** It is the fastest
orientation into what the last session actually did.
[`PROGRESS.md`](PROGRESS.md) is what to read next, and it is the authority on
what to do.

⛔ Overwritten each session. It is a snapshot, not a log. The log is
[`../HISTORY/`](../HISTORY/) and the git history.

---

## 2026-08-28: repeated one control, and it took the answer away

| row | before | after |
| --- | --- | --- |
| **`INF-09`** | ⭐ "answered": the destination filesystem decides | ⛔ **withdrawn.** Five destinations, all finish. `pkg_add` is the only suspect left |
| **the 1 KB block size** | ⭐ the lever, and a rebuild was the next task | ⛔ **not the lever.** One `mke2fs -b` apart, both finish |
| **a compiler in the guest** | ⛔ blocked on `pkg_add` | ⭐ **installs in 46 seconds with `tar`**, and `pkg_info` finds it |
| **compiling in the guest** | ⚠ assumed to follow | ⛔ **it does not.** No `as`, no `sys/cdefs.h`, no `libc.a`, and with all three in place the compile still **did not finish in an hour** |
| **the machine** | ⚠ nobody had looked | ⛔ **37.27 GB of this project's own layers.** ⭐ 19.07 GB reclaimed, a rule and a command added |
| **Work** | 22 entries, 2 done | ⭐ **23 entries, 4 done**, one new defect filed |
| **Experiments** | 11 | 15 |
| **The machine** | ⛔ 37.27 GB of this project's layers | ⭐ **18.2 GB**, and a command that keeps it that way |
| **Reviews** | 14 | ⭐ **19** |
| **Corrections published about itself** | four | ⛔ **five**, and the fifth is a correction to the fourth |

---

## ⛔ What was reached, and it is the opposite of a headline

⛔ **The previous session's answer rested on one run of one control**, and this
one repeated it. The same `tar`, the same archive, the same image, through the
plain driver and through the instrument that took the original reading:

```text
tar xpf /guest-package.tgz -C /var/tmp    onto the ext2 root    finished
```

⛔ **That is the run the record says had not finished after 900 seconds.**
Five destinations were tried in the end: the real root, a fresh 1 KB
filesystem, a fresh 4 KB one, the shipped root's own bytes as a data disk, and
the same with the archive copied on first. **Every one of them finished.**

⭐ **So the eighth dead explanation is alive: it is `pkg_add`'s own work.** It
reproduces every time, with the same signature the first reading took: user time
frozen, system time climbing one second per second, resident size never moving.

⭐ **And `pkg_add -v` says where it stops.** It prints every path in the package,
reaches the last one alphabetically, and then says nothing for the rest of the
run. ⛔ **The unpack finishes; the phase after it does not.**

---

## ⭐ The six findings that change what the next session does

1. ⭐ **A compiler goes into the guest in 46 seconds without `pkg_add`**, and
   `pkg_info -e` finds it afterwards. A pkgsrc binary package is an archive with
   `@cwd /usr/pkg` in its own `+CONTENTS` and nine `@ignore` metadata files that
   belong in `/var/db/pkg/<pkgname>/`. ⛔ **`IMG-02` is assembly now, not
   research.**
2. ⛔ **And the guest still cannot compile, for a reason nobody had looked for.**
   No `/usr/bin/as`, no `/usr/include/sys/cdefs.h`, no `/usr/lib/libc.a`. ⭐ The
   `comp` set puts all three in, in about a minute. ⚠ **That gap was already
   written down** under `PERF-01`, for a cross sysroot, and nobody had connected
   it to the guest.
3. ⛔ **AND WITH ALL OF IT IN PLACE, THE COMPILE DID NOT FINISH IN AN HOUR.**
   `cc -O2 -c sqlite3.c` against 27 s on Linux: 3,600 seconds at 100 percent of
   a CPU, no result. ⚠ **A floor of more than 130x with the top not reached**,
   and `PERF-03`'s gate is 5 percent. ⛔ **This is the number that decides what
   the project is**, and it points at one question: can a container on a free
   runner be given a usable `/dev/kvm`?
4. ⛔ **The block size was one commit from being "fixed" without being
   understood.** A fresh 1 KB filesystem with the shipped root's geometry takes
   the archive in the same time a 4 KB one does, so the rebuild would have
   worked, shipped, and been the tenth explanation.
5. ⭐ **`INF-08` and `INF-10` are closed, and the two halves had different
   answers.** The PowerShell console driver never had `INF-08`, because its
   default prompt is unanchored; it had `INF-10` in full. ⛔ **A suite that ran
   only the language the defect was filed against would have declared the pair
   fixed.**
6. ⛔ **Silence at a console is not a wedged guest.** Ctrl-T over an idle shell
   prints nothing, so a command that finished and a command that stopped being
   scheduled are the same picture unless the command carries its own completion
   marker. ⚠ That is how a run that finished can be recorded as one that did
   not.

---

## ⚠ What was NOT measured, so it is not claimed

- ⛔ **What was different on the day the 900-second reading was taken.** The
  console log was not kept and nobody can say from here. ⚠ **What is claimed is
  only that it does not reproduce**, on the same image, with the same command,
  through two instruments.
- ⛔ **Which loop inside the kernel `pkg_add` is in after the unpack.**
  `ktrace(2)` is not in this kernel and `pkg_install`'s source has not been read.
- ⛔ **Whether `pkgin` is stuck too.** It ships in the image, it has never been
  run, and assuming it shares `pkg_add`'s fate is a guess.
- ⛔ **Whether the guest's compile would EVER have finished.** No SIGINFO
  reading was taken during it, so "slow" and "stuck like `pkg_add`" are not
  separated. ⚠ That is the first thing the next session should settle, and it
  costs one Ctrl-T.
- ⚠ **Whether NetBSD 11.0's `comp` set is right for a guest that reports
  `smolBSD 11.0_STABLE`.** It compiles, which is not the same as being correct,
  and `scripts/sources` pins 10.1 for a different purpose.
- ⚠ **Any host other than one Windows laptop and one GitHub runner.**
- ⛔ **arm64 or macOS.** Not attempted. All artefacts are amd64.
