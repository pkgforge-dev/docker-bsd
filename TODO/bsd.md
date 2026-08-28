# TODO: bsd

Reaching a real BSD userland from a Windows host through a podman-shaped
interface.

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.

⛔ **This file carries current facts only.** How the project reached them is in
[`../HISTORY/bsd-entries.md`](../HISTORY/bsd-entries.md), verbatim and
unedited. ⚠ **Read that before overturning anything here**: several conclusions
below are the second or third answer to their question, and the discarded ones
are why.

⭐ **The prior art is read, and it is in this repository.** 28 references were
swept on 2026-08-27 and written up in two files:
[`../HISTORY/references/findings.md`](../HISTORY/references/findings.md) has the
verdicts and the ranking,
[`../HISTORY/references/usable.md`](../HISTORY/references/usable.md) has the
commands. ⛔ **Every entry below names the sections that bear on it.** A session
that designs before reading them is re-deriving work that is already on disk.

⚠ **The measured numbers are in [`../docs/LIMITS.md`](../docs/LIMITS.md)** and
in no other file, this one included.

---

## BSD-01. Run a BSD userland from Windows, with the least friction that works

**Source** The operator, 2026-08-27, with five references supplied, plus a
follow-up naming all four BSDs and `pkgforge-dev/docker-bsd`.
**Category** bsd · **Priority** P1 · **Effort** M · **Status** open

### Problem

```bash
podman run --rm -it "example.io/freebsd" -sh
```

from Windows, into a real BSD, without `wsl` inside `linux` inside `qemu`
inside `bsd`.

### ⭐ Where it stands: the purpose is met, the acceptance is not

⛔ **Those are different sentences and both are true.** Stated as a table so
nobody has to infer which.

| the clause | state |
| --- | --- |
| a real BSD | ⭐ **met.** FreeBSD 15.1-RELEASE, stock GENERIC, answering commands |
| from Windows | ⭐ **met.** On the host's own hypervisor through WHPX |
| ⛔ without the nesting | ⭐ **met.** One hypervisor, and unelevated, which was not asked for |
| `podman run`, inside the guest | ⭐ **met.** `rc=0`, `runtime=ocijail`, the container's own stdout read back |
| `podman run`, **from the Windows client** | ⛔ **NOT met.** This is the `Prove` clause, and it is what keeps the entry open |

### ⛔ The blocker, stated exactly

`podman system service` is a long-running Go daemon and it **takes the guest
kernel down**: a page fault in kernel mode, in `do_wait` under
`__umtx_op_wait_uint_private`, which is what a Go scheduler parks threads on.
⭐ **Everything underneath it works**: the throwaway key, the closed
empty-password door, the forwarded loopback port, the authenticated ssh, the
socket file, and `podman system connection add`.

⚠ **A one-shot `podman run` inside the guest reaches `rc=0`**, and selecting a
different guest timecounter is what moves it there. ⛔ **That is a workaround
and not a fix**, the cause is not known, and with that timecounter the daemon
still takes the kernel down.
[`../docs/LIMITS.md`](../docs/LIMITS.md) section 5 carries the fault.

### ⚠ What is not measured, so it is not claimed

- **A BSD boot under nested KVM against the Hyper-V guest.** ⭐ Nested KVM is
  available inside this machine's WSL2 podman machine and that is measured; how
  fast a BSD guest is under it is not.
- **Whether the `.vhd` Hyper-V route works**, which is the lowest-friction
  option that has never been re-checked since the reference sweep.
- **Whether a Go daemon can be kept alive in that guest at all.** Three things
  worth trying and none tried: a timecounter chosen for a daemon rather than
  for a command, setting it at boot so no Go binary runs before it is selected,
  and running the service somewhere else entirely, which satisfies the
  acceptance and is a weaker result that must be labelled as one.

### ⭐ Prior art already read, by section

⛔ **Read these before designing anything here.** Each is a section, not a file.

| what you are about to do | read |
| --- | --- |
| anything involving QEMU on Windows, or a `-cpu` model | ⭐ `findings.md`, the `R18` `anyvm-org/anyvm` verdict. It is the only reference that has **measured** the Windows hypervisor: `-cpu host` and `-cpu max` can wedge QEMU outright, and a named model newer than the host does it too |
| deciding whether nesting is acceptable | ⭐ the same verdict's last paragraph: nested AMD-V mishandles an L2 guest's AVX512 state, which is a **correctness** fault and not a performance one. ⚠ It does not bite on this Intel host and it is why nesting was ranked on more than speed |
| booting a BSD under Firecracker | `usable.md`, the `R11` and `R13` sections, and `findings.md`'s `R11` verdict for the CPU faults that took a year to find |
| running a BSD in CI | `usable.md`, the `R8` `vmactions` section, and `R17` for the `udev` rule that makes a runner's `/dev/kvm` writable |
| an OCI image booted as a microVM | `usable.md`, the `R26` `bsdkrun` section. ⛔ macOS and Linux only, so on this host it is nesting |
| driving WSL's own host protocol | `usable.md`, the `R6` table of the wire format. ⛔ The guest half is 819 lines of C; the host half is a rebuilt `wslservice.exe`, which is refused |

### Prove

```bash
podman -c freebsd run --rm IMAGE /bin/sh -c 'uname -sr'
```

⛔ Exit 0, read unpiped, and `FreeBSD` on stdout. ⚠ **Status stays `open` on
this command and not on the goal**, which is reached: closing an entry on a
command that was never run is the failure this repository has a table for.

---

## BSD-02. Whether the other three BSDs can be *run*, not merely built

**Source** Derived from `BSD-01` and the `docker-bsd` work.
**Category** bsd · **Priority** P3 · **Effort** S · **Status** done

### Problem

`docker-bsd` builds images for all four BSDs. Only FreeBSD has a documented OCI
runtime to run them on.

### ⭐ Closed 2026-08-27, with the answer and not with a scope note

⛔ **"Runnable" is two questions and the answer differs between them.** The
entry's original premise conflated them and it is kept, uncorrected, in
[`../HISTORY/bsd-entries.md`](../HISTORY/bsd-entries.md).

| BSD | runnable as an OCI container | runnable as a booted guest |
| --- | --- | --- |
| FreeBSD | ✅ `ocijail`, behind the handbook's `podman-suite`; `runj` as a proof of concept. Needs a FreeBSD host | ✅ Firecracker, QEMU, bhyve, `libkrun`, and upstream `.vhd` and BASIC-CI images |
| NetBSD | ⚠ no jail-equivalent runtime. ⭐ CBSD manages NetBSD from 15.0.6 | ✅ ⭐ smolBSD as a microvm, Firecracker, QEMU, `libkrun` |
| OpenBSD | ❌ none found | ✅ QEMU, through `vmactions` and `anyvm` |
| DragonFly | ❌ none found | ✅ QEMU, through `vmactions` and `anyvm` |

⭐ **So the narrow claim holds and the broad one does not.** Three BSDs have no
jail-equivalent OCI runtime. All four are runnable as guests, and two have been
for years.

### ⚠ What was NOT done

- ⛔ **No BSD was run by this entry.** Every runtime above was established from
  its own repository, its releases and its tracker.
- ⚠ **`ocijail` and `runj` were read, not built.**
- ⚠ **"None found" for OpenBSD and DragonFly is the state of one search** over
  28 references, not a proof that nothing exists.

### ⭐ Prior art already read, by section

| what you are about to do | read |
| --- | --- |
| anything smolBSD-shaped, which is what this repository now ships | ⭐ `usable.md`, the `R7` section. It records `smoler.sh`, a **Dockerfile-shaped builder in which `RUN` works inside the guest**, which is the mechanism `INF-09`'s provisioning step was hand-written without consulting. ⛔ `findings.md`'s `R7` verdict says the tracker holds 83 items and 51 threads and **only two were read** |
| distributing something that boots, rather than a rootfs | ⭐ `usable.md`, `R7`'s registry section: a raw bootable disk pushed to a registry through `oras`. ⚠ It also carries the Windows trap: `oras` writes a **zero-byte file** because a tag contains a colon |
| a shared filesystem between host and guest, which is `IMG-03` | ⛔ `usable.md`'s `honest-limit` row on NetBSD's `mount_psshfs`: it caches attributes for 30 seconds over the page cache and serves short reads under a parallel build, so object files came back `file too short`. **Use NFS or a local disk with copy-back** |
| surveying what FreeBSD OCI images exist | `findings.md`, the `R24` `oci-jails` row: its `CATALOG.md` is a surveyed map of every source |
| claiming a BSD userland cannot run on a Linux kernel | ⛔ `findings.md`, the `R28` `AkihiroSuda/lsf` verdict. **One was built.** It is a dead 2022 proof of concept that crashes, so the conclusion holds and the **reason** this repository publishes for it must not be "nobody has tried" |

### Prove

⭐ **Met.** A per-BSD table naming the runtime and its state, backed by 28
references, in
[`../HISTORY/references/usable.md`](../HISTORY/references/usable.md) and
[`../HISTORY/references/findings.md`](../HISTORY/references/findings.md).
