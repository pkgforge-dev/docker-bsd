# PROMPT.md

⭐ **What to paste to a fresh agent with no memory of this repository.**

⛔ **It is deliberately brief, and that is the design.** The repository is the
orientation. A prompt that restates the work order is a second copy of it going
stale, and it spends the next session's budget on something it is about to read
anyway.

⚠ **This is not a session handoff.** A handoff names what one session left
unfinished and is printed in chat, never written to a file. This page is
generic: it says the same thing in six months.

---

## The prompt

```text
You are working in pkgforge-dev/docker-bsd, cloned locally.

It builds OCI images for FreeBSD, NetBSD, OpenBSD and DragonFly BSD, and works
on the harder half: running one. A BSD userland needs a BSD kernel, so the
repository also holds the measured routes from an ordinary host to a booted BSD.

Read, in this order, in full:

  docs/AGENTS.md      the router, and the only agent entry point. Read it first
                      and follow the row for the task you are given.
  TODO/SUMMARY.md     the brief: what the last session did, and what it did NOT
                      measure. Read every line, including the last section.
  TODO/PROGRESS.md    the only file carrying a work order. Rewrite it at the
                      start and at the end of your session.
  TODO/INDEX.md       the entry list, and the counts a gate checks.
  docs/LIMITS.md      what this project cannot do yet, with every measurement.
                      Nothing else in the repository carries those numbers.

Then run the host probe, because a different machine changes what you can prove:

  sh scripts/doctor/doctor.sh
  pwsh -NoProfile -File scripts/doctor/doctor.ps1

Before you push, both of these, and read each exit code unpiped:

  sh scripts/common/check-gate.sh --fast
  sh tests/run.sh

Four things this repository will not bend on, each explained in docs/AGENTS.md:
  a negative result is a result and gets committed;
  measured, or labelled, never estimated, and a correlation is not a cause;
  one fact, one home, so no measured number appears in two documents;
  read every exit code from the process that produced it, unpiped.

You have no permissions beyond reading and running local commands unless the
operator pastes the permissions block in docs/HUMANS.md. If they pasted nothing,
the answer to every line in it is no.
```

---

## ⚠ What to change before pasting it

⛔ **Two things, and only if they are true.**

| | |
| --- | --- |
| the operator wants the agent to act on a remote | paste the permissions block from [`../../docs/HUMANS.md`](../../docs/HUMANS.md), edited, and nothing less specific |
| the session has a task already chosen | name it by its id, and say so. ⚠ Otherwise the agent takes the work order from [`../../TODO/PROGRESS.md`](../../TODO/PROGRESS.md), which is what it is for |

⛔ **Do not add the work order, the entry list, the counts, the check results or
a version number.** All of those live in the tree, they are read first anyway,
and a copy of them here is a copy that will be wrong.
