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
total 2  open 1  blocked 0  done 1
```

| priority | open | blocked | done | total |
| --- | --- | --- | --- | --- |
| P0 | 0 | 0 | 0 | 0 |
| P1 | 1 | 0 | 0 | 1 |
| P2 | 0 | 0 | 0 | 0 |
| P3 | 0 | 0 | 1 | 1 |
| **all** | **1** | **0** | **1** | **2** |

---

## Entries

| id | pri | eff | status | title | file |
| --- | --- | --- | --- | --- | --- |
| BSD-01 | P1 | M | open | Run a BSD userland from Windows, with the least friction that works | [`bsd.md`](bsd.md) |
| BSD-02 | P3 | S | done | Whether the other three BSDs can be run, not merely built | [`bsd.md`](bsd.md) |

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

---

## ⭐ The argument behind the current ordering

Written down so a later session can re-derive it rather than re-argue it.

**`BSD-01` is the only open entry and it is the whole project.** Everything this
repository publishes exists so that entry can close: images nobody can run are
an artefact, not a product. Its purpose is met and its acceptance command is
not, and [`PROGRESS.md`](PROGRESS.md) carries the distance between those two.

⚠ **`BSD-02` is done and stays listed.** It closed with a written answer per
BSD rather than by running anything, and it is the reason this repository knows
that three of its four images have no runtime to run on.

⛔ **This list is deliberately short, and that is a state rather than a
target.** [`../docs/LIMITS.md`](../docs/LIMITS.md) is the honest account of what
does not work yet; entries get filed from it, with a measurement attached,
rather than from anybody's idea of what ought to be done.
