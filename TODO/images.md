# TODO: images

What this repository **publishes**, and the distance between what it publishes
today and the one gesture a consumer expects.

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.
⛔ Every entry here is filed from a measurement in
[`../docs/LIMITS.md`](../docs/LIMITS.md), never from an opinion about what ought
to exist.

---

## IMG-01. `podman run --rm -it <image> sh` drops you in a BSD

**Source** The operator, 2026-08-27, asking the question a consumer asks.
**Category** images · **Priority** P0 · **Effort** L · **Status** done

### Problem

```bash
podman run --rm -it ghcr.io/pkgforge-dev/freebsd:latest sh
```

⛔ **Today that exits 139 on any Linux host.** A BSD userland needs a BSD kernel
and a container does not have one.

### Premise, measured

⭐ **The route works and is not packaged.** A Linux container carrying an
emulator, a microvm kernel and a root filesystem reaches a BSD shell that
answers, with **no privilege, no device and nothing installed on the host**.
The timing is in [`../docs/LIMITS.md`](../docs/LIMITS.md); the experiment is
[`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh).

⚠ **What the experiment does that a published image must not.** It `apk add`s
the emulator and downloads the kernel and root filesystem **at run time**, from
a bind mount. ⛔ A published image bakes all three into layers, so the consumer
pays no network and no setup at all.

### Approach

1. A `Dockerfile` on a small Linux base with the emulator, the guest kernel and
   the guest root filesystem in layers.
2. An entrypoint that boots the guest and wires its console to the container's
   stdio, ⭐ **using `/dev/kvm` when it is present and pure emulation when it is
   not**, without the consumer choosing.
3. ⛔ **Every artefact pinned by digest**, the way [`../scripts/sources`](../scripts/sources)
   already pins a release. An image that fetches at build time from a moving tag
   is not reproducible.
4. Published to both registries the organisation uses, and as a loadable file
   in the release, for the air-gapped consumer `INF-04` exists for.
5. ⛔ **It must build and be tested on a free GitHub runner.**
   [`RULES.md`](RULES.md) constraint: that is the target environment, not a
   convenience.

### ⛔ What must not be done

- ⛔ **Do not fetch at run time.** That is what makes the experiment an
  experiment and would make the image a liability on an air-gapped host.
- ⛔ **Do not require a flag to make it work.** `-it` is acceptable because it
  is a console. Anything more is setup, and the point of this entry is no setup.
- ⛔ **Do not name it `freebsd`.** ⭐ **Ruled 2026-08-27: the first image is
  NetBSD and is named `netbsd`**, because that is what it is.
  [`RULES.md`](RULES.md) decision 1. FreeBSD follows when `IMG-02` has a full
  root filesystem.

### Prove

```bash
podman run --rm -i IMAGE sh -c 'sysctl -n kern.ostype'
```

⛔ Exit code 0, read unpiped, stdout naming a BSD. ⚠ **And the same command on a
host with `podman` freshly installed and nothing else**, because that is the
claim.

### Closed 2026-08-28

**What shipped.** `ghcr.io/pkgforge-dev/netbsd:latest`, built and proved on a
free `ubuntu-latest` runner by
[`../.github/workflows/image-netbsd.yml`](../.github/workflows/image-netbsd.yml),
from [`../images/netbsd/Containerfile`](../images/netbsd/Containerfile). The
size and the seconds are in [`../docs/LIMITS.md`](../docs/LIMITS.md) and
nowhere else.

**The acceptance command, run against the PUBLISHED image**, pulled from the
registry on a machine that had just deleted its local copy:

```text
$ podman run --rm -i ghcr.io/pkgforge-dev/netbsd:latest sh -c 'sysctl -n kern.ostype'
smolBSD
exit 0
```

**Every requirement of this entry, and where it is met:**

| the requirement | where |
| --- | --- |
| artefacts in layers, nothing fetched at run time | ⭐ proved by a run with `--network none` in CI, which reaches the same shell |
| every artefact pinned by digest | [`../scripts/sources`](../scripts/sources). ⚠ One exception is labelled rather than hidden: the emulator comes from a package branch with no snapshot to pin to, and its resolved version is written into the image |
| `/dev/kvm` used when present, emulation when not, with no flag | [`../images/netbsd/entrypoint.sh`](../images/netbsd/entrypoint.sh) |
| built and tested on a free GitHub runner | the workflow above |
| named `netbsd` | [`RULES.md`](RULES.md) decision 1 |
| anonymously pullable | checked against the registry without credentials, HTTP 200 |

⛔ **The guard was seen to fail, which is why the proof is not theatre.** CI asks
the guest to `exit 3` and requires exactly 3 back. An entrypoint that always
exited 0 would pass the acceptance command above for ever.

⚠ **What did NOT close with it.** The second half of the entry's own Prove line
said "on a host with podman freshly installed and nothing else". The runner is
close to that and is not it: podman was already there. `PORT-01` owns the rest,
and [`../scripts/time-image`](../scripts/time-image) is the one command it
needs.

---

## IMG-02. A real userland in it, not a rescue shell

**Source** The operator, 2026-08-27: "can a developer install rust and compile a
rust binary for freebsd?"
**Category** images · **Priority** P0 · **Effort** L · **Status** open

### Problem

⛔ **The image `IMG-01` would publish today is a demonstration, not a
development environment**, and
[`../docs/LIMITS.md`](../docs/LIMITS.md) says so in four rows: it is NetBSD
rather than FreeBSD, it is a rescue userland of about 20 MB with no package
manager and no compiler, nothing persists, and compute is emulated unless a
device is handed in.

### Premise, measured

⭐ **A full BSD in a microvm is not hypothetical.** `acj` publishes a FreeBSD
kernel and root filesystem that reach a login prompt in under two seconds on
`/dev/kvm`, measured here by
[`../experiments/31-boot-freebsd-firecracker.sh`](../experiments/31-boot-freebsd-firecracker.sh).
⛔ The number itself lives in [`../docs/LIMITS.md`](../docs/LIMITS.md) and in no
other file.

⚠ **What is NOT known** is what that costs unaccelerated, which is the case
`IMG-01` must serve. ⛔ A full kernel probing a full device tree is exactly the
shape whose device probe dominated the boot on the other route, and
[`../docs/LIMITS.md`](../docs/LIMITS.md) carries that number.

### Approach

⛔ **Measure before building.** In order:

1. boot a full FreeBSD microvm **unaccelerated** and time it. That number
   decides whether one image can serve both cases or whether there must be two;
2. add a package manager and install something;
3. ⭐ **compile something real and record the wall time**, against the same
   compile on the host, so the penalty is a ratio and not an adjective.

### Prove

```bash
podman run --rm -i IMAGE sh -c 'pkg install -y rust && rustc --version'
```

⛔ Exit 0 and a version. ⭐ **Plus a recorded build time** in
[`../docs/LIMITS.md`](../docs/LIMITS.md), because "it works" without a number is
what this entry exists to stop.

---

## IMG-03. The flags a consumer already knows must reach the guest

**Source** The operator, 2026-08-27: "users really need no setup and just use
same old docker/podman flags they know and love?"
**Category** images · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **They reach the container and stop there.** The guest is a virtual machine
inside the container with its own root filesystem, its own network stack and its
own environment.

| flag | today |
| --- | --- |
| `-v host:guest` | ⛔ the BSD cannot see it |
| `-p 8080:80` | ⛔ nothing forwards it inward |
| `-e FOO=bar` | ⛔ not inherited |

⚠ **That is the difference between "it boots" and "I can use it."** A consumer
who cannot get a source tree in and a binary out has a demonstration.

### Approach

⭐ **All three are ordinary emulator features and none needs privilege.** A
shared filesystem for `-v`, a user-mode port forward for `-p`, and passing the
environment through the guest's boot arguments or a shared file for `-e`.

⛔ **The entrypoint reads the container's own view and translates it**, so the
consumer types the flag they already know and nothing new is documented. ⚠ A
flag that silently does nothing is worse than one that is refused: if a mapping
cannot be honoured, say so and exit non-zero.

### Prove

```bash
echo hello > /tmp/in.txt && podman run --rm -v /tmp:/mnt IMAGE sh -c 'cat /mnt/in.txt'
```

⛔ Exit 0 and `hello` on stdout, read unpiped.
