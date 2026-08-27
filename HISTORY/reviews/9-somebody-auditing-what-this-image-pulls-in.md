# Review 9: somebody auditing what this image pulls in

⭐ **The lens.** A person who has to approve this image for a team. They do not
care how fast it boots. They ask what it downloads, whom it trusts, what runs
with what privilege, and what changes underneath them between two builds that
call themselves the same thing.

**Run** 2026-08-28, over the tree at the time the build variant was being
provisioned.

---

## What it swept

[`../../images/netbsd/Containerfile`](../../images/netbsd/Containerfile),
[`../../scripts/sources`](../../scripts/sources),
[`../../scripts/build-netbsd`](../../scripts/build-netbsd),
[`../../images/netbsd/grow-rootfs.sh`](../../images/netbsd/grow-rootfs.sh) and
[`../../.github/workflows/image-netbsd.yml`](../../.github/workflows/image-netbsd.yml),
against the question "what would I have to trust".

---

## ⭐ What holds up

| the question | the answer |
| --- | --- |
| what is fetched at build time | four things: a base image by manifest digest, a guest kernel by SHA-256, a guest root filesystem by SHA-256, and Alpine packages |
| what is fetched at run time | ⭐ **nothing.** Proved by a CI run with `--network none` reaching the same shell |
| can the digest check be skipped | ⛔ **no.** There is no flag, and `tests/run.sh` fails the build if a way past one is ever added |
| does the workflow ask for more than it needs | `contents: read` at the top, `packages: write` only on the job that publishes |
| are third-party actions pinned | to a commit, and the one action used is checked out with `persist-credentials: false` |

---

## ⛔ What it found

### 1. ⛔ The emulator is not pinned, and the label is honest but easy to miss

`apk add qemu-system-x86_64 python3` resolves against an Alpine branch, which is
a moving pointer with no snapshot service to point at instead. ⭐ **The resolved
version is written into `/opt/bsd/evidence.txt` in the image**, so two builds
can be told apart afterwards.

⛔ **That is a record, not a pin.** Two builds of the same commit can differ,
and the only way to know is to read a file inside each. An auditor who diffs
manifests will see it; one who reads the Containerfile will read the warning;
one who reads neither will assume the whole thing is pinned because everything
else is.

⚠ **No fix is proposed here** because the honest ones are expensive: vendor the
emulator, or build it. `OPT-02` already owns that direction and this is one more
argument for it.

### 2. ⛔ The build variant installs from a repository over the network, at build
### time, with no digest at all

`pkg_add -U gcc14` fetches from `cdn.netbsd.org` inside the booted guest. ⛔
**Nothing verifies what comes back.** The pkgsrc tooling checks its own
signatures only when configured to, and this build does not configure it.

⚠ **The consequence is bounded and worth stating exactly**: it is a build-time
fetch over TLS from the project's own CDN, baked once into a published layer,
not a run-time fetch on a consumer's machine. So a consumer inherits whatever
that CDN served on the day of the build, and can see it in the image.

⭐ **This is a real gap and it is the same shape as `INF-06`**, which exists for
upstreams changing their minds. Recorded there rather than invented as a new
entry.

### 3. ⚠ The guest in the build variant has network egress by default

The variant that has a package manager ships with a user-mode network stack, so
a program inside the guest can reach the internet whenever the container can.

⭐ **That is deliberate and it is the right default**: a package manager with no
network cannot do its one job. ⚠ **And it is worth an auditor knowing**, because
"it is a VM inside a container" reads as more isolated than it is. The mitigation
is the ordinary one and it works: `--network none` on the container cuts the
guest off completely, proved in CI.

### 4. ⚠ Everything in the guest runs as root, and there is no other user

The guest boots to a root shell. There is no unprivileged user and nothing drops
privilege. ⛔ **Inside the guest that is a virtual machine's own root**, not the
host's, and the container itself needs no privilege at all. An auditor should
weigh the guest's root the way they would weigh a VM image, not a container.

### 5. ⚠ The provisioning stage boots an emulator inside a container build

That is unusual enough to be worth naming. It runs unaccelerated, because a
build has no `/dev/kvm`, and it is by far the slowest step in the file. ⭐ **The
guest syncs and remounts its root read only before the emulator is stopped**,
because the console driver's stop is a terminate and a filesystem with dirty
buffers at that moment would be shipped in an unknown state.

⚠ **It is also expensive in a way that has an obvious cheaper shape**: the
package is downloaded by the GUEST, through an emulated network stack, when the
container could have downloaded it at Linux speed and handed it over. That is an
optimisation nobody has measured and it is not made here.

---

## ⚠ What this review did NOT look at

- ⛔ **The contents of the guest root filesystem.** It is upstream's published
  image, verified by digest and otherwise taken as given. Nothing here audited
  what is inside it.
- ⛔ **The emulator's own attack surface.** qemu with a user-mode network and a
  virtio block device is a large amount of C, and this review did not weigh it.
- ⛔ **Whether ghcr.io's copy matches what CI built.** The digest was read from
  the registry and not compared against the build's own output.
- ⚠ **Signing or provenance.** Nothing is signed, no attestation is produced,
  and `INF-01` is the entry for it.
- ⚠ **The four userland images this repository also publishes.** A different
  pipeline, untouched by this session.
