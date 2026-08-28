# INF-09, in its original wording

⭐ **The record of one entry that has published a confident explanation nine
times.** ⛔ Append, never edit. Each section below is the wording that was live
on a page in this repository, kept verbatim, with the measurement that
withdrew it written underneath.

⚠ **The entry itself is [`../TODO/infrastructure.md`](../TODO/infrastructure.md)
and it carries what is true now.** [`../docs/conventions/prose.md`](../docs/conventions/prose.md)
says a live page is amended in place and the superseded wording moves here, so
this file is the only place the old sentences exist.

---

## 1. ⛔ Withdrawn 2026-08-28: "It is the filesystem, and it is neither `pkg_add` nor the guest"

⭐ **The most confident thing this entry ever published**, and it stood for one
session. It was the headline of `TODO/SUMMARY.md`, `TODO/PROGRESS.md`,
`docs/LIMITS.md` and `experiments/README.md` at the same time.

### The wording, as it stood

> ⛔ **Writing half a gigabyte into the guest's root filesystem does not finish,
> whatever writes it.** Two controls are the whole answer, run with the same
> bytes, in the same image, minutes apart, by
> `experiments/43-siginfo-the-stuck-guest.sh`:
>
> | the same 490 MB, the same 1,664 files, the same guest | result |
> | --- | --- |
> | `tar xpf /guest-package.tgz -C /var/tmp`, onto the **ext2 root** | ⛔ **still running after 900 s** |
> | the same `tar`, into a **tmpfs** mounted inside that guest | ⭐ **finished**, and said so |
>
> ⭐ **So `pkg_add` is exonerated**: plain `tar` does not finish either.
> ⭐ **And the guest is exonerated**: the same `tar`, the same bytes, the same
> emulated CPU, finishes when the destination is not that filesystem.

And, under the eight dead explanations:

> | ⚠ **it is `pkg_add`'s bookkeeping after the files are written** | ⛔ **no.** Plain `tar`, which does no bookkeeping at all, does not finish either |

And in `docs/LIMITS.md`:

> ⭐ **So it is the filesystem, not the writer and not the emulator.** The guest
> root is ext2 with **1 KB blocks over 2 GB and no features at all**, because
> this repository grows a small published image with `resize2fs`, which cannot
> change a block size.

### ⛔ What withdrew it

**The `tar` control does not reproduce.** Run again on 2026-08-28, on the same
`localhost/netbsd:build`, whose root filesystem `dumpe2fs` confirms is the same
one (2,096,108 blocks of 1,024 bytes, 522,240 inodes, no features):

| how it was run | the same `tar`, onto the same ext2 root |
| --- | --- |
| `experiments/45-is-it-the-root.sh`, through the plain driver | ⭐ **finished. 35 s by the guest's own clock** |
| `experiments/43-siginfo-the-stuck-guest.sh`, the instrument that took the original reading, with `PROBE_CMD` set to that `tar` | ⭐ **finished**, and the shell was back at a prompt before the second Ctrl-T |

⛔ **So the first link in the chain is broken, and everything hanging off it
goes with it.** `pkg_add` was exonerated *because* plain `tar` was said to
behave the same way. It does not.

⚠ **What is NOT claimed here.** That the original reading was misread. Nobody
can say from this distance what was different about the machine that day, and
the console log it came from was not kept. ⛔ **What is claimed is only that it
does not reproduce**, on the same image, with the same command, through two
different instruments.

⭐ **And the last of the eight dead explanations is alive again.** `pkg_add`'s
own work, after or during the write, is back in the frame, because the control
that killed it is the control that will not reproduce.

---

## 2. ⛔ Withdrawn 2026-08-28: the 1 KB block size is the lever

### The wording, as it stood

> ⛔ **1 KB blocks over a 2 GB filesystem, with no features at all.** No
> `dir_index`, no `extent`, no `sparse_super`. 256 block groups. Writing 490 MB
> means allocating roughly **half a million individual 1 KB blocks**, and every
> directory lookup is a linear scan.

⚠ **That paragraph is still true as a description of the filesystem**, and it
was published as the reason the write did not finish. That half is what is
withdrawn.

### ⛔ What withdrew it

`experiments/44-block-size-control.sh`. Two scratch disks made by the same
`mke2fs` in the same container, both 2 GB, both `-O none`, both `-i 4096`, and
**one `-b` apart**. One freshly booted guest each, so neither is charged for the
other's page cache. Same archive, same `tar`:

```text
RESULT case=4k finished=yes      32 s
RESULT case=1k finished=yes      35 s
```

⛔ **A fresh 1 KB filesystem with the shipped root's geometry finishes in the
same time as a 4 KB one.** `mke2fs -b 4096` would have "worked", would have been
shipped, and would have been the ninth explanation this entry published without
understanding.

⚠ **`experiments/45-is-it-the-root.sh` then removed the remaining differences
one at a time** and none of them mattered either: the shipped root's own bytes
`dd` out of the image and mounted as an ordinary data disk finished in 34 s, and
so did the same disk with the archive copied onto it first so that one
filesystem carried both the read and the write.

---

## 3. ⚠ Kept, and still standing: what the kernel said

⭐ **The SIGINFO reading is the one thing in this entry that has survived every
correction, and it reproduced exactly.** 2026-08-28, `pkg_add -U
/guest-package.tgz`, Ctrl-T every 45 seconds:

```text
t=48    load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u   23.86s 77% 13348k
t=96    load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u   72.32s 77% 13348k
t=144   load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u  120.76s 77% 13348k
```

Against the reading taken the first time, at the same intervals:

```text
t=48    load: 0.41  cmd: pkg_add 2899   15.78u    26.88s 74% 13348k
t=290   load: 0.41  cmd: pkg_add 2899   15.78u   269.22s 74% 13348k
t=871   load: 0.41  cmd: pkg_add 2899   15.78u   832.29s 74% 13348k
t=1404  load: 0.41  cmd: pkg_add 2899   15.78u  1382.68s 74% 13348k
```

⛔ **The same signature, to the resident size.** User time frozen, system time
climbing one second per second of wall clock, RSS never moving off 13,348 KB.

⭐ **So the fault is real, it reproduces, and it belongs to `pkg_add`.** What
changed is only which of the two writers it belongs to.

---

## 4. ⚠ The instruments, and what each of them cost

- ⛔ **A control run once is not a control.** Both of this entry's original
  controls were single runs, and the one that carried the argument is the one
  that did not reproduce. ⚠ The rule this repository already had, that a result is a
  median over several runs and never a single one, was written for a benchmark on
  a shared runner and applies here exactly as hard.
- ⛔ **Silence on a console is not evidence of a wedged guest.** Ctrl-T over an
  idle shell prints nothing, because `sh` ignores SIGINFO and there is no
  foreground job to report on. ⚠ A run that finished and a run that stopped
  being scheduled look identical through that instrument unless the command
  carries its own completion marker. `experiments/45-is-it-the-root.sh` uses the
  marker-bracketed driver for exactly this reason.
- ⛔ **An instrument that cannot say "it finished" can only say "it is still
  running", and it will say that either way.** That is the shape of the reading
  that was withdrawn above.
