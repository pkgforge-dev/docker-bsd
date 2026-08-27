# TODO: measurement

⭐ **What this repository claims and has not measured.** Every entry here
converts a sentence in [`../docs/LIMITS.md`](../docs/LIMITS.md) that currently
says "not measured" into a number.

[`INDEX.md`](INDEX.md) is the list; [`PROGRESS.md`](PROGRESS.md) is the order.

⛔ **An entry closes with a number, not with a conclusion.** "It seems fine" is
what this file exists to prevent.

---

## PERF-01. What does real work cost inside the guest

**Source** The operator, 2026-08-27: "if so, what performance penalties?"
**Category** measurement · **Priority** P1 · **Effort** M · **Status** open

### Problem

⛔ **Nothing in this repository has measured throughput of any kind.** Every
published number is time-to-a-prompt, and a boot time says nothing about a
compile.

⚠ **The one adjacent number is a warning rather than a guide.** A stock
general-purpose kernel spent **108 seconds** probing devices on one route,
accelerated, which says IO through that path is expensive and does not say what
work costs. ⛔ Extrapolating a compile time from it would be inventing a number.

### Approach

⭐ **One workload, three configurations, one ratio.** The workload is a real
compile of something small and CPU-bound, not a benchmark suite.

| configuration | what it isolates |
| --- | --- |
| on the host directly | the baseline |
| in the guest, with `/dev/kvm` | the cost of virtualisation |
| in the guest, unaccelerated | ⛔ the cost of **interpretation**, which is the case a consumer with no device gets |

⛔ **Report the ratio, not the seconds alone.** Seconds are about the machine;
the ratio is about the route, and the ratio is what transfers.

⚠ **And report IO separately from CPU.** They are the two costs and they are
not the same multiple: the 108-second probe suggests IO is the worse one.

### Prove

A table in [`../docs/LIMITS.md`](../docs/LIMITS.md) with the workload named, the
three wall times, and the two ratios. ⛔ It replaces the section that currently
says this is unknown; it does not sit beside it.

---

## PORT-01. Does route 1 work anywhere other than the one host it was measured on

**Source** The operator, 2026-08-27: "does this work everywhere? even on linux?
even on CI?"
**Category** measurement · **Priority** P1 · **Effort** S · **Status** open

### Problem

⛔ **Route 1 is measured on exactly one path**: a container inside a WSL2 Linux
machine on one Windows laptop.
[`../docs/LIMITS.md`](../docs/LIMITS.md) marks native Linux, CI and macOS as
**inferred**, and arm64 as expected to fail.

⚠ **The inference is reasonable and it is still an inference.** The container is
a Linux container either way, so a native Linux host is the same code path with
one layer removed. Nothing has run it.

### Approach

⭐ **The experiment already exists and takes one command.**
[`../experiments/35-boot-in-container.sh`](../experiments/35-boot-in-container.sh)
needs only a container engine and prints a machine-readable RESULT line.

⛔ **Run it, unchanged, on each host and record the line.** Do not adapt it per
host: if it needs adapting, that difference **is** the finding.

| host | why it matters |
| --- | --- |
| native Linux, `x86_64` | ⭐ the most likely consumer, and the cheapest gap to close |
| GitHub CI, `x86_64` | ⭐ decides whether this can be used in anybody's pipeline |
| macOS, Apple Silicon | ⚠ a container there is already inside a Linux VM, and the guest is `amd64` |
| any arm64 | ⛔ expected to fail. Recording **how** it fails is the point |

⭐ **CI is the one to automate.** A job that runs it on every push turns this
entry into a standing guarantee instead of a one-off measurement.

### Prove

A row per host in [`../docs/LIMITS.md`](../docs/LIMITS.md)'s portability table,
each carrying the RESULT line the experiment printed, ⛔ **and each labelled
measured rather than inferred**, or the row says why it could not run.
