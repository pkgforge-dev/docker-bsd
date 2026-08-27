# poc.md

Every measurement behind the claims in [`../README.md`](../README.md), with the
command that produced it.

⚠ **All of it on one machine, on 2026-08-27**: Windows 11 Pro 26200, podman
5.8.6 with a WSL2 Fedora machine, PowerShell 7.6.5, Git Bash. A measurement
carries its conditions or it is not a measurement.

---

## 1. ⭐ The measurement that settles the architecture

```bash
podman run --rm ghcr.io/freebsd/freebsd-runtime:15.1 /bin/sh -c 'uname -a'
```

```text
WARNING: image platform (freebsd/amd64) does not match the expected platform (linux/amd64)
```

**Exit code 139. No stdout.** 139 is 128 + 11: SIGSEGV.

⛔ **Not `Exec format error`.** That distinction is the entire design decision.
`Exec format error` is what a wrong architecture produces, and it is what
`binfmt_misc` plus `qemu-user` exists to fix. Here the Linux ELF loader
**accepts** the binary, because it is a valid amd64 ELF object, and the process
dies on its first syscall because the syscall ABI belongs to another operating
system.

Consequences, each of which was a candidate approach before this was measured:

- ⛔ no `binfmt_misc` change reaches it. The adjacent `Exec format error` problem
  in `Azathothas/TEMPLATE` issue 2 looks like the same family and is not;
- ⛔ `qemu-user` does not help. It emulates a foreign architecture presenting
  **Linux** syscalls. Nothing presents BSD syscalls on a Linux kernel;
- ⭐ therefore a BSD userland needs a BSD kernel, and the only question left is
  which hypervisor boots it.

⭐ **Building an image needs none of that.** An OCI image is a tar plus JSON.
The kernel only matters at `run`, which is why this repository builds happily
on Linux CI runners and makes no attempt to smoke-test its own output.

## 2. The pull is refused before it can even fail

```bash
podman pull ghcr.io/freebsd/freebsd-runtime:15.1
```

```text
Error: ... no image found in image index for architecture "amd64", variant "", OS "linux"
```

⚠ `--os freebsd` is required and it is **not** the same flag as `--platform`.
Reaching for `--platform linux/amd64` out of habit asks for an image that does
not exist.

## 3. All four OCI `os` values are accepted

Tested by importing a three-file tar four times:

| `--os` | result |
| --- | --- |
| `netbsd` | ✅ `netbsd/amd64` |
| `openbsd` | ✅ `openbsd/amd64` |
| `dragonfly` | ✅ `dragonfly/amd64` |
| `freebsd` | ✅ `freebsd/amd64` |

⛔ **The first attempt failed for an unrelated reason and it is worth recording**,
because the error names neither the cause nor the fix:

```text
potentially insufficient UIDs or GIDs available in user namespace
(requested 197609:197609 for /bin) ... lchown /bin: invalid argument
```

The tar had been built on Windows and carried a Windows-derived uid. Rootless
podman cannot map it. ⭐ **Every rootfs tar this repository builds is packed
`--owner=0 --group=0 --numeric-owner`.** The upstream BSD sets already are, so
only the DragonFly path, which repacks, has to do it.

⚠ `tar --uid` is bsdtar and is **not** GNU tar. Git Bash gives you GNU tar, and
`--uid` there is `unrecognized option`. The GNU spelling is `--owner=0
--group=0`.

## 4. The full publish round trip, on this machine

Proven against a throwaway local registry, because the account token here has
`repo` and `workflow` but not `write:packages`, so ghcr could not be the target.

```bash
podman run -d --name bsdpoc-registry -p 5959:5000 docker.io/library/registry:2
podman push --tls-verify=false localhost:5959/pkgforge-dev/freebsd:15.1-static-amd64
podman pull --tls-verify=false --os freebsd --arch amd64 localhost:5959/pkgforge-dev/freebsd:15.1-static-amd64
```

| step | result |
| --- | --- |
| download `...static.txz` | 559 876 bytes |
| SHA-256 against published `CHECKSUM.SHA256` | ✅ `483d55d1...79ca8` |
| load | ✅ `freebsd/amd64`, 1 layer, 2.9 MB |
| push, then pull back | ✅ `freebsd/amd64` preserved |
| stored manifest | ✅ `application/vnd.oci.image.manifest.v1+json` |

⭐ **The registry side of publishing a BSD image is ordinary.** Nothing in the
OCI path treats a non-Linux `os` specially. The only thing missing from a real
publish is the credential, which CI has.

## 5. NetBSD, built

```bash
podman import --os netbsd --arch amd64 --change 'CMD ["/bin/sh"]' base.tar.xz localhost/netbsd:10.1-base
```

`base.tar.xz` is 50 739 544 bytes, 6 637 entries, already owned `root/wheel`.
Result: **`os=netbsd arch=amd64`, 269 323 561 bytes, `CMD=[/bin/sh]`.**

⚠ `etc.tar.xz` (508 152 bytes) is fetched and **not merged**: `podman import`
takes one tar. `base` is a complete userland, which is enough here.

## 6. DragonFly: why the disk image is a dead end

Upstream publishes only `dfly-x86_64-6.4.2_REL.{img,img.bz2,iso,iso.bz2}`. No
set tarballs exist.

⛔ **The `.img` cannot be used on Linux.** Its root filesystem is HAMMER2 and
Linux has no driver, so no CI runner can mount it.

The ISO is the way through, confirmed rather than assumed with a 5-byte ranged
read at the ISO9660 signature offset:

```bash
curl -fsSL -r 32769-32773 "https://mirror-master.dragonflybsd.org/iso-images/dfly-x86_64-6.4.2_REL.iso"
```

```text
CD001
```

748 MB. ⚠ **Method verified, extraction not yet run end to end.** Stated here
rather than implied by the script's existence.

## 7. ⛔ Three tools, one trap, three failures

Every native Windows binary driven from Git Bash failed the same way, and each
error named neither the path nor the cause. This is worth its own section
because it cost three separate debugging rounds.

| tool | symptom |
| --- | --- |
| `curl` | `curl: (23) client returned ERROR on write of 8268 bytes` |
| `podman load` | `load produced no image` |
| `7z` | (anticipated, same class) |

**Cause.** `MSYS_NO_PATHCONV=1` is required to drive podman from Git Bash, and
it also stops Git Bash rewriting a msys `/c/Users` path into the `C:` form for native
binaries that need a Windows path. `/tmp` makes it worse: Git Bash resolves it
inside the msys root and a native binary resolves it somewhere else or nowhere.

⭐ **The fix is uniform and it is not more quoting.** Run each native binary
**from** the target directory and hand it a **bare filename**. A relative name
is correct for every tool on every host and sidesteps path conversion entirely.
The scratch directory is repository-relative, never `/tmp`.

## 8. ⛔ A false pass, in the script whose whole job is verification

`build-publish` was written as:

```sh
ARTIFACT=$(sh "$HERE/fetch-verify" ... | tail -1)
rc=$?
```

`$?` after a pipeline is **`tail`'s** status, which is 0 whatever the check did.
A failed download reported success and the build continued to load a file that
was not there. The test harness that caught it had the identical bug in its own
`echo "rc=$?"` after a pipe.

⭐ **This is the exact row in the template's forbidden-patterns table**,
committed twice in one afternoon by the code enforcing it. Output now goes to a
file and the status is read unpiped.

---

## What is still unknown

⛔ Stated rather than left to be discovered:

- **Hyper-V and WSL2 coexisting on one machine is asserted, not measured.** Both
  use the Windows hypervisor, which is the reason to expect it. It is the first
  thing to check before building anything on the runtime side, because the
  operator's podman machine is a WSL2 VM that must keep working.
- **No BSD host was available**, so no image produced here has ever been run.
  Every image was verified by what it *declares*, never by executing it.
- **OpenBSD was fetched but not completed** in the session that wrote this; the
  mechanism is identical to NetBSD's and the set shape was confirmed by
  streaming the first entries (`root/bin` ownership).
- **`bsdtar` is absent on this machine**, so the DragonFly path here would use
  `7z`. CI installs `libarchive-tools`.
