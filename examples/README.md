# examples

⭐ **Runnable.** Each one is a script you can execute, not a snippet to adapt.
They are numbered in the order somebody meets them, and each says at the top
what it needs and what it will cost.

⛔ **They carry no measurements.** Every number lives in
[`../docs/LIMITS.md`](../docs/LIMITS.md), which is the only page with them.
An example that printed its own timing would be a second copy of a number, and
the copy a reader trusts is the wrong one.

⚠ **These are not the experiments.** [`../experiments/`](../experiments/README.md)
is where a question gets answered and a result gets recorded. This directory is
where somebody who just wants the thing to work starts.

---

| example | what it does | what it needs |
| --- | --- | --- |
| [`01-bsd-shell-with-only-podman.sh`](01-bsd-shell-with-only-podman.sh) | ⭐ **a BSD shell, from a host with nothing but a container engine** | podman or docker |
| [`02-pull-a-published-image.sh`](02-pull-a-published-image.sh) | pulls one of the images this repository publishes and reads back what it declares | podman or docker |
| [`03-what-can-this-host-do.sh`](03-what-can-this-host-do.sh) | asks this machine which routes are open to it, and says why the others are not | nothing |

---

## ⛔ The one that will not work, and why it is here

```bash
podman run --rm -it ghcr.io/pkgforge-dev/freebsd:latest sh
```

⛔ **That exits 139 on any Linux host**, a SIGSEGV, and no flag fixes it. The
Linux kernel accepts the binary and it dies on its first syscall, because the
syscall ABI is a different operating system's.

⭐ **[`01-bsd-shell-with-only-podman.sh`](01-bsd-shell-with-only-podman.sh) is
what that command should have been**, and making it that command is the
highest-value open task in this repository. ⚠ Until then the example is a
script, not a tag.

---

## ⚠ What running these will leave behind

⛔ Nothing cleans up after you.

| | |
| --- | --- |
| container images pulled | ⚠ hundreds of megabytes. `podman image rm` them |
| the scratch directory | `.tmp/`, ignored by git, and it is where the guests and their disks land |

⚠ **And one trap worth knowing before you pull anything**: pulling a BSD image
retags the shared local name, so a later unqualified pull of the same name is a
no-op that serves the BSD copy. Name the variant on every fetch, or remove the
image afterwards. [`02-pull-a-published-image.sh`](02-pull-a-published-image.sh)
does the second.
