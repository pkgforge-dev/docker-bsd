# reproducing.md

⭐ **One command per published number.** Every measurement in
[`LIMITS.md`](LIMITS.md) came out of exactly one script in
[`../experiments/`](../experiments/README.md), and this page is the map from the
number back to the command.

⛔ **A mismatch is a finding, not a harness bug.** If a number here does not
reproduce on your machine, that is data about the difference between the two
machines, and it belongs in [`../HISTORY/`](../HISTORY/README.md) rather than in
a quiet edit to `LIMITS.md`.

⚠ **Run the probe first.** [`environment.md`](environment.md) says why, and
records the one machine every published number was taken on.

---

## The map

| the number in [`LIMITS.md`](LIMITS.md) | the command that produced it |
| --- | --- |
| ⭐ a BSD shell in a container, unprivileged | `sh experiments/35-boot-in-container.sh` |
| a FreeBSD userland on the Windows hypervisor, and the boot-phase table | `pwsh -NoProfile -File experiments/33-boot-freebsd-whpx.ps1` |
| a FreeBSD microvm on `/dev/kvm` | `sh experiments/31-boot-freebsd-firecracker.sh` |
| which CPU models wedge the emulator, and the paravirtual-bus column | `pwsh -NoProfile -File experiments/30-boot-smolbsd.ps1 -IncludeTcgControl` |
| the Host Compute System refusal | `pwsh -NoProfile -File experiments/32-boot-hcs.ps1` |
| podman inside the guest, and the kernel panic | `pwsh -NoProfile -File experiments/40-drive-freebsd-podman.ps1` |
| how far the podman client gets | `pwsh -NoProfile -File experiments/41-connect-podman-from-windows.ps1` |
| what this host can do at all | `sh scripts/doctor/doctor.sh`, `pwsh -NoProfile -File scripts/doctor/doctor.ps1` |

⚠ **Two of them fetch first.** `33` and `40` and `41` consume what
`experiments/21-fetch-freebsd-ci.sh` leaves behind; `30` consumes what
`experiments/20-fetch-smolbsd.sh` leaves behind. Both fetch scripts verify a
published digest where upstream publishes one, and say so where it does not.

---

## ⭐ The cheapest one to start with

```bash
sh experiments/35-boot-in-container.sh
```

⛔ **It needs nothing but a container engine**, it fetches what it needs, and it
prints a machine-readable line:

```text
RESULT accel=tcg shell=yes seconds=2.6 answered=yes
```

⚠ **`answered=yes` is the part that matters.** `shell=yes` only says a prompt
appeared; `answered=yes` says commands were run in the guest and their output
was read back. ⛔ A first version of that experiment asserted on a command the
guest does not ship and reported `answered=no` over a guest that was answering
correctly.

---

## ⚠ What will differ on your machine, and is not a defect

| | |
| --- | --- |
| the boot-phase split | ⛔ the 108 seconds of device probing is this hypervisor's cost. A different host may be very different, and that is worth reporting |
| the CPU-model column | ⚠ two published reports disagree with this repository's result on older software and other hardware. [`traps.md`](traps.md) row 6 |
| ⚠ anything on Linux, macOS or arm64 | none of it is measured here at all, so there is nothing to match |
| the first run's wall time | ⚠ it includes fetching hundreds of megabytes. The second run does not |

---

## ⛔ Where the artefacts go

Everything lands in `.tmp/`, which is ignored, and **nothing cleans it up**.

| directory | what | rough size |
| --- | --- | --- |
| `.tmp/freebsd/` | the FreeBSD CI image, compressed and expanded, plus console logs | ⚠ about 6.8 GB |
| `.tmp/smolbsd/` | the NetBSD rescue image, its kernel, and one serial log per attempt | 33 MB |
| `.tmp/incontainer/` | what the container experiment mounts | 33 MB |
| `/var/tmp/fbsd-fc/` inside a Linux machine | the Firecracker kernel and root filesystem | 603 MB |

⚠ **The FreeBSD image is mutated by experiment 40**, which installs packages
into it. A clean measurement needs it expanded again from the compressed copy,
and the fetch script will not do that while the expanded one exists.
