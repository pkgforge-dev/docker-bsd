# conventions

⭐ **How work is written here.** Six pages, each about one thing, each binding.
[`../AGENTS.md`](../AGENTS.md) routes a task to the ones it needs; this page is
the index, and it restates none of them.

⛔ **A convention with no incident behind it is a preference**, and preferences
stated as rules are what make somebody stop believing the rules that matter.
Every page here earned its rows.

---

| page | what it governs | ⛔ the one rule that gets broken most |
| --- | --- | --- |
| [`forbidden-patterns.md`](forbidden-patterns.md) | mistakes that actually shipped, each paired with what it caused | ⛔ grep yourself against it **before** declaring a gate green |
| [`shell.md`](shell.md) | crossing a shell, quoting, and the Windows traps | ⛔ read every exit code from the process that produced it, unpiped |
| [`prose.md`](prose.md) | how a sentence in this repository is allowed to claim something | ⛔ measured, or labelled. Never estimated |
| [`docs.md`](docs.md) | where a fact lives, and how documents link | ⛔ one fact, one home. No measured number in two places |
| [`code.md`](code.md) | how a script is written and what it must assert | ⛔ a guard never seen to fail is theatre |
| [`git.md`](git.md) | commits, branches, and what a message may say | ⛔ no tool is credited, ever |

---

## ⭐ The four that apply to everything

⚠ Restated here **only** as pointers, because they cut across every page above
and somebody reading one page should not miss them.

1. ⛔ **Read the exit code from the process that produced it.**
   [`shell.md`](shell.md). `cmd | tail` then `$?` is `tail`'s status, so a
   guard that failed reads as green. It shipped here twice.
2. ⛔ **Measured, or labelled.** [`prose.md`](prose.md). A number on a report
   that was nobody's measurement is worse than a blank, because a blank gets
   checked. ⚠ **And a correlation is not a cause**: this repository published
   one tidy explanation and withdrew it inside the same session.
3. ⛔ **One fact, one home.** [`docs.md`](docs.md). A value in two documents is
   a value that will disagree with itself, and the copy a reader trusts is the
   wrong one.
4. ⛔ **A negative result is a result.** [`code.md`](code.md). The experiment
   that failed here is the reason the next one worked.

---

## ⚠ These are copies, and they are this repository's own

They came from `Azathothas/ToolKit` on 2026-08-27 and were adapted.
[`../vendored.md`](../vendored.md) records what changed on the way in and what
did not. ⛔ **This copy is the authority here.** Do not sync it back, and do not
sync it forward.

⚠ **They still speak in that tree's terms in places**, which is a debt named in
[`../vendored.md`](../vendored.md) rather than a cross-reference.
