# Review 6: an air-gapped consumer

⭐ **The lens.** Somebody on a machine with no route to a registry and, often,
no route to the internet at all. They can carry files in. They want a BSD.

⛔ **They are the reader this project currently has nothing for**, and that was
not visible until somebody asked.

**Run** 2026-08-27.

---

## ⛔ What it found

### 1. ⛔ Every route documented here begins with a network fetch

| route | what it fetches first |
| --- | --- |
| the container route | a base image, then an emulator package, then a kernel and a root filesystem |
| the Windows route | a 666 MB disk image |
| the microvm route | a kernel, a root filesystem and a binary |

⛔ **There is no documented way to obtain any of it as a file and carry it in.**
Filed as `INF-04`, P1.

### 2. ⚠ The published images are the only artefact, and they are the least useful one

This repository publishes OCI images to a registry. ⛔ For three of the four
BSDs nothing can run one, and for an air-gapped consumer the registry is the
problem rather than the format.

⭐ **The artefacts that would actually help are the ones not published**: the
root filesystems, a bootable disk, an ISO, and the images as loadable files.

### 3. ⚠ A checksum exists for some things and is not published for others

The build path verifies FreeBSD's digest against an upstream checksum file.
⚠ **Nothing this repository itself publishes carries a digest a consumer can
check after carrying it across an air gap.** That is half of `INF-04` and all of
why it says "each with a checksum file".

---

## ⭐ What it checked and found sound

| | |
| --- | --- |
| does the boot need a network once the pieces are local | ⭐ **no.** Measured: the container run needs nothing after the artefacts are cached |
| is the verification step skippable | ⭐ no, and there is deliberately no flag for it |
| would a loaded image behave differently | ⚠ unknown, and not claimed either way |

---

## ⛔ What this review did NOT look at

- ⛔ **It did not test anything air-gapped.** No network was actually removed.
  Every finding is read off the documented steps, and a step that quietly needs
  the network at a moment nobody noticed would pass this review.
- **It did not consider signature verification**, which an air-gapped consumer
  wants more than most: they cannot re-fetch to compare.
- **It did not size the artefacts.** "Carry it in" is easy at 30 MB and a
  different conversation at 6 GB, and both exist here.
