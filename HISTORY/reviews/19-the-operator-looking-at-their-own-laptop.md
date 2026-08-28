# 19. The operator, looking at their own laptop

⛔ **The lens: the person who owns the machine, not the repository.** Every other
review here reads the tree. This one asks what running these sessions has done
to the hardware they run on, and whether the answer is now bounded.

⚠ **It exists because the operator asked**, on 2026-08-28: are agents leaving
background tasks and stray processes behind, and hogging disk. ⭐ **The answer
was measured, and it was half reassuring and half not.**

---

## 1. ⭐ What was actually found, on the machine, that day

| what | measured | verdict |
| --- | --- | --- |
| stray processes | one emulator, running, in flight, deliberate. No orphans from eight earlier runs | ⭐ **clean** |
| exited containers | **zero** | ⭐ **clean, and by construction**: every `podman run` in this repository passes `--rm` |
| volumes | four on the machine, **none** created by this project | ⭐ **clean.** Two belong to a sibling project |
| ⛔ **images** | ⛔ **435 images, 37.27 GB, 100 percent reclaimable** | ⛔ **not clean, and it is this project's** |

⛔ **The leak is `podman build`, which has no `--rm` to pass.** A 2.3 GB image
rebuilt ten times leaves ten discarded 2.3 GB trees, and nothing had ever pruned
in the life of the repository.

⭐ **19.07 GB was reclaimed**, 435 images down to 283, with every other project's
image and all four volumes untouched.

---

## 2. ⛔ The part that is easy to get wrong, and nearly was

⚠ **The obvious fix is `podman image prune`, and it would have been wrong.**
This machine runs at least two other projects: `localhost/archlinux:*` and a set
of `parity-fault*` images are still there, and two of the four volumes are named
for a sibling repository. ⛔ **A machine-wide prune from a project's own script
is a project taking a decision that is not its to take.**

⭐ **So attribution had to be proved rather than assumed**, and the first attempt
under-claimed badly: matching on labels and environment found 14.1 GB of 22.5,
because the `fetch` stage of the Containerfile is discarded before any label is
set. ⚠ **The layers were then READ**, and every remaining one carries, in its
build history, a URL this repository pins in
[`../../scripts/sources`](../../scripts/sources):

```text
https://smolbsd.org/assets/netbsd-SMOL
https://github.com/NetBSDfr/smolBSD/releases/download/latest/...
sh /grow-rootfs.sh rootfs.img ...
```

⭐ **That is proof of origin, and it is still narrower than a prune.** ⛔ The
lesson is the repository's own and it keeps recurring: when a number looks
incomplete, read the thing rather than loosen the test.

---

## 3. ⚠ What is still unbounded on this machine

⛔ **Named, because a review that reports only what was fixed is a report on
itself.**

| what | state | who owns it |
| --- | --- | --- |
| ⛔ **the guest's memory ceiling** | the podman machine has **2 GiB** and a build guest asks for 1 GB while a 2 GB disk image goes through page cache | ⚠ nobody. It has never been examined and it is a plausible confound under every number this project has taken on this laptop |
| ⛔ **18.2 GB still on the machine** | other projects' tagged images and the tagged images this project needs. ⭐ **Correctly left alone** | the operator |
| ⚠ the scratchpad | session logs and patch scripts outside the repository | the harness, not this repository |
| ⚠ **the podman machine itself** | 40 GB used of 1007 GB. ⭐ Not close to a limit today | the operator |
| ⛔ **a build that fails halfway** | leaves its layers behind exactly as a successful one does, and the reaper only runs at session end | ⚠ **unbounded within a session.** A session that builds five times carries five trees until it ends |

⭐ **The last row is the one worth acting on**, and the fix is not more tooling:
give every stage in [`../../images/netbsd/Containerfile`](../../images/netbsd/Containerfile)
the source label, so a mid-session reap can prove all of it rather than most.

---

## 4. ⭐ What the operator can now check without asking anybody

⛔ **The point of the change is that this stops being a question put to an
agent.**

```bash
sh scripts/common/reap.sh
```

⚠ **It reports and removes nothing.** It exits 1 when something is reclaimable
or when a guest of this project is still running, and it names what it found.
⭐ **`--apply` takes back only what it can prove is this project's**, and
`--force-stop` is the only way to stop a running guest, which has to be typed on
purpose.

---

## ⛔ What this review did NOT look at

- **Any machine but this one.** The whole audit is one Windows laptop with one
  podman machine, which is the same single-host limitation every number in this
  repository carries.
- **CPU or memory over time.** Only a point-in-time process list. ⚠ **A session
  that pins a core for an hour is invisible to this**, and this session did
  exactly that, deliberately.
- **What the harness leaves outside the repository.** Session logs, task output
  files and scratch scripts live in a temp directory this repository does not
  own and did not audit.
- **Whether 2 GiB of machine memory has skewed any published number.** ⛔ Named
  in section 3 as an unexamined confound and **not** investigated, because doing
  it properly means re-running measurements on a larger machine and there is
  only one machine.
- **The sibling projects' own leftovers.** Their images and volumes were
  identified only well enough to leave them alone.
