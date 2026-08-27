# Review 8: somebody who runs the published image and nothing else

⭐ **The lens.** A developer who read one line of the README, ran it, and now
has a shell. They never open this repository again. Everything they will ever
learn about this project, they learn from the image's behaviour.

**Run** 2026-08-28, over `ghcr.io/pkgforge-dev/netbsd:latest` and the tree that
built it.

---

## What it swept

The published image's observable behaviour: what a consumer types, what comes
back, what fails and how the failure reads. Specifically
[`../../images/netbsd/entrypoint.sh`](../../images/netbsd/entrypoint.sh),
[`../../images/netbsd/guest.py`](../../images/netbsd/guest.py), and the four
commands a person actually types at a new image.

---

## ⛔ What it found

### 1. ⛔ `podman run IMAGE ls` runs `ls` in the guest, and the guest has no `ls`

`command_from` treats any argument list that is not a bare shell name as a
command for the GUEST. On the rescue variant the guest is a 20 MB rescue
userland, so `ls`, `cat`, `uname` and `echo` mostly do not exist.

⚠ **What the consumer sees** is the guest's own `not found`, followed by a
non-zero exit that is faithfully propagated. That is correct behaviour and it
reads as a broken image, because nothing says which userland they are in.

⭐ **It is not a defect in the code.** It is a documentation gap and it belongs
to `INF-07`, which is about pages that read like a manual. ⛔ **Filed rather
than patched**, because the fix is a sentence in the README and not a change to
what the entrypoint does.

### 2. ⚠ The diagnostics on stderr are the only thing that says a VM is involved

`netbsd: shell after 2.0s, accel=tcg` goes to stderr on every run. ⭐ **That is
the right stream** and it is the only signal a consumer gets that they are
talking to a virtual machine rather than a container.

⚠ **A consumer who redirects stderr sees nothing at all** for three seconds and
then an answer. There is no defect here; it is worth knowing that the project's
only self-description at run time is one line that many callers throw away.

### 3. ⛔ A consumer who installs a package loses it, and nothing says so

On the build variant, `pkg_add` works. With `--rm`, the installed package is
gone. With no `--rm` it survives in that container and not in the next one.

⛔ **That is ordinary container behaviour and it is NOT ordinary for a
development environment**, which is what the build variant advertises itself
as. The compiler is baked in for exactly this reason, and a consumer who adds a
second package will meet the same wall with no warning.

⚠ **It is the reason `IMG-03` exists.** Until a host directory reaches the
guest, nothing a consumer makes inside it comes out.

### 4. ⭐ The failure modes that were checked and are correct

| what a consumer does | what happens |
| --- | --- |
| `sh -c 'exit 3'` | ⭐ the container exits 3. Proved in CI, and the guard was seen to fail |
| `--network none` | ⭐ the same shell. Nothing is fetched at run time |
| passes no `-i` | ⚠ the guest boots and the console has no input. It hangs until killed |
| `--device /dev/kvm` on a host where it cannot be opened | ⭐ falls back to emulation and says so on stderr |

⛔ **The `-i` row is the one that will generate an issue.** It is documented as
required and a consumer who omits it gets a hang rather than a message. Nothing
in the entrypoint can distinguish "no stdin" from "stdin that has not spoken
yet", so the honest options are a timeout or a note in the manual, and neither
is written today.

---

## ⚠ What this review did NOT look at

- ⛔ **Anything about performance under load.** It ran single commands. The
  whole of `PERF-01` to `PERF-03` is outside this lens.
- ⛔ **The build variant's compiler.** At the time of this review the
  provisioned image had not finished building, so `gcc` inside it is unproved
  by this reader.
- ⛔ **Any host other than the one Windows laptop and the CI runner.**
  `PORT-01`.
- ⚠ **The interactive path with a real terminal.** It was exercised with a
  pipe, which is not the same thing: a pipe cannot test line discipline, echo
  or a control character reaching the guest.
- ⚠ **arm64.** The artefacts are amd64 and no arm64 host was available.
