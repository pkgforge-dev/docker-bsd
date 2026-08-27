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

### Problem

⛔ **Installing one compiler into the guest takes longer than every other step
in the image build put together**, and it is the reason that job's timeout is
two hours rather than twenty minutes.

The step boots the guest and runs `pkg_add` on a package that is already inside
its filesystem. No network is involved. It is half a gigabyte of files, and
under emulation that is tens of minutes.

### ⛔ THE CAUSE IS NOT KNOWN, AND THREE GUESSES ARE ALREADY DEAD

⚠ **This entry was first written with a confident explanation and the
explanation was wrong.** It is corrected here rather than quietly, because the
wrong version is the useful part: each guess was cheap to test and each one
would have sent the fix in a different direction.

| the guess | the measurement that killed it |
| --- | --- |
| it is fetching over the emulated network | ⛔ **no.** The package is written into the guest's filesystem from Linux before it boots, and the stage has no network at all |
| the emulated disk is slow | ⛔ **no.** The guest writes 100 MB in 2.5 seconds, 42 MB per second. Half a gigabyte of bulk writing is about twelve seconds |
| ⚠ it is tens of thousands of small files | ⛔ **no, and this was the confident one.** The package holds **1,664** files. `xz -dc gcc14.tgz \| tar t \| wc -l` |

⭐ **One thing was learned while killing the third guess**: the package is **xz**
compressed, not gzip, whatever its `.tgz` name says. LZMA decoding is expensive
per byte and emulation is expensive per instruction. ⛔ **That is a hypothesis
and it is not measured**, and this entry does not get another confident
explanation until somebody times the decompression on its own.

### Approach

⛔ **Find the cause first.** Three cheap measurements, in order, each inside the
guest:

1. `xz -dc` the package to `/dev/null` and time it. That isolates the decode
   from everything else;
2. `tar t` the decoded stream to `/dev/null` and time it;
3. the same two on the Linux side, for a ratio.

⭐ **Then the fix follows from the answer, and two are already obvious:**

- if it is the decode, recompress the package on the Linux side into something
  cheap to decode. The guest never has to know it was ever xz;
- if it is the extraction, do not boot the guest at all. Its root filesystem is
  ext2 and Linux already writes into it with `debugfs`, which is how the
  package and the benchmark source get there.

⚠ **What makes it an `M` rather than an `S`** if the second route is taken: a
pkgsrc package is a tar plus metadata, and `pkg_add` also registers it in the
package database. Files alone give a working compiler and a package database
that does not know about it.

### Prove

⛔ **A number for the cause**, in [`../docs/LIMITS.md`](../docs/LIMITS.md),
before any fix is written. Then the build variant's image builds in a time
comparable to the rescue variant's, the compile the benchmark runs still
succeeds inside it, and `pkg_info` still lists what is installed.
