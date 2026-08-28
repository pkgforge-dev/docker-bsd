# TODO: infrastructure

⭐ **What turns this from a repository that works into one that keeps working
without anybody watching it.**

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.

⚠ **The model is `pkgforge-dev/docker-archlinux`**, which publishes provenance,
an SBOM and a per-platform evidence file, and has three freshness workflows that
open a pull request rather than waking somebody up. ⛔ **It is the floor, not
the ceiling.**

---

## INF-01. Every published image carries provenance and an evidence file

**Source** Derived from the sibling repository's practice, 2026-08-27.
**Category** infrastructure · **Priority** P2 · **Effort** M · **Status** open

### Problem

⛔ **A consumer cannot currently tell what is inside a published image or where
it came from.** [`../README.md`](../README.md) already admits the weaker half of
this: the digest check proves integrity, not provenance, because the checksum
file comes from the same host as the artefact.

### Approach

⭐ **Three things, and the third is the one nobody else ships.**

1. a build provenance attestation and an SBOM on every image;
2. ⭐ **an evidence file per platform**: every component, its version, its size,
   its digest and where it was fetched from, published as a release asset;
3. ⛔ **the guest artefacts in that evidence too.** An image that carries an
   emulator, a kernel and a root filesystem has three supply chains, and listing
   only the container's packages would be an evidence file that lies by omission.

⚠ **Signature verification of the upstream userlands is a separate step up** and
is not this entry. Say so rather than implying the attestation covers it.

### Prove

```bash
podman run --rm IMAGE cat /usr/share/docker-bsd/evidence.json
```

⛔ Exit 0, and the digests in it match what the image actually contains, checked
by a test rather than by reading.

---

## INF-02. Upstream moving is noticed by a bot, not by a person

**Source** Derived from the sibling repository's practice, 2026-08-27.
**Category** infrastructure · **Priority** P2 · **Effort** S · **Status** open

### Problem

⚠ **Every artefact this repository depends on lives somewhere else**: four BSD
userlands, an emulator, a guest kernel and a guest root filesystem. ⛔ When one
moves, the first thing that notices today is a failing build or, worse, a
consumer.

⭐ **CI already checks that the URLs resolve** on every run, and that is the
weakest useful version: it catches a 404 and misses a new release.

### Approach

⭐ **A scheduled workflow per upstream class**, each opening a **pull request**
with the change and the evidence, never pushing.

| what | how often | what the pull request carries |
| --- | --- | --- |
| a new BSD release | weekly | the new version, its digest, and the diff to [`../scripts/sources`](../scripts/sources) |
| a new guest kernel or root filesystem | weekly | the same, plus a boot that succeeded |
| the emulator's version in the image | monthly | the new pin |

⛔ **A pull request that only says "a new version exists" is noise.** It carries
the evidence that the new version still boots, produced by running
[`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh)
against it.

### Prove

⛔ Each workflow fires once, on a real schedule, and the run id is recorded. ⚠ A
workflow that has never fired is a workflow nobody knows works, and
[`../docs/methodology/gate.md`](../docs/methodology/gate.md) has a rule about
guards never seen to fail.

---

## INF-03. A test that is seen to fail

**Source** Derived from the sibling repository's `tests-seen-to-fail.md`, 2026-08-27.
**Category** infrastructure · **Priority** P2 · **Effort** S · **Status** open

### Problem

⛔ **This repository has 46 assertions and no record of any of them refusing
anything.** A guard whose test has never been seen to fail is theatre, and
[`../docs/conventions/forbidden-patterns.md`](../docs/conventions/forbidden-patterns.md)
has a row saying exactly that.

⚠ **Three of them HAVE been seen to fail**, during the session that wrote them:
the count check, the one-fact-one-home check and the experiment-header check
each refused a real defect. ⛔ **That is not written down anywhere.**

### Approach

⭐ A `HISTORY/tests-seen-to-fail.md`, one row per assertion, each carrying the
defect that was planted or found and the output it produced when it refused.

⛔ **Plant the defect and read the exit code, unpiped.** An assertion that
cannot be made to fail is either unreachable or tautological, and either way it
is not a test.

### Prove

Every assertion in `tests/run.sh` has a row. ⚠ **An assertion with no row is
either untested or unfalsifiable**, and the entry does not close while any
remain.

---

## INF-04. Publish the artefacts themselves, not only images

**Source** The operator, 2026-08-27.
**Category** infrastructure · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **A registry is not reachable from every machine that wants a BSD.** An
air-gapped host, a build farm behind a proxy, and anyone who prefers a file to a
pull all need the artefact rather than the image.

⚠ **And a registry tag is not an archive.** It moves, it can be deleted,
and it carries no changelog a person can read.

### Approach

⭐ **Every release carries the pieces, not just a pointer to them.**

| artefact | for |
| --- | --- |
| the root filesystems | anybody assembling their own image |
| the bootable disk images and ISOs | a hypervisor, a laptop, a machine with no container engine |
| ⭐ the container images as files | an air-gapped host, loaded with `podman load` |
| the guest kernel | the microvm route, without the registry |

⛔ **Each with a checksum file and each listed in the release body**, with
what changed since the previous release and what it was built from.

⚠ **A release with a bare file list is not a release.** The description is
the part a consumer reads before deciding to trust it.

### Prove

```bash
curl -fsSLO RELEASE_ASSET_URL && sha256sum -c CHECKSUM_FILE
```

⛔ Exit 0, read unpiped, on a machine that has never talked to the registry.

---

## INF-05. CI that tests the permutations, and publishes only when all of them pass

**Source** The operator, 2026-08-27.
**Category** infrastructure · **Priority** P1 · **Effort** L · **Status** open

### Problem

⚠ **CI today is a static gate on two hosts.** It proves the repository is
coherent. ⛔ **It proves nothing about the thing the repository exists to
ship**, because nothing runs a guest.

### Approach

⭐ **A matrix over the axes that actually vary**, and every cell reports.

| axis | values |
| --- | --- |
| host | Linux, Windows, macOS |
| architecture | `x86_64`, and arm64 as a known-failing row until it is not |
| acceleration | with a device, and without |
| engine | podman, docker |
| guest | each BSD this project publishes |

⛔ **Publishing is gated on the whole matrix**, the way a sibling project
gates on every architecture: a run that loses one cell publishes nothing at all,
rather than publishing a partial set nobody can tell is partial.

⚠ **A cell that cannot run says so and is counted as skipped**, never as
passed. A matrix that quietly drops a cell is a matrix that shrinks.

⭐ **And the boot experiment is the test.**
[`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh)
already prints a machine-readable result line, so CI runs the same thing a
developer runs rather than a second implementation of it.

### Prove

One run, green, with every cell either passed or explicitly skipped with a
reason, ⛔ and a deliberate failure in one cell shown to block the publish.

---

## INF-06. Survive an upstream changing its mind

**Source** The operator, 2026-08-27.
**Category** infrastructure · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **Everything this project consumes belongs to somebody else**: four BSD
userlands, an emulator, a guest kernel and a guest root filesystem. Any of them
can rename a directory, retire a release, change a compression, or serve
something that is not what it says it is.

⚠ **This is not hypothetical.** A sibling project records being served five
different broken shapes for one file: zero bytes, the wrong compression, an
error page, a truncated archive, and nothing at all.

### Approach

⭐ **Three properties, in order of how much they buy.**

1. ⛔ **Fail loudly rather than proceed on garbage.** A fetch that returns an
   error page must not be imported as a root filesystem. Verify what arrived is
   the shape expected, not just that the transfer exited 0.
2. **Pin, and know when the pin is stale.** `INF-02` is the bot half.
3. ⭐ **Step over a broken source and record that it was broken.** Where
   there is more than one mirror, try the next one and report which failed, so
   the outage is visible rather than silently absorbed.

⛔ **And test it with the broken shapes, not with a happy path.** Feed the
scripts a zero-byte file, an HTML error page, a truncated archive and a wrong
digest, and assert each is refused. ⚠ A resilience claim with no fault
injection behind it is an assumption.

### Prove

A test that feeds each broken shape to the fetch path and asserts a non-zero
exit and an actionable message, ⛔ each one seen to fail, recorded per
`INF-03`.

---

## INF-07. The consumer-facing documents read like a manual

**Source** The operator, 2026-08-27.
**Category** infrastructure · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **The documents a consumer reads first carry this project's biography.**
Which explanation was withdrawn, which experiment failed first, what a previous
session believed. ⚠ **That is genuinely valuable and it is in the wrong
place**: it belongs to [`../HISTORY/`](../HISTORY/README.md), which exists for
exactly it.

⚠ **A reader deciding whether to use this should not have to read how it
was built.** Length reads as uncertainty, and a document that argues with itself
in front of a stranger is not a manual.

### Approach

⭐ **Two audiences, two registers, one set of facts.**

| document | register |
| --- | --- |
| [`../README.md`](../README.md) | what it is, what to run, what it costs. ⛔ No narrative |
| [`../docs/LIMITS.md`](../docs/LIMITS.md) | tables of what works and what does not, with conditions. ⛔ No story about how each was found |
| [`../HISTORY/`](../HISTORY/README.md) | ⭐ **all of it**, in full, in its original wording |

⛔ **Moved, never deleted.** A withdrawn claim is one of the most useful
things this repository owns, and the rule that it keeps its wording does not
change; where it lives does.

⚠ **And "up to date" is the harder half.** A manual that is wrong is worse
than one that is long, so anything moved must leave a link behind, and the
one-fact-one-home check must still pass.

### Prove

⛔ A consumer-facing page contains no sentence about what a previous session
believed, and every such sentence is reachable from
[`../HISTORY/README.md`](../HISTORY/README.md). ⚠ Checked by reading, not by
a script: no check can recognise "this sentence is a memoir".

---

## INF-08. The shared console driver returns the right answer late

**Source** Reproduced 2026-08-27 while building the `IMG-01` image, which reads
a command's output back out of a guest's serial console.
**Category** infrastructure · **Priority** P1 · **Effort** S · **Status** open

### Problem

⛔ **`Console.run()` in [`../experiments/lib/console.py`](../experiments/lib/console.py)
always burns its whole timeout.** It decides a command has finished by waiting
for one more prompt than there was before it typed, and it counts prompts with
a pattern anchored by a dollar sign. Python matches that anchor at the end of
the string only, so the count is 0 or 1 and never rises. "One more than before"
is never true.

```bash
python -c "import re; t='out\n# '; print(len(re.compile(r'# $').findall(t+'x\n# ')))"
```

⛔ **It answers 1, and it answers 1 after the command as well.** The output is
collected correctly and returned, so every caller gets the right answer after
the full budget rather than a wrong one. That is why nothing noticed.

### What it cost, measured

⚠ [`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh)
runs five commands at 90 seconds each. Nothing it published is wrong: the boot
time comes from `wait_for`, which is sound. ⛔ **The image built for `IMG-01`
could not use `run()` at all**, because a consumer's `podman run` cannot take
fifteen minutes to print one line, and that is what made this visible.

### Approach

⚠ **The twin has to move with it.** `console.ps1` is the other half and
`tests/run.sh` asserts both carry the same two measured tty rules.

1. count prompts with a pattern that can match more than once, or track a
   position in the stream rather than a count;
2. ⛔ **plant the defect first.** A test that types one command and asserts it
   returns in well under the timeout, seen to fail against today's code;
3. check whether `console.ps1` has the same defect, and say so either way.

⭐ **The image does not wait for this.** `images/netbsd/guest.py` brackets the
command with two markers the echo cannot contain and waits for the second one,
which is a better completion signal than a prompt count and is why that file
uses `send` and `wait_for` directly.

### Prove

```bash
sh experiments/35-boot-in-container.sh
```

⛔ Exit 0, and the whole run finishes in a time that is not a multiple of the
per-command timeout.

---

## INF-09. Provisioning the guest costs more than everything else in the build

**Source** Measured 2026-08-28 while building the image `IMG-02` needs.
**Category** infrastructure · **Priority** P2 · **Effort** M · **Status** open

### ⭐ FOUND 2026-08-28. It is the filesystem, and it is neither `pkg_add` nor the guest

⛔ **Writing half a gigabyte into the guest's root filesystem does not finish,
whatever writes it.** Two controls are the whole answer, run with the same
bytes, in the same image, minutes apart, by
[`../experiments/43-siginfo-the-stuck-guest.sh`](../experiments/43-siginfo-the-stuck-guest.sh):

| the same 490 MB, the same 1,664 files, the same guest | result |
| --- | --- |
| `tar xpf /guest-package.tgz -C /var/tmp`, onto the **ext2 root** | ⛔ **still running after 900 s** |
| the same `tar`, into a **tmpfs** mounted inside that guest | ⭐ **finished**, and said so |

⭐ **So `pkg_add` is exonerated**: plain `tar` does not finish either.
⭐ **And the guest is exonerated**: the same `tar`, the same bytes, the same
emulated CPU, finishes when the destination is not that filesystem.

### ⛔ What the kernel says, which is the question no earlier reading could ask

⛔ **`ktrace` cannot be used on this guest at all.** The binary is in the
userland and the syscall is not in the kernel:

```text
ktrace: ktrace(2) system call not supported in the running kernel;
        re-compile kernel with `options KTRACE'
```

⚠ This entry's approach section asked for a ktrace, and it was never available.
⛔ **A tool being present is not an instrument being available**, and nothing
outside the guest could have told the difference.

⭐ **SIGINFO is answered by the KERNEL and needs no userland at all**, which is
what makes it the right instrument here: this guest's userland stops being
scheduled. Ctrl-T every 45 seconds, over 1,404 seconds of `pkg_add`:

```text
t=48    load: 0.41  cmd: pkg_add 2899   15.78u    26.88s 74% 13348k
t=290   load: 0.41  cmd: pkg_add 2899   15.78u   269.22s 74% 13348k
t=871   load: 0.41  cmd: pkg_add 2899   15.78u   832.29s 74% 13348k
t=1404  load: 0.41  cmd: pkg_add 2899   15.78u  1382.68s 74% 13348k
```

⛔ **Read the two numbers. User time is FROZEN at 15.78 seconds and system time
climbs one for one with the wall clock.** Over 1,356 seconds the process
executed **not one userland instruction**, and its resident size never moved off
13,348 KB.

⭐ **That answers "spinning or waiting", and it is neither of the two things
every guess assumed.** It is not blocked on IO, which would show almost no CPU.
It is not working in userland, which would move `15.78u`. ⛔ **It is inside the
kernel, burning a whole CPU, and not coming back.**

### ⛔ The filesystem it is grinding on, read rather than assumed

`dumpe2fs` on the image this repository ships, from Linux, 2026-08-28:

```text
Filesystem features:      (none)
Block count:              2096108
Block size:               1024
Blocks per group:         8192
Inode count:              522240
```

⛔ **1 KB blocks over a 2 GB filesystem, with no features at all.** No
`dir_index`, no `extent`, no `sparse_super`. 256 block groups. Writing 490 MB
means allocating roughly **half a million individual 1 KB blocks**, and every
directory lookup is a linear scan.

⭐ **This repository made that filesystem.**
[`../images/netbsd/grow-rootfs.sh`](../images/netbsd/grow-rootfs.sh) grows the
published image with `resize2fs`, and ⛔ **`resize2fs` cannot change a block
size.** 1 KB blocks are a reasonable choice for the small image upstream
publishes. Grown to 2 GB and filled with a compiler, they are not.

⚠ **Written as the narrowing it is, not as a proven mechanism.** What is
measured: the destination filesystem decides whether the write finishes, all of
the time is kernel time, and this filesystem has that geometry. ⛔ **Which loop
inside NetBSD's `ext2fs` is spinning has NOT been read**, and this repository
has twice published a tidy mechanism invented to fit a number. The next step is
the control in the approach, not a theory.

### ⭐ CORRECTED 2026-08-28 BY READING UPSTREAM. The ext2 is a build-host fallback

⛔ **The section above says "this repository made that filesystem" and that is
only half true.** The fourth reference sweep re-mined smolBSD at `0824f4ee04fc`
and found the choice made in upstream's own `mkimg.sh`, lines 155 to 167:

```text
if [ -n "$is_linux" ]; then
	# no other image than builder image are ext2, don't check for FROMIMG
	mke2fs -O none ${vnd}
	mountfs="ext2fs"
elif [ -n "$is_freebsd" ]; then
	newfs -o time -O1 -m0 /dev/${mountdev}
	mountfs="ffs"
else # NetBSD
	newfs -O1 -m0 /dev/${mountdev}
	mountfs="ffs"
```

⭐ **Three facts, and they change the fix:**

1. ⛔ **ext2 is what smolBSD falls back to when the BUILD HOST is Linux**,
   because a Linux host cannot `newfs` an FFS. It is not a decision about the
   guest. On a NetBSD or FreeBSD build host the same script produces **FFS**.
2. ⛔ **The comment says only the BUILDER image is ext2.** This repository
   ships `build-amd64.img`, which is that builder image, as its runtime root.
3. ⛔ **`mke2fs -O none` is literally "no features"**, which is exactly what
   `dumpe2fs` reported here. ⭐ **The filesystem this entry is stuck on is
   generated at that line**, and the 1 KB block size follows from `mke2fs`
   defaults on a small image.

⚠ **Upstream has met ext2 trouble of its own**: `mkimg.sh:319` carries the
comment `unionfs with ext2 leads to i/o error`.

⭐ **And upstream provisions with a chroot, not a booted guest.**
`smoler/build.sh:245` turns a `RUN` line into
`chroot . su ${USER} -c "cd ${WORKDIR} && ..."`, inside a script that refuses to
run outside the builder image. ⛔ **This repository types at a serial console
instead**, which is the mechanism this entry is about.

⛔ **So the question is no longer "what block size".** It is "why is the builder
image the runtime root at all".
[`../HISTORY/references/usable.md`](../HISTORY/references/usable.md), the `R34`
section, has the lines.

---

### ⛔ EIGHT EXPLANATIONS, ALL DEAD, KEPT BECAUSE EACH COST A DIFFERENT FIX

⚠ **This entry was first written with a confident explanation and it was
wrong.** Each guess was cheap to test and each would have sent the fix somewhere
different.

| the guess | the measurement that killed it |
| --- | --- |
| it is fetching over the emulated network | ⛔ **no.** The package is written into the guest's filesystem from Linux before it boots, and the stage has no network at all |
| the emulated disk is slow | ⛔ **no.** The guest writes 100 MB in 2.5 seconds |
| ⚠ it is tens of thousands of small files | ⛔ **no, and this was the confident one.** The package holds **1,664** files |
| it is the xz decode, which is expensive per byte | ⛔ **no.** Decoding the whole 107 MB package inside the guest takes **17 seconds** |
| `/tmp` is a 32 MB tmpfs and `pkg_add` stages there | ⛔ **no.** `TMPDIR=/var/tmp pkg_add -U` behaved exactly the same. ⚠ The full `/tmp` is real and is a real trap for a consumer, and it is not this |
| it is `-U` | ⛔ **no.** Dropping it gave no output and no exit inside twelve minutes |
| ⚠ **it is memory pressure**, because the guest has 1 GB and no swap | ⛔ **no.** Rerun with three times the memory, so **2,881 MB free** by the guest's own `top`: no output in 2,700 seconds. ⭐ The emulator's resident size stopped at about 1 GB either way, so the working set is a gigabyte and having three makes no difference |
| ⚠ **it is `pkg_add`'s bookkeeping after the files are written** | ⛔ **no.** Plain `tar`, which does no bookkeeping at all, does not finish either |

⭐ **What found it was a control, not a theory**: run the same write against a
different filesystem in the same guest, and see which one finishes.

### ⚠ Two things measured on the way that belong to other entries

- ⛔ **The guest's whole userland stops being scheduled**, not just the writer.
  A shell builtin `echo` produced nothing for 300 seconds, twice, and thirty
  forked `sleep 30` calls took more than 1,500 seconds of wall clock. ⚠ That is
  why no instrument that is a program can be used here: not `ps`, not `top`,
  not `vmstat`, not a driver script and not a `kill`. It is also why
  [`../experiments/42-probe-pkg-add-inside-guest.sh`](../experiments/42-probe-pkg-add-inside-guest.sh)
  could not get its own record out of the guest twice in a row.
- ⛔ **`Console.send()` blocks forever against such a guest**, which is `INF-10`.
  The tty's input queue is 1,024 bytes, the guest stops draining it, and the
  write never returns.

### Approach

⭐ **The fix follows from the control rather than from a theory.** In order of
what is cheapest to prove:

0. ⛔ **Ask first whether the builder image should be the runtime root at all.**
   Upstream ships `rescue-amd64.img` and `build-amd64.img` and treats the second
   as a **build environment**, not a product. ⭐ **The cheapest possible fix is
   to stop shipping it as one**, and it costs no filesystem work.
1. ⭐ **Make the filesystem instead of growing it.** The guest root is ext2 and
   Linux owns it completely: `debugfs -R rdump` the published tree out,
   `mke2fs -b 4096 -d` a new one at the size wanted, and write the package in
   from Linux. ⛔ **No guest, no emulator, and no provisioning step at all**,
   which is what [`PROGRESS.md`](PROGRESS.md) already said this entry should
   reach.
2. ⚠ **Prove the block size is the lever before rebuilding anything**, by
   repeating the two controls against a 4 KB filesystem. ⛔ A fix that works and
   is not understood is the ninth guess.
3. ⭐ **Or produce FFS rather than ext2**, which is what upstream does on a BSD
   build host. ⚠ **That needs a BSD to run `newfs`**, and [`RULES.md`](RULES.md)
   says none exists here, so it would have to happen inside this project's own
   guest. ⛔ Recorded as the option it is, not recommended.
4. ⚠ **Read what upstream already provides before writing any of them.**
   [`../HISTORY/references/usable.md`](../HISTORY/references/usable.md), the
   `R34` section. ⛔ **This repository hand-rolled a serial-console provisioner
   without looking at `smoler/build.sh`**, whose tracker holds 83 items and 51
   threads of which two have been read.

⛔ **And do not leave the trap in place for a consumer.** Somebody who boots the
build variant and unpacks anything large meets exactly this, with the same
silence, and `pkg_add` is not required to reproduce it.

### Prove

```bash
sh experiments/43-siginfo-the-stuck-guest.sh localhost/netbsd:build
```

⛔ The command that does not finish today must finish, with `gcc --version`
answering afterwards and `pkg_info` listing what is installed, inside a runner's
job budget.

## INF-10. `Console.send()` blocks forever on a guest that stopped reading

**Source** Measured 2026-08-28 by
[`../experiments/42-probe-pkg-add-inside-guest.sh`](../experiments/42-probe-pkg-add-inside-guest.sh),
whose first version wedged on it.
**Category** infrastructure · **Priority** P1 · **Effort** S · **Status** open

### Problem

⛔ **`Console.send()` in [`../experiments/lib/console.py`](../experiments/lib/console.py)
writes to the guest's stdin with no timeout and no way out.** Every other
primitive in that file is bounded: `pump`, `wait_for` and `wait_for_prompt` all
take a budget and return `False`. ⛔ **The one that writes takes none.**

```python
self.proc.stdin.write(ch.encode())
self.proc.stdin.flush()
```

⚠ **That is fine against a guest that is reading its console**, which is every
guest this repository had driven until now. ⛔ **It is not fine against a guest
that has stopped.** The emulator stops draining its own stdin, the pipe fills,
and the `write` blocks in the kernel. No timeout in the caller applies, because
the caller never gets back to check one.

### What it cost, measured

⛔ **Ten minutes with one `ps` outstanding, and no output of any kind.**
2026-08-28: a probe sampling the guest's process table every forty seconds
while `pkg_add` ran got its first sample away and then blocked on the second
one. ⚠ **The symptom is indistinguishable from the thing being investigated**:
a silent console over a busy emulator, which is exactly what `INF-09` looks
like from outside. ⛔ **An instrument whose failure mode is the same shape as
the fault is worse than no instrument.**

⭐ **The guest was not dead.** Killed and rerun with nothing typed at it, the
same guest ran a driver script to completion and printed its record.

### Approach

⛔ **Not patched in passing, for the same reason as `INF-08`.** That file is
this repository's single copy of two measured tty rules, and
`tests/run.sh` asserts its twin `console.ps1` carries the same ones, so a
change to one is a change to both.

1. ⛔ **plant the defect first.** A test that fills the pipe and asserts `send`
   returns rather than hanging, seen to fail against today's code;
2. give `send` a budget and a return value, the way `wait_for` has one. ⚠ A
   partially typed line is a real state and the caller has to be told, not left
   to assume the line arrived;
3. ⛔ **check `console.ps1` and say so either way.** The same shape on the
   PowerShell side is a `StandardInput.Write` with the same absence.

⚠ **`INF-08` is in the same file and the two should move together.** One is a
read that returns late, this is a write that never returns, and both are the
same missing idea: a bound.

### Prove

```bash
sh experiments/42-probe-pkg-add-inside-guest.sh localhost/netbsd:build
```

⛔ Runs to its own end, and a test that fills the guest's input pipe returns a
failure rather than hanging.
