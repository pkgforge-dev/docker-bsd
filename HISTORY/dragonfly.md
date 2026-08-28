# dragonfly.md

⛔ **DragonFly BSD was one of this repository's four targets and is not any
more.** Ruled out by the operator on **2026-08-28**:
[`../TODO/RULES.md`](../TODO/RULES.md) decision 7.

⭐ **This file exists so the removal is a decision with evidence rather than a
gap.** Everything below was measured on 2026-08-27, worked, and was deleted
from the live tree on 2026-08-28. ⚠ **The next person to ask "why not
DragonFly" gets the measurement, not a shrug.**

⛔ **Append, never edit**, like everything else here.

---

## Why it was dropped

⚠ **Not because the route failed.** The route worked and is written out below.
The reasons are:

1. ⛔ **It is the least maintained of the four**, in the operator's judgement,
   and the other three are what people actually target.
2. ⚠ **It was the only one needing a third acquisition method**, so it carried
   a whole code path, a tool dependency and a test branch on its own.
3. ⚠ **It was never built end to end.** The method was verified by reading a
   signature; the 748 MB extraction was never run.

---

## ⭐ What was learnt about it, and it is worth keeping

### ⛔ The disk image is a dead end on any Linux host

DragonFly publishes **no set tarballs at all**, only `.img` and `.iso`. The
`.img` root filesystem is **HAMMER2**, and Linux has no driver for it, so no CI
runner can mount it. ⛔ **That closes the obvious route**, which is what every
other BSD here uses.

### ⭐ The ISO is ISO9660 and any host can read it

Confirmed by reading the **`CD001` signature at offset 32769**, which is the
ISO9660 primary volume descriptor. So `bsdtar` or `7z` reads it anywhere, with
no BSD and no kernel support.

### ⚠ Three traps the route hit, all of which generalise

- ⭐ **Accept either reader.** CI runners get `bsdtar` from `libarchive-tools`;
  this developer's Windows machine has `7z` and no `bsdtar`. ⛔ Requiring one
  would make the script unrunnable on a machine that can do the job.
- ⛔ **Bare filenames, run from the working directory.** `7z` is a native
  Windows binary and hits the same path-translation problem `curl` and `podman`
  do. [`../docs/conventions/shell.md`](../docs/conventions/shell.md) section 7.
- ⛔ **Normalise ownership to root when repacking.** An ISO carries no useful
  uid, and a tar holding a build machine's uid is what rootless podman refuses
  with `potentially insufficient UIDs or GIDs available in user namespace`.
  Measured on the first attempt.

---

## The code, as it was deleted

⭐ **Kept so it can be restored rather than rewritten**, if anybody ever
reverses the decision. ⚠ **One character-level change**: the section banner was
a row of box-drawing characters, which this repository's document check refuses
outside a script. The code is otherwise byte for byte.

```sh
# DragonFly: no sets exist, and the disk image is HAMMER2
build_iso() {
  _reader=""
  if command -v bsdtar >/dev/null 2>&1; then _reader="bsdtar"
  elif command -v 7z >/dev/null 2>&1; then _reader="7z"
  elif command -v 7zz >/dev/null 2>&1; then _reader="7zz"
  else
    printf 'build-bsd: dragonfly needs bsdtar or 7z to read ISO9660\n' >&2
    printf '  ubuntu:  apt-get install -y libarchive-tools\n' >&2
    printf '  windows: scoop install 7zip\n' >&2
    exit 2
  fi
  printf 'build-bsd: reading the ISO with %s\n' "$_reader" >&2

  _u=$(sh "$SOURCES" --urls dragonfly)
  _iso=$(fetch "$_u") || exit 1
  _isoname=$(basename "$_iso")

  _root="$WORK/root"
  mkdir -p "$_root"
  if [ "$_reader" = "bsdtar" ]; then
    ( cd "$WORK" && bsdtar -xf "$_isoname" -C root ) || {
      printf 'build-bsd: could not extract the ISO with bsdtar\n' >&2; exit 1; }
  else
    ( cd "$WORK" && "$_reader" x -y -oroot "$_isoname" >/dev/null ) || {
      printf 'build-bsd: could not extract the ISO with %s\n' "$_reader" >&2; exit 1; }
  fi

  ( cd "$_root" && tar --owner=0 --group=0 --numeric-owner -cf "$WORK/rootfs.tar" . ) || {
    printf 'build-bsd: could not repack the root filesystem\n' >&2; exit 1; }

  LOADED="localhost/${BSD}-import:$$"
  ( cd "$WORK" && "$ENGINE" import --os dragonfly --arch "$ARCH" \
      --change 'CMD ["/bin/sh"]' \
      "rootfs.tar" "$LOADED" ) >/dev/null 2>&1 || {
      printf 'build-bsd: import failed\n' >&2; exit 1; }
  TAG="${VERSION}-base"
}
```

The matrix rows that went with it:

```sh
DRAGONFLY_VERSION="6.4.2"
DRAGONFLY_BASE="https://mirror-master.dragonflybsd.org/iso-images"
# method:  dragonfly) printf 'iso\n' ;;
# urls:    printf '%s/dfly-x86_64-%s_REL.iso\n' "$DRAGONFLY_BASE" "$DRAGONFLY_VERSION"
```

---

## ⚠ One thing the reference sweep says about it, and it is not flattering

⛔ **`cross-platform-actions/action` supports a DragonFly guest and had to mask
a CPU feature specifically for it.** Some AMD GitHub runners report STIBP
always-on without the STIBP and IBRS bits that normally accompany it; DragonFly
writes `IA32_SPEC_CTRL` when it sees the always-on bit, and KVM answers that
write with a general protection fault.
[`references/usable.md`](references/usable.md), the `R31` section.

⚠ **That is one more platform-specific fault to carry**, and it is the kind of
cost this decision is about.
