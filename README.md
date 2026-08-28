- #### [OCI images of the BSDs](https://github.com/orgs/pkgforge-dev/packages?repo_name=docker-bsd) [![ci](https://github.com/pkgforge-dev/docker-bsd/actions/workflows/ci.yml/badge.svg)](https://github.com/pkgforge-dev/docker-bsd/actions/workflows/ci.yml)

Unofficial, automated OCI images of **FreeBSD, NetBSD and OpenBSD**, built
from each project's own published userland, plus the measured routes from an
ordinary host to a **running** one.

⚠ **Proof of concept.** One architecture, `amd64`. The shape is settled and the
coverage is not. [`docs/LIMITS.md`](docs/LIMITS.md) is the honest account of
what works today, with the cost of each route in seconds.

**Licence:** 0BSD.

---

- #### ⛔ Read this before you try to run one

A BSD image needs a **BSD kernel**. It cannot run on a Linux container engine,
and that is not a bug anybody can fix here.

```bash
podman run --rm ghcr.io/freebsd/freebsd-runtime:15.1 /bin/sh -c 'uname -a'
```

Exit code **139**, which is 128 + 11, a **SIGSEGV**. No stdout.

⭐ **Read the number, not the text.** 139 is not `Exec format error`. The
loader **accepts** the binary and it dies on its first syscall, because the
syscall ABI is a different operating system's. ⛔ So `binfmt_misc` and
`qemu-user` do not help: they translate a foreign **architecture** presenting
Linux syscalls.

⭐ **Building these images needs no BSD kernel. Only running one does.**
That is why ordinary Linux CI can build them, and why nothing here smoke-tests
them: no runner can run one.

---

- #### ⭐ How to actually get a BSD shell

**The routes, and what each costs.** ⛔ The numbers live in
[`docs/LIMITS.md`](docs/LIMITS.md) and nowhere else; this table is a pointer.

| you have | you get | privilege |
| --- | --- | --- |
| ⭐ **only podman or docker** | a NetBSD shell in a couple of seconds, under emulation, with the emulator **inside the image** | ⭐ **none** |
| an emulator, on Windows | a full FreeBSD 15.1 userland on the machine's own hypervisor | ⭐ none |
| `/dev/kvm` | a FreeBSD microvm in under two seconds | write access to `/dev/kvm` |
| a BSD host | ⭐ `podman run` on these images directly | none |

⭐ **The first row is one command, and this repository publishes the image:**

```bash
podman run --rm -it ghcr.io/pkgforge-dev/netbsd:latest sh
```

⛔ **Nothing is installed and nothing is fetched at run time.** The emulator,
the guest kernel and the guest root filesystem are in the image, so it works
with `--network none` and needs no privilege, no capability and no device.
⚠ `-it` is not optional: what you are given is a console.

**Two variants, and only one of them is published today:**

| tag | what is in it | state |
| --- | --- | --- |
| ⭐ `netbsd:latest` | a rescue userland. A shell and `sysctl`. ⛔ No `uname`, no `ls`, no compiler | ⭐ **published.** The command above pulls it |
| `netbsd:build` | ⭐ a real userland: `uname`, `make`, `pkg_add`, `pkgin`, a network, and a compiler package staged inside it ready to install | ⛔ **built and proved in CI, not yet published.** `IMG-02` |

⛔ **Do not write a `docker pull` for `netbsd:build` yet.** It does not exist in
the registry, and a command in a README that returns a 404 is worse than no
command.

⚠ **The compiler is staged, not installed.** Installing it at build time was
tried and does not finish, which is `INF-09` in [`TODO/INDEX.md`](TODO/INDEX.md)
and is written up with what was ruled out.

⛔ **What neither of them does yet:** `-v`, `-p` and `-e` reach the **container**
and stop there. The BSD is a virtual machine inside it with its own filesystem,
so a source tree on your host is not visible to it and nothing you build inside
comes out. That is filed as `IMG-03` in [`TODO/INDEX.md`](TODO/INDEX.md).

- #### The four, and why they are not handled the same way

⛔ **Three different acquisition methods.** [`scripts/sources`](scripts/sources)
is the single place that records which and why; everything else reads it.

| BSD | method | why |
| --- | --- | --- |
| FreeBSD | `oci` | ⭐ Upstream publishes real OCI layout archives with a `CHECKSUM.SHA256`. They are **verified and loaded, never rebuilt.** Rebuilding an image somebody already publishes correctly is the most expensive mistake available. |
| NetBSD | `sets` | `base.tar.xz` is already a root filesystem tar owned `root/wheel`, so it imports directly. |
| OpenBSD | `sets` | `base79.tgz` is the same shape, owned `root/bin`. 535 MB. |

⚠ **Only FreeBSD publishes OCI images upstream.** For the other two these
are, as far as this repository's authors could determine on 2026-08-27, the
only published OCI images that exist.

⛔ **And for three of the four, nothing can run what is published.** That is
`BSD-02`, answered per BSD in [`HISTORY/references/usable.md`](HISTORY/references/usable.md).

---

- #### Build one

```bash
sh scripts/build-bsd --bsd netbsd
```

That is a **dry run**: it fetches, verifies, imports, checks what the image
declares, tags it locally, and prints what it would have published. Publishing
is not something to do by accident, so it takes a flag:

```bash
sh scripts/build-bsd --bsd netbsd --push
```

FreeBSD has five variants, smallest first: `static` (559 KB), `dynamic`,
`runtime`, `notoolchain`, `toolchain` (215 MB).

```bash
sh scripts/build-bsd --bsd freebsd --variant static
```

**What it does, in order.** Fetch from the URL [`scripts/sources`](scripts/sources)
declares. ⛔ **For FreeBSD, verify the SHA-256 against the published checksum
file**, with no flag to skip it. Import with the correct OCI `os` value.
⛔ **Read back what the image actually declares** and refuse it if the `os` or
`arch` is not what was asked for. Tag, and push only with `--push`.

⚠ **The checksum proves integrity, not provenance.** The checksum file comes
from the same host as the artifact. What it catches is every accident, which is
nearly everything that actually goes wrong. Signature verification is the next
step up and is **not** implemented.

---

- #### Requirements

| tool | for |
| --- | --- |
| `podman` or `docker` | everything |
| `curl` | everything |
| `sha256sum` or `shasum` | FreeBSD's digest check. ⛔ Absence is an error, not a skip. |

⚠ **On Windows, set `MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'`** before
driving podman from Git Bash. The scripts are written to survive it: every
native binary is run from the working directory with a **bare filename**, never
given a path. That was measured here three times, once per tool.
[`docs/conventions/shell.md`](docs/conventions/shell.md) section 7.

---

- #### Known limits

⛔ Listed because a limit hidden is a defect filed against the user later. The
full account, with numbers, is [`docs/LIMITS.md`](docs/LIMITS.md).

| limit | what it means |
| --- | --- |
| ⛔ the images cannot run on Linux | see the top of this file. A BSD kernel is required |
| ⭐ **one published image boots itself** | `netbsd:latest`. ⚠ The other four are userlands and still need a BSD kernel |
| ⛔ nothing you build inside the guest comes out | `-v` reaches the container and stops there. `IMG-03` |
| ⚠ three of four BSDs have no runtime | `ocijail` exists for FreeBSD. Nothing equivalent exists for the others |
| ⚠ NetBSD and OpenBSD import **one set** | `podman import` takes a single tar. `base` is a complete userland; `etc` and the rest are not merged in |
| ⚠ DragonFly was **dropped on 2026-08-28** | it needed a third acquisition method of its own. The route worked and is kept, with its three traps, in [`HISTORY/dragonfly.md`](HISTORY/dragonfly.md) |
| ⚠ no signature verification | integrity only, per above |
| ⚠ `amd64` only | one architecture is enough to prove the shape |
| ⚠ one release per BSD | pinned in `scripts/sources`. Publishing every release is a different decision with a retention policy attached |

---

- #### Testing

```bash
sh tests/run.sh
```

```bash
sh scripts/common/check-gate.sh --fast
```

⛔ **Neither runs a BSD image**, for the reason at the top of this file. The
first checks the build scripts and the matrix; the second checks the
repository. ⚠ A skipped check is reported as skipped and never counted as a
pass.

---

- #### Layout

| path | what |
| --- | --- |
| [`scripts/sources`](scripts/sources) | ⭐ the matrix, as data. Bumping a release is one edit here |
| [`scripts/build-bsd`](scripts/build-bsd) | fetch, verify, import, check, tag, push |
| [`scripts/common/`](scripts/common/) | the gate this repository runs on itself |
| [`examples/`](examples/README.md) | ⭐ runnable. Start at `01-bsd-shell-with-only-podman.sh` |
| [`experiments/`](experiments/README.md) | ⭐ every route to a running BSD, committed with its result, **including the ones that failed** |
| [`docs/AGENTS.md`](docs/AGENTS.md) | ⭐ the single entry point for an agent working here |
| [`docs/HUMANS.md`](docs/HUMANS.md) | what a person runs, and the permissions block |
| [`docs/LIMITS.md`](docs/LIMITS.md) | ⭐ what does not work yet, and what each route costs |
| [`TODO/`](TODO/PROGRESS.md) | the work order, the entry list, and the last session's brief |
| [`HISTORY/`](HISTORY/README.md) | ⭐ every measurement and every claim this repository has withdrawn |
