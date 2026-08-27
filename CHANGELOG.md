# CHANGELOG.md

What shipped, when, and where the evidence is. One entry per shipped unit of
work, pointing at the record that carries the detail.

Four rules, and
[`scripts/common/check-changelog.sh`](scripts/common/check-changelog.sh) holds
all four:

1. ⛔ **Newest first.** A new entry goes at the top of its section.
2. ⛔ **Every heading carries a date**, as an ISO 8601 UTC stamp.
3. ⛔ **Every entry names its record**, the entry or commit carrying the
   evidence.
4. ⛔ **Every entry says whether it deployed.** "No deploy" is a complete and
   common answer. Silence is not.

⛔ Do not tidy this file while shipping something else, and do not delete an
entry. A superseded one is amended in place with a dated note.

---

## 2026-08-27

### 2026-08-27T15:10:00Z: this repository became standalone, and a BSD boots in a container

**Record:** [`TODO/SUMMARY.md`](TODO/SUMMARY.md) is the brief;
[`docs/LIMITS.md`](docs/LIMITS.md) carries every measurement; `BSD-01` in
[`TODO/bsd.md`](TODO/bsd.md) carries the entry and its five corrections.
**Deployed:** ⛔ **no deploy.** No image was published in this change.

⚠ **`main` is one root commit from here.** Everything before it was development
history in another repository's shadow, and the split is the reason.
[`docs/vendored.md`](docs/vendored.md) records what was copied, from where, and
what changed on the way in.

- ⭐ **A BSD shell inside an unprivileged container in a couple of seconds**,
  with no acceleration, no `/dev/kvm`, no capabilities and no emulator on the
  host, because the emulator ships inside the image. ⛔ **The route is measured
  and not yet packaged**, which is the highest-value open task. The timing is in
  [`docs/LIMITS.md`](docs/LIMITS.md) and nowhere else.
- ⭐ **A full FreeBSD 15.1 userland on a Windows host's own hypervisor**,
  unelevated, with no nesting, and a container running inside it on `ocijail`.
- ⛔ **A long-running Go daemon panics that guest's kernel** in `_umtx_op`, so
  the podman client cannot reach it yet. Everything underneath that works.
- ⛔ **Nine experiments**, each committed with its result, including the two
  that failed, the one that reported a false success, and an explanation that
  was published and withdrawn in the same session.
- ⭐ **The gate, the conventions, the methodology and the record are this
  repository's own**, adapted rather than fetched, so a clone reproduces every
  measurement with nothing else checked out.

⚠ **What is deliberately still missing**, and is in
[`docs/LIMITS.md`](docs/LIMITS.md) rather than hidden: no published image boots
itself, no Linux host was measured, no arm64 anything, and no steady-state
performance number exists for any route.
