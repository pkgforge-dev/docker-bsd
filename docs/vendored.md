# vendored.md

⭐ **What this repository took from somewhere else, and what it still reaches
for.** One page, so "where did this file come from" is never a `git log`
archaeology exercise.

⛔ **This repository is standalone.** It was developed beside
`Azathothas/ToolKit`, which is the operator's shared tooling tree, and it
borrowed that tree's checks, conventions and methodology while it was being
written. Those are now **copies living here**, and this repository's copy is
the authority for this repository.

---

## ⛔ What that means in practice

| | |
| --- | --- |
| a check in `scripts/common/` behaves differently from ToolKit's | ⭐ **this one is right, here.** They are separate files with separate futures |
| a convention here disagrees with ToolKit's | the same. ⛔ Do not "sync" them |
| a fix is made here that ToolKit would want | ⚠ that is a change **in ToolKit**, made there, by somebody with that repository in front of them |
| a fix is made in ToolKit that this repository would want | ⚠ the same in reverse. ⛔ **A copy does not get updates.** That is the cost of the split and it was paid deliberately |

⚠ **Vendoring was chosen over fetching**, and the reason is the one this
repository exists to serve: an agent or a person should be able to clone this
repository and reproduce every measurement in it with nothing else checked out.
A gate that fetches its own checks from another repository at run time is a
gate that stops working when that repository moves.

---

## What was copied, and from where

Copied on **2026-08-27** from `Azathothas/ToolKit` at commit `260f307`.

| what | where it is now | changed on the way in |
| --- | --- | --- |
| the gate | `scripts/common/check-gate.{sh,ps1}` | ⛔ **yes.** Dropped the template-placeholder check, which has nothing to look for here, and taught both halves to find shell scripts by **shebang** as well as by extension, because `scripts/build-bsd` and `scripts/sources` carry no `.sh` |
| the twin check | `scripts/common/check-twins.sh` | the dropped check removed from its pair list |
| documents, changelog, control bytes, record, secrets | `scripts/common/check-*.{sh,ps1}` | nothing functional |
| the commit and push tool | `scripts/common/git-sync.{sh,ps1}` | nothing functional |
| the record mover, the file writer | `scripts/common/set-record.mjs`, `write-file.mjs` | nothing |
| the host probe | `scripts/doctor/` | nothing |
| conventions, methodology, security | `docs/conventions/`, `docs/methodology/`, `docs/security/` | nothing yet. ⚠ They still describe some things in ToolKit's terms and that is a debt, not a decision |
| the BSD work record | `TODO/bsd.md` | nothing. It moved whole, corrections and all |
| the 28-reference sweep | `HISTORY/references/` | nothing |

---

## ⭐ The one thing this repository still reaches for

⛔ **Exactly one, and it is pinned.**

`scripts/powershell-windows/wsl-ephemeral.ps1` in `Azathothas/ToolKit` creates a
throwaway WSL2 distribution from an OCI image or a rootfs tarball, runs a
command in it, and removes it. ⭐ **It is how a Windows session gets a clean
Linux to run this repository's POSIX scripts in**, without installing a
distribution and leaving it there.

### ⛔ It is the ONLY way a session here builds a Linux on this host

⛔ **Standing rule, set by the operator on 2026-08-28. When work in this
repository needs WSL, it goes through that script.** Not `wsl --install`, not a
distribution somebody registered once and now shares between sessions, not
`wsl.exe -- /bin/sh -lc` typed at a distribution that happened to be there.

⭐ **The reason is that a hand-made distribution is state nobody records.** Every
number this repository publishes is supposed to be reproducible by a stranger,
and a measurement taken inside a distribution whose contents are whatever the
last session left behind is not. An ephemeral distribution is created from a
named image, used, and unregistered, so the next session starts from the same
place this one did.

⚠ **The script's own page is the authority on how to drive it**, and it stands
alone: [`scripts/powershell-windows/wsl-ephemeral.md`](https://github.com/Azathothas/ToolKit/blob/main/scripts/powershell-windows/wsl-ephemeral.md)
in that tree. ⛔ **Read it rather than the source**, and rather than this
section, which says only what bears on this repository.

### ⛔ Three things it does NOT cover, and one of them can break this repository

⚠ **Named because the rule above could be read as "route everything WSL through
it", and two of these are not it.**

| | |
| --- | --- |
| ⛔ **the podman machine is not reached this way** | `podman-machine-default` is a WSL distribution and it is the whole container route. It is driven through `podman`, and the script **refuses it by name**: it is on that script's protected list, so `-Action Remove` cannot take this repository's runtime out |
| ⛔ **`wsl --shutdown` is machine-wide and this repository never runs it** | it is the command a person reaches for after finishing with a throwaway distribution, and it stops **every** distribution including the podman machine. The script never issues it; neither should a session here |
| ⚠ **a distribution's lifetime is not the kernel's** | `--terminate` and `--unregister` replace a userspace. The WSL2 kernel keeps running, so `binfmt_misc` registrations and loaded modules survive into the next distribution. ⛔ **Only `wsl --shutdown` gives a fresh kernel**, which is exactly the command above, so a question about kernel-level state cannot be answered by making a new distribution. `scripts/common/check-binfmt.sh` is the check that would read stale state |

### Fetching it

```bash
COMMIT=260f307
curl -fsSL -o wsl-ephemeral.ps1 \
  "https://raw.githubusercontent.com/Azathothas/ToolKit/$COMMIT/scripts/powershell-windows/wsl-ephemeral.ps1"
```

⛔ **Fetch by raw URL at a pinned commit, never from a local clone**, and verify
the digest. A working tree on Windows is CRLF and its digest is not the one
`raw.githubusercontent.com` serves. ⛔ **And never pipe the download into a
shell**: a truncated transfer executes the prefix and leaves nothing to inspect.

⚠ **It is not vendored, and that is deliberate**: it is 1,579 lines whose whole
subject is Windows and WSL quoting, it is actively maintained in that tree, and
nothing in this repository's gate depends on it. ⚠ **So the rule above is about
how a session works, not about what a measurement depends on**: no number here
is produced by that script, and a clone with no network still reproduces every
one of them.

⚠ **Two things to know before using it**, both measured in that tree and both
still true:

- ⛔ **From a script, pass `-CommandB64` rather than `-Command`.** Windows
  PowerShell 5.1 drops a double quote when it builds a child process's argument
  list, so a 5.1 caller that passes `-Command` loses characters. It is the same
  trap [`conventions/shell.md`](conventions/shell.md) section 7 records from
  this side.
- ⚠ `-TimeoutSeconds` bounds the script's own questions to the distribution. It
  does **not** bound `-Command`, so a build that runs for an hour is not killed
  at two minutes.

---

## ⚠ What is NOT taken, and why

⛔ Recorded so the question is not reopened every time somebody reads ToolKit's
`scripts/` directory.

| script | why not |
| --- | --- |
| `check-placeholders` | it catches a template placeholder surviving into a real file. This repository was not generated from a template |
| `check-remote-items` | it verifies what an open issue asserts about pins and tags. There is no tracker traffic here yet |
| `check-binfmt` | ⚠ **copied but not gated.** It answers whether `binfmt_misc` handlers are really registered, which is irrelevant to a BSD image (that fails with a SIGSEGV, not `Exec format error`) and becomes relevant the day this repository cross-builds for a foreign architecture |
| `docs/templates/` | skeletons for a new repository. This one exists |

---

## ⚠ The debt this page exists to name

⛔ **The copied documents still speak in ToolKit's terms in places.** A path, an
entry id, or an example that names that tree rather than this one is a bug in
this repository's documentation, not a cross-reference.

⭐ **Report it the way [`AGENTS.md`](AGENTS.md) says to report any
convention breach**: name the file and the line, say what it should say, and
offer. ⚠ There is no gate for this one, because a check that recognised
"a sentence written about the wrong repository" would be a check nobody could
write honestly.
