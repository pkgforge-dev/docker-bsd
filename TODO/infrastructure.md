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
**Category** infrastructure · **Priority** P1 · **Effort** S · **Status** done

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

### Closed 2026-08-28

**What changed.** `Console.wait_for_prompt` takes a **position in the stream**
instead of a prompt count, and `run()` passes it the length of the buffer from
before the command was typed. ⭐ The prompt the command was typed at begins
before that position and cannot match; the one the guest prints afterwards
does. ⛔ **No count, no baseline, and nothing that depends on how many times a
pattern is allowed to match.**

⚠ **A second, smaller defect in the same function was found by the test and
fixed with it.** `run()` compared each line against the prompt pattern *after*
`rstrip()`, which removes the prompt's trailing space, so a `# $` pattern
stopped matching its own prompt and a bare `#` was returned as a line of output
the guest never printed. ⛔ **`console.ps1` already allowed for it, with
`# ?$`**, and this side did not: that is exactly the twin drift the pair exists
to prevent.

**The defect was planted first**, per the entry's own approach.
[`../tests/console-bounds.py`](../tests/console-bounds.py) drives the real
driver against a fake guest that answers like a tty, and against today's code it
said:

```text
  FAIL run() did not see the command finish at all
  FAIL run() returned ['#'], expected ['GUEST-ANSWERED']
```

After the fix, on the same test:

```text
  ok   run() returned in 0.2s of a 30s budget
  ok   run() returned exactly what the guest printed: ['GUEST-ANSWERED']
```

⭐ **The twin was checked, and the entry asked for that either way.**
`console.ps1` **did not have this defect**, and the reason is worth keeping: its
default prompt, `root@[^\r\n]*# `, is not anchored, so its prompt count could
rise. ⚠ **A caller passing an anchored pattern would have met it exactly**, so
both halves track a position now and
[`../tests/console-bounds.ps1`](../tests/console-bounds.ps1) asserts it on that
side too.

⛔ **Both tests run in `tests/run.sh`**, and a host that cannot run one reports
it as a SKIP rather than counting it as a pass.

---

## INF-09. Provisioning the guest costs more than everything else in the build

**Source** Measured 2026-08-28 while building the image `IMG-02` needs.
**Category** infrastructure · **Priority** P2 · **Effort** M · **Status** open

### ⛔ WHERE IT STANDS, 2026-08-28. `pkg_add` does not finish. Plain `tar` does

⭐ **Five destinations, the same 490 MB archive, the same guest, one freshly
booted guest each. Every one of them finished.** The seconds are in
[`../docs/LIMITS.md`](../docs/LIMITS.md) and in no other file.

| what the same `tar xpf /guest-package.tgz` was pointed at | |
| --- | --- |
| the guest's own ext2 root, at `/var/tmp` | ⭐ **finished** |
| a fresh 2 GB ext2, `-O none`, **1 KB blocks**, on a second disk | ⭐ **finished** |
| the same, **4 KB blocks**, one `mke2fs` argument apart | ⭐ **finished** |
| the shipped root's own bytes, `dd` out of the image and mounted as data | ⭐ **finished** |
| the same, with the archive copied onto it first so one filesystem carries both the read and the write | ⭐ **finished** |

⛔ **And `pkg_add -U` on that same archive, into that same root, does not.**
It reproduces exactly, every time, with the signature below.

⭐ **So the answer is the eighth explanation in the table further down, the one
this entry had already killed and buried**: it is `pkg_add`'s own work, and not
the filesystem, not the block size, not the emulator and not the guest.

⛔ **The control that killed that explanation does not reproduce.** It said
plain `tar` onto the ext2 root was still running after 900 s. Run again today
through two different instruments, including the one that took the original
reading, it finishes in about half a minute. ⚠ **Nobody can say from here what
was different that day**, and the console log was not kept. The withdrawn
wording, and what withdrew it, is in [`../HISTORY/inf-09.md`](../HISTORY/inf-09.md).

### ⛔ What the kernel says, and this is the reading that has survived everything

⛔ **`ktrace` cannot be used on this guest at all.** The binary is in the
userland and the syscall is not in the kernel:

```text
ktrace: ktrace(2) system call not supported in the running kernel;
        re-compile kernel with `options KTRACE'
```

⚠ This entry's approach section once asked for a ktrace, and it was never
available. ⛔ **A tool being present is not an instrument being available**, and
nothing outside the guest could have told the difference.

⭐ **SIGINFO is answered by the KERNEL and needs no userland at all.** Ctrl-T at
`pkg_add`, on 2026-08-28, every 45 seconds:

```text
t=48    load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u   23.86s 77% 13348k
t=96    load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u   72.32s 77% 13348k
t=144   load: 0.46  cmd: pkg_add 2899 [0x7f7ff728888a/0]  18.45u  120.76s 77% 13348k
```

⛔ **Read the two numbers. User time is FROZEN at 18.45 seconds and system time
climbs one for one with the wall clock**, and the resident size never moves off
13,348 KB. ⭐ **The same signature, to the kilobyte, as the first reading this
entry ever took**, which ran to 1,404 seconds and is kept in
[`../HISTORY/inf-09.md`](../HISTORY/inf-09.md).

⭐ **That answers "spinning or waiting".** It is not blocked on IO, which would
show almost no CPU. It is not working in userland, which would move `18.45u`.
⛔ **It is inside the kernel, burning a whole CPU, and not coming back.**

⚠ **And a healthy run looks completely different through the same instrument.**
The `tar` that finishes reported `14.26u 14.04s` at t=33, both numbers moving,
and printed its own SIGINFO progress line beside the kernel's.

### ⭐ And `pkg_add -v` says WHERE it stops, which is the first positive reading this entry has

⛔ **The unpack finishes. What comes after it does not.** `pkg_add -v -U` on the
same package prints every path in it, in order, and reaches the last one:

```text
gcc14/share/gcc-14.3.0/python/libstdcxx/v6/xmethods.py
```

⛔ **And then nothing, for the remaining 380 seconds of the run**, while the
kernel answers every Ctrl-T with the same frozen user time:

```text
t=63    17.19u   40.40s 76% 13356k
t=252   17.19u  229.63s 76% 13356k
t=441   17.19u  355.77s 76% 13356k
```

⭐ **That is the narrowest statement this entry has ever been able to make**, and
it is a reading rather than a theory: **`pkg_add` unpacks the whole package and
stops in the phase after the unpack.** ⚠ Which phase, and which loop in the
kernel, is still not read.

### ⛔ The filesystem, read rather than assumed

`dumpe2fs` on the image this repository ships, from Linux, 2026-08-28:

```text
Filesystem features:      (none)
Filesystem state:         clean
Block count:              2096108
Block size:               1024
Blocks per group:         8192
Inode count:              522240
```

⛔ **1 KB blocks over a 2 GB filesystem, with no features at all.** No
`dir_index`, no `extent`, no `sparse_super`. 256 block groups.

⚠ **That is a description of the filesystem and it is NOT the fault.** It was
published as the fault and
[`../experiments/44-block-size-control.sh`](../experiments/44-block-size-control.sh)
withdrew it: a fresh filesystem with that geometry takes the archive in the
same time a 4 KB one does. ⭐ **`mke2fs -b 4096` would have worked, would have
been shipped, and would have been the ninth explanation published without being
understood.**

### ⭐ Upstream's own source, which says how the filesystem got that shape

⛔ **Still true, and it no longer explains anything about this fault.** The
fourth reference sweep re-mined smolBSD at `0824f4ee04fc` and found the choice
made in `mkimg.sh`, lines 155 to 167:

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

⭐ **Two facts worth keeping:** ext2 is what smolBSD falls back to when the
BUILD HOST is Linux, and upstream treats `build-amd64.img` as a build
environment rather than a product. ⚠ **The ext2 is also what makes this
repository's build work at all**: an FFS root could not be grown, written into
or inspected from Linux, and every step in
[`../images/netbsd/grow-rootfs.sh`](../images/netbsd/grow-rootfs.sh) depends on
being able to do exactly that.

⭐ **And upstream provisions with a chroot, not a booted guest.**
`smoler/build.sh:245` turns a `RUN` line into
`chroot . su ${USER} -c "cd ${WORKDIR} && ..."`, inside a script that refuses to
run outside the builder image. ⛔ **That chroot runs BSD binaries and so it
needs a BSD host**, which [`RULES.md`](RULES.md) says does not exist here.
⚠ It is not a route this project can take; it is evidence that upstream does not
type at a serial console either.

### ⭐ ANSWERED: should `build-amd64.img` be the runtime root at all? Yes, for now

⛔ **[`PROGRESS.md`](PROGRESS.md) asked this first because it was the fix that
cost no filesystem work.** The answer is that there is nothing to fix on that
axis:

1. ⭐ **The filesystem is exonerated by four controls.** The reason to stop
   shipping the builder image was that its filesystem could not take a large
   write. It can.
2. ⛔ **Upstream publishes two images and the other one is a rescue userland**
   of about 20 MB, with no package manager and no toolchain. Swapping to it
   loses everything `IMG-02` exists for.
3. ⚠ **Building a third from NetBSD's own sets is a real option and it is not
   this entry's.** [`../scripts/sources`](../scripts/sources) pins NetBSD 10.1
   sets while the guest kernel is smolBSD 11.0_STABLE, so it carries a version
   skew nobody has measured, and it is `IMG-02` sized work.

⚠ **Recorded as answered rather than closed**, because the question was worth
asking and the reason it is a "no" changed completely once the controls ran.

### ⛔ NINE EXPLANATIONS, AND THE NINTH IS THAT ONE OF THEM WAS WRONGLY BURIED

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
| ⛔ **it is the destination filesystem** | ⛔ **no, and this one was the headline of four documents.** Five destinations, including a fresh 1 KB filesystem and the shipped root's own bytes as a data disk, all take the archive in about half a minute |
| ⛔ **it is the 1 KB block size** | ⛔ **no.** One `mke2fs` argument apart, same size, same features, same inode density, one guest each: both finish |
| ⭐ **it is `pkg_add`'s own work**, during or after the write | ⚠ **ALIVE AGAIN.** It was killed by a `tar` control that does not reproduce, and it is the only explanation left standing |

⭐ **What found the first eight was a control.** ⛔ **What found the ninth was
running the same control twice**, which is a rule this repository already had
for benchmarks and had not applied to a diagnosis.

### ⚠ Two things measured on the way that belong to other entries

- ⛔ **The guest's whole userland stops being scheduled** while `pkg_add` runs,
  not just the writer. A shell builtin `echo` produced nothing for 300 seconds,
  twice, and thirty forked `sleep 30` calls took more than 1,500 seconds of wall
  clock. ⚠ That is why no instrument that is a program can be used here, and why
  [`../experiments/42-probe-pkg-add-inside-guest.sh`](../experiments/42-probe-pkg-add-inside-guest.sh)
  could not get its own record out of the guest twice in a row.
- ⛔ **`Console.send()` blocked forever against such a guest**, which was
  `INF-10` and is fixed.

### Approach

⭐ **The destination is exonerated and the phase is located, so what is left is
one question and one workaround.** In order of what is cheapest to prove:

1. ⭐ **DONE. Read what `pkg_add` says before it stops.** `pkg_add -v` prints
   every path and reaches the last one, so the unpack completes and the phase
   after it does not. ⛔ That is a reading and not a theory, and this entry spent
   nine explanations for want of one.
2. ⭐ **Do not need it at all, and this is the route `IMG-02` takes.** A pkgsrc
   binary package is an archive with a known layout: `@cwd /usr/pkg` in its own
   `+CONTENTS`, every payload path relative to that one prefix, and nine
   metadata files that belong in `/var/db/pkg/<pkgname>/` and are marked
   `@ignore` so they are not payload. ⛔ **`tar` does all of it in about half a
   minute**, which is measured, and
   [`../experiments/46-install-without-pkg-add.sh`](../experiments/46-install-without-pkg-add.sh)
   is the whole recipe with the checks after it.
3. ⚠ **Then say what was given up.** No dependency resolution, and the package's
   own `+INSTALL` has to be run rather than assumed away. ⛔ For `gcc14` every
   branch in that script is guarded by `test -x ./+HELPER` and the package ships
   no helper, so it is a no-op, **for this package**. The experiment runs it
   anyway, because assuming it for the next one is how this stops working
   quietly.
4. ⛔ **Do not rebuild the filesystem.** Four controls say it is not the problem,
   and a fix that works and is not understood is what this entry exists to stop.
5. ⚠ **What would actually close this** is reading which loop in the kernel
   `pkg_add` is in after the unpack. ⛔ `ktrace(2)` is not in this kernel, so
   that needs either a kernel with `options KTRACE` or reading
   `pkg_install`'s source for what it does between the last extracted file and
   the pkgdb write. **Neither has been done.**

⛔ **And do not leave the trap in place for a consumer.** Somebody who boots the
build variant and runs `pkg_add` on anything large meets this, with the same
silence, whatever the image ships pre-installed.

### Prove

```bash
sh experiments/46-install-without-pkg-add.sh localhost/netbsd:build
```

⛔ Exit 0, with `gcc --version` answering, `pkg_info -e` finding the package, and
a recorded compile of `sqlite3.c` inside the guest, all inside a runner's job
budget. ⚠ **The entry does not close on that**: it closes when the phase after
the unpack is understood, or when `pkg_add` is deliberately and visibly declared
unusable in this image with the reason recorded for a consumer.

---

## INF-10. `Console.send()` blocks forever on a guest that stopped reading

**Source** Measured 2026-08-28 by
[`../experiments/42-probe-pkg-add-inside-guest.sh`](../experiments/42-probe-pkg-add-inside-guest.sh),
whose first version wedged on it.
**Category** infrastructure · **Priority** P1 · **Effort** S · **Status** done

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

### Closed 2026-08-28

**What changed.** Both halves of the console driver got what every other
primitive in them already had: a budget and a return value.

| | |
| --- | --- |
| `console.py` | the child's **stdin fd is non-blocking**, next to the line that already did it for stdout. A full queue is then a `BlockingIOError` rather than a process parked in the kernel, and a deadline can be spent against it. `send(line, per_char, seconds)` returns whether the whole line was typed |
| `console.ps1` | `Send-Line -TimeoutMs`, typing through a new `Send-Char` that bounds **both** the `WriteAsync` and the `FlushAsync`. ⚠ A StreamWriter buffers, so the write can return long before a byte reaches the guest and the flush is where a full pipe actually stops |

⛔ **A `False` is a real state and the callers were changed to read it.**
`guest.py`'s `run_line` returns "the console stopped accepting input part way
through the command, so it was never run" instead of waiting out its whole
budget for a status from a command the guest never saw.

⭐ **And a `send_raw` was added for the characters that are not a line**, because
a non-blocking fd turns a bare `proc.stdin.write` into a call that can return
`None` and lose a keystroke in silence. `43-siginfo-the-stuck-guest.sh` presses
Ctrl-T through it.

**The defect was planted first**, per the entry's own approach. The test fills
the pipe against a guest that printed a prompt and then stopped reading, which
is the state `INF-09`'s guest reaches. Against today's code, both halves:

```text
  FAIL send(self, line, per_char=0.005) takes no budget. INF-10 ...
  FAIL Send-Line takes no budget. INF-10 ...
```

After the fix:

```text
  ok   send() gave up after 3.0s and said so
  ok   Send-Line gave up after 3.0s and said so
```

⛔ **The test cannot hang against the code it refuses**, which matters here more
than usual: this entry is on record as an instrument whose failure mode was the
same shape as the fault. The budget parameter is checked before anything is
written, and the write itself runs in a daemon thread joined with a deadline.

⚠ **What is NOT fixed, and it is a property rather than a defect.** A timed-out
write leaves a partially typed line in the guest's input queue on both sides,
and on the PowerShell side a pending task on the stream, so the next write
throws. ⛔ **That is why it returns a value**: a caller that gets `False` stops
the guest. It does not type again.

---

## INF-11. The gate can hang forever, because nothing in it is bounded

**Source** Measured 2026-08-28: a full `check-gate.sh` run sat in
`check-binfmt.sh --json` for **more than sixteen minutes** and had to be killed.
**Category** infrastructure · **Priority** P2 · **Effort** S · **Status** open

### Problem

⛔ **No call in [`../scripts/common/`](../scripts/common/) has a timeout.**
`grep -rn 'timeout ' scripts/common/*.sh` returns nothing. The one that hung
shells out to another operating system:

```sh
"$WSL" -d "$DISTRO" -u root -- /bin/sh -lc 'exit 0'
```

⚠ **The hang was not reproduced.** Run again on its own, immediately after, that
same check answered in seconds, and `wsl.exe -e true` answered in under a
second. ⛔ **So the CAUSE is not established and the DEFECT is**, and they are
different claims: the defect is that there is no bound, which is true by reading
regardless of what wedged that day.

⛔ **This is the third time this repository has met the same shape.** `INF-08`
was a read that returned late, `INF-10` a write that never returned, and this is
a gate that can wait for ever. ⚠ **Each was found by waiting**, not by a test.

⚠ **And CI hides it.** `ci.yml` sets `timeout-minutes: 20`, so on a runner this
fails as a job timeout with no indication which check hung. ⛔ **On a developer's
machine there is no bound at all.**

### ⚠ A contributing condition, measured and worth writing down

⛔ **The session that hit this was polling `podman machine ssh` every 45 seconds
from a hold loop while the gate ran.** Both go through `wsl.exe` and the same
distro. ⚠ **That is not proof of contention** and it is the only unusual thing
about the run. ⭐ **A hold loop's "cheap check" must not touch what it is waiting
on**, which is now a row in
[`../docs/conventions/forbidden-patterns.md`](../docs/conventions/forbidden-patterns.md).

### Approach

1. ⭐ **Bound the external calls**, not the whole gate. A gate-wide timeout says
   "something hung"; a per-call one names it.
2. ⚠ **`timeout` is not everywhere.** It is coreutils, present in Git Bash and
   on a runner, absent on some minimal hosts. ⛔ **Detect it and say so rather
   than silently running unbounded**, the way `check-gate.sh` already reports a
   missing `shellcheck` as a SKIP rather than a pass.
3. ⛔ **Plant it.** A check that sleeps past its bound, seen to be killed and
   reported, or the bound is decoration.
4. ⚠ **Report a timeout as a distinct outcome**, not as a failure. A host whose
   WSL is wedged has not got a defective tree.

### Prove

```bash
sh scripts/common/check-gate.sh
```

⛔ Completes or reports which check exceeded its bound, within a stated wall
time, with the defect planted and the kill seen.
