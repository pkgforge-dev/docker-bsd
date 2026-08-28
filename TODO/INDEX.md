# INDEX.md

Every entry, one line each, sorted by id. This is a **list**, not a log and not
an order. ⛔ The work order lives in [`PROGRESS.md`](PROGRESS.md) and nowhere
else.

⛔ **The counts below are checked, not typed.**
`scripts/common/check-record.sh` asserts that they agree with the rows, that
every row has an entry and every entry a row, and that no status disagrees
between the two. It runs as a gate.

---

## Counts

```text
total 22  open 20  blocked 0  done 2
```

| priority | open | blocked | done | total |
| --- | --- | --- | --- | --- |
| P0 | 1 | 0 | 1 | 2 |
| P1 | 12 | 0 | 0 | 12 |
| P2 | 7 | 0 | 0 | 7 |
| P3 | 0 | 0 | 1 | 1 |
| **all** | **20** | **0** | **2** | **22** |

---

## Entries

| id | pri | eff | status | title | file |
| --- | --- | --- | --- | --- | --- |
| BSD-01 | P1 | M | open | Run a BSD userland from Windows, with the least friction that works | [`bsd.md`](bsd.md) |
| BSD-02 | P3 | S | done | Whether the other three BSDs can be run, not merely built | [`bsd.md`](bsd.md) |
| IMG-01 | P0 | L | done | `podman run --rm -it <image> sh` drops you in a BSD | [`images.md`](images.md) |
| IMG-02 | P0 | L | open | A real userland in it, not a rescue shell | [`images.md`](images.md) |
| IMG-03 | P1 | M | open | The flags a consumer already knows must reach the guest | [`images.md`](images.md) |
| INF-01 | P2 | M | open | Every published image carries provenance and an evidence file | [`infrastructure.md`](infrastructure.md) |
| INF-02 | P2 | S | open | Upstream moving is noticed by a bot, not by a person | [`infrastructure.md`](infrastructure.md) |
| INF-03 | P2 | S | open | A test that is seen to fail | [`infrastructure.md`](infrastructure.md) |
| INF-04 | P1 | M | open | Publish the artefacts themselves, not only images | [`infrastructure.md`](infrastructure.md) |
| INF-05 | P1 | L | open | CI that tests the permutations, and publishes only when all pass | [`infrastructure.md`](infrastructure.md) |
| INF-06 | P1 | M | open | Survive an upstream changing its mind | [`infrastructure.md`](infrastructure.md) |
| INF-07 | P1 | M | open | The consumer-facing documents read like a manual | [`infrastructure.md`](infrastructure.md) |
| INF-08 | P1 | S | open | The shared console driver returns the right answer late | [`infrastructure.md`](infrastructure.md) |
| INF-09 | P2 | M | open | Provisioning the guest costs more than everything else in the build | [`infrastructure.md`](infrastructure.md) |
| INF-10 | P1 | S | open | `Console.send()` blocks forever on a guest that stopped reading | [`infrastructure.md`](infrastructure.md) |
| OPT-01 | P2 | M | open | The allocator, because the default one is slow | [`performance.md`](performance.md) |
| OPT-02 | P2 | L | open | An emulator image built to do one thing | [`performance.md`](performance.md) |
| OPT-03 | P2 | L | open | Is a virtual machine even the right shape | [`performance.md`](performance.md) |
| PERF-01 | P1 | M | open | What does real work cost inside the guest | [`measurement.md`](measurement.md) |
| PERF-02 | P1 | L | open | Two users, one program, one matrix | [`performance.md`](performance.md) |
| PERF-03 | P1 | L | open | Be within 5 percent. It is a hard gate. | [`performance.md`](performance.md) |
| PORT-01 | P1 | S | open | Does route 1 work anywhere other than the one host it was measured on | [`measurement.md`](measurement.md) |

---

## Writing a new entry

⭐ Start from [`../docs/templates/todo-entry.md`](../docs/templates/todo-entry.md)
and read [`../docs/methodology/authoring.md`](../docs/methodology/authoring.md)
first. ⛔ An entry filed from an opinion rather than a measurement is how a
backlog stops meaning anything; [`../docs/LIMITS.md`](../docs/LIMITS.md) is
where the measurements are.

---

## Priorities and effort

Defined once, here, and meant.

| priority | means |
| --- | --- |
| P0 | breaks correctness, loses data, or takes the process down |
| P1 | a documented capability does not work, or a flag does nothing |
| P2 | worth doing; nothing is wrong without it |
| P3 | worth recording so it is not rediscovered |

| effort | means |
| --- | --- |
| S | under a day |
| M | a few days |
| L | a week |
| XL | ⚠ almost always two entries pretending to be one |

⚠ **The effort figures on the `L` rows are estimates and nothing more.** No
entry here has been attempted, so none of them is calibrated.

---

## ⭐ The argument behind the current ordering

Written down so a later session can re-derive it rather than re-argue it.

⛔ **`IMG-01` and `IMG-02` are the only P0s.** This repository's purpose is that
somebody can run a BSD. It publishes images nobody can run, and it has
**measured** a route that works and not packaged it. ⚠ That gap between "we
proved it" and "you can use it" is invisible from the inside, because everything
here works.

⭐ **`IMG-01` before `IMG-02`.** The first is the promise in one command; the
second is that promise being worth keeping. ⛔ Reversing them builds a
development environment nobody can start.

### ⭐ Then the three that decide whether the project deserves to exist

⛔ **`PERF-02` and `PERF-03` are the entries that can end this project**, and
that is why they are written with an explicit bar rather than an aspiration.
A developer who can cross-compile on their own machine has an alternative; if
this costs materially more than that alternative, it is a convenience with a
tax. ⚠ `PERF-01` is the smaller version of the same question and comes first
only because it is cheaper.

⚠ **The `OPT-*` entries are P2 and are not optional**, which is a contradiction
worth stating plainly. They are the levers `PERF-03` will pull. ⛔ They are P2
because pulling a lever before `PERF-02` says which one is stuck is how a month
is spent for nothing.

### ⚠ Then keeping it alive

⛔ **`INF-04` through `INF-07` are P1**, above the older `INF-01` to `INF-03`,
because each closes a gap a consumer meets rather than one a maintainer meets:
no registry-free route, no proof any guest boots anywhere, no resilience to an
upstream moving, and documents that read as a biography.

⚠ **`BSD-01` stays P1 and is no longer the headline.** The container route
overtook it: more hosts, less privilege, faster to a shell. ⛔ It stays open
because its acceptance command has not returned 0, and because
full-BSD-with-real-container-interop is still the strongest end state.

⛔ **`PORT-01` is the cheapest entry in this file and is not first.** One
command per host. It is below the images only because a route nobody can consume
is not made more useful by knowing it also works elsewhere.
