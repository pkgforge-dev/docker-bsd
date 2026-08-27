# Review 4: a consumer who read only the limits page

⭐ **The lens.** Somebody deciding whether to use this at all. They read
[`../../docs/LIMITS.md`](../../docs/LIMITS.md), they read nothing else, and they
are asking one question: **will this waste my afternoon?**

⛔ **They are the reader most likely to be misled by a true sentence**, because
a page of honest measurements can still add up to a false impression.

**Run** 2026-08-27.

---

## ⛔ What it found

### 1. ⛔ The page led with its best number and buried its worst answer

The short-answer table at the top gives a time-to-a-shell. ⚠ **Everything that
makes that number less useful was further down**: that it is NetBSD rather than
FreeBSD, that the userland is a rescue shell with no package manager, that the
usual container flags do not reach the guest, and that nothing persists.

⛔ **A reader who stops after the table concludes something false**, and stopping
after the table is what a reader deciding whether to bother actually does.

⭐ **Fixed** by adding a section directly under it that answers the five
questions such a reader asks, in their words, with three of the five answers
being "no" or "not measured".

### 2. ⛔ "It works" was doing the work of "you can use it"

Every claim on the page was true. ⚠ **The page still implied a working
development environment**, because it never said that a compiler cannot be
installed and that no throughput of any kind has been measured.

⭐ **Fixed and filed.** The page now says it is a demonstration and names what
would make it real; `IMG-02` and `PERF-01` carry the work.

### 3. ⚠ Portability was stated as if measured

The routes table read as a description of what works, without distinguishing
the one path actually run from the several inferred from it.

⭐ **Fixed.** Native Linux, CI and macOS are labelled **inferred**, arm64 is
labelled expected-to-fail, and `PORT-01` is the entry that closes it with one
command per host.

---

## ⭐ What it checked and found sound

| | |
| --- | --- |
| is every number traceable | ⭐ yes, each names the experiment that produced it |
| is the machine stated | ⭐ yes, once, and only once |
| are closed routes explained rather than omitted | ⭐ yes, with the measurement that closed each |
| is the hard blocker stated plainly | ⭐ yes, with the kernel stack that produces it |
| is a withdrawn explanation still visible | ⭐ yes, under the claim rather than over it |
| does anything read as a promise | ⚠ the top table did. That was finding 1 |

---

## ⛔ What this review did NOT look at

- **It did not verify a single number.** That was Review 1's lens, and a number
  wrong at the source would pass here.
- ⛔ **It did not test the page on an actual stranger.** Every finding is one
  reader imagining another, which is the weakest evidence in this directory.
- ⚠ **It did not check the README against the limits page.** Two documents
  describing the same routes to two audiences is exactly where an
  over-claim survives, and nothing has compared them line by line.
- **It did not consider a consumer who wants the OCI images rather than a
  shell.** Three of the four have no runtime at all, and that is stated in the
  README rather than in the limits page.
