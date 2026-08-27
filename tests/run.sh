#!/bin/sh
# run.sh - the static test suite.
#
# ⛔ NOTHING HERE BUILDS AN IMAGE AND NOTHING HERE RUNS ONE. Running a BSD image
# needs a BSD kernel, which no runner has; a test that claimed to would be
# theatre. These check the things that can be true or false without a kernel:
# the scripts parse, the matrix is coherent, and the documents agree with the
# tree.
#
# Usage:  sh tests/run.sh
# Exit codes: 0 all passed, 1 something failed, 2 could not run.
#
# ⛔ Read the exit code from this process, unpiped.

set -u

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH='' cd -- "$HERE/.." && pwd)
cd "$ROOT" || { printf 'run: cannot enter %s\n' "$ROOT" >&2; exit 2; }

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

printf 'static tests\n'

# ── every script parses and is executable ───────────────────────────────────
for f in scripts/*; do
  [ -f "$f" ] || continue
  if sh -n "$f" 2>/dev/null; then ok "parses: $f"; else bad "does not parse: $f"; fi
done

# ── sources is internally coherent ──────────────────────────────────────────
IDS=$(sh scripts/sources --list 2>/dev/null)
if [ -z "$IDS" ]; then
  bad "sources --list produced nothing"
else
  ok "sources lists: $(printf '%s' "$IDS" | tr '\n' ' ')"
fi

# ⛔ Every id must answer every question. A id that has a method and no URL is
# the shape that fails at 3am in a scheduled run rather than here.
for id in $IDS; do
  m=$(sh scripts/sources --method "$id" 2>/dev/null)
  v=$(sh scripts/sources --version "$id" 2>/dev/null)
  u=$(sh scripts/sources --urls "$id" 2>/dev/null)
  # A && B || C is not if-then-else: C also runs when B fails. Written out.
  if [ -n "$m" ]; then ok "method: $id=$m"; else bad "no method: $id"; fi
  if [ -n "$v" ]; then ok "version: $id=$v"; else bad "no version: $id"; fi
  if [ -n "$u" ]; then ok "urls: $id"; else bad "no urls: $id"; fi
  case "$m" in
    oci|sets|iso) : ;;
    *) bad "unknown method for $id: $m" ;;
  esac
done

# ⛔ build-bsd must handle every method sources can emit. This is the check that
# catches a fifth BSD added to sources with no branch to build it.
for id in $IDS; do
  m=$(sh scripts/sources --method "$id" 2>/dev/null)
  if grep -q "^  $m)" scripts/build-bsd 2>/dev/null; then
    ok "build-bsd handles method: $m"
  else
    bad "build-bsd has no branch for method: $m (from $id)"
  fi
done

# ── the matrix json is well formed ──────────────────────────────────────────
J=$(sh scripts/sources --json 2>/dev/null)
case "$J" in
  '{"include":['*']}') ok "sources --json is shaped like an Actions matrix" ;;
  *) bad "sources --json is malformed: $J" ;;
esac

# ── ⛔ no exit code read through a pipe ─────────────────────────────────────
# The defect: `cmd | tail; rc=$?` reads tail's status, so a failed check reads
# as green. It was committed in this repository once, by the script whose whole
# job is verification. HISTORY/poc.md section 8.
if grep -nE '\|[^|]*\)$' scripts/* >/dev/null 2>&1 && grep -nB1 'rc=\$\?' scripts/* 2>/dev/null | grep -q '|'; then
  bad "an exit code is read after a pipe. HISTORY/poc.md section 8"
else
  ok "no exit code is read through a pipe"
fi

# ── ⛔ the digest check has no bypass ───────────────────────────────────────
if grep -qiE 'skip.?(checksum|digest|verify)|--no-verify|SKIP_SHA' scripts/* 2>/dev/null; then
  bad "a way past the digest check exists. There must not be one."
else
  ok "no bypass for the digest check"
fi

# ── ⛔ native binaries are never handed a path ──────────────────────────────
# The Windows trap: a Git Bash path given to a native curl, podman or 7z fails
# naming neither the path nor the cause. HISTORY/poc.md section 7.
# shellcheck disable=SC2016
# The single quotes are deliberate: this is a grep pattern and the literal
# characters are wanted, not an expansion of them.
if grep -nE 'curl .*-o "\$WORK/' scripts/* >/dev/null 2>&1; then
  bad "curl is given a path. Run it from the directory with a bare filename."
else
  ok "curl is never handed a path"
fi

# ── the documents agree with the tree ──────────────────────────────────────
for f in README.md HISTORY/poc.md LICENSE; do
  if [ -f "$f" ]; then ok "present: $f"; else bad "missing: $f"; fi
done

# ⚠ The README claims exit 139. If that number is edited in one place and not
# the other, the two documents disagree about the finding the whole repository
# rests on.
if grep -q '139' README.md && grep -q '139' HISTORY/poc.md; then
  ok "README and poc.md agree on the SIGSEGV exit code"
else
  bad "README and HISTORY/poc.md disagree about the exit code"
fi

# ── the standalone shape ────────────────────────────────────────────────────
# ⛔ These exist because this repository stopped depending on another one, and
# a structure nobody checks is a structure that quietly reverts.

for f in docs/AGENTS.md docs/HUMANS.md docs/LIMITS.md docs/vendored.md \
         TODO/INDEX.md TODO/PROGRESS.md TODO/SUMMARY.md \
         HISTORY/README.md HISTORY/misc/PROMPT.md CHANGELOG.md \
         examples/README.md experiments/README.md; do
  if [ -f "$f" ]; then ok "present: $f"; else bad "missing: $f"; fi
done

# ⛔ ONE AGENT ENTRY POINT. docs/AGENTS.md is the router; a second one in the
# root or in a subdirectory is a second router, and two routers fork.
stray=$(git ls-files '*AGENTS.md' | grep -v '^docs/AGENTS.md$' || true)
if [ -z "$stray" ]; then
  ok "exactly one AGENTS.md, and it is docs/AGENTS.md"
else
  bad "more than one AGENTS.md: $stray. reproduce: git ls-files '*AGENTS.md'"
fi

# ⛔ ONE FACT, ONE HOME. The measured seconds live in docs/LIMITS.md and nowhere
# else. A second copy is a copy that will disagree, and the one a reader trusts
# is the wrong one. ⚠ The experiments and HISTORY are exempt: an experiment
# PRINTS its own measurement, and HISTORY is the record of when it was taken.
numbers='2\.6 s|0\.6 s|113\.6|108\.2|1\.8 s'
leak=$(git ls-files '*.md' \
  | grep -v '^docs/LIMITS.md$' \
  | grep -v '^experiments/' \
  | grep -v '^HISTORY/' \
  | grep -v '^TODO/bsd.md$' \
  | while read -r f; do
      if grep -qE "$numbers" "$f" 2>/dev/null; then printf '%s ' "$f"; fi
    done)
if [ -z "$leak" ]; then
  ok "the measured seconds appear only in docs/LIMITS.md"
else
  bad "a measured number escaped docs/LIMITS.md into: $leak. reproduce: grep -nE '$numbers' $leak"
fi

# ⛔ EVERY EXPERIMENT SAYS WHY IT EXISTS. A script whose name says what it does
# and whose header does not say why it was worth doing is a script the next
# person deletes.
missing=""
for f in $(git ls-files 'experiments/*.sh' 'experiments/*.ps1'); do
  if ! head -n 40 "$f" | grep -qiE 'WHY|\.SYNOPSIS'; then
    missing="$missing $f"
  fi
done
if [ -z "$missing" ]; then
  ok "every experiment has a header saying why it exists"
else
  bad "no WHY header:$missing. reproduce: head -40 <file>"
fi

# ⛔ EVERY EXAMPLE PARSES AND SAYS WHAT IT NEEDS.
bad_ex=""
for f in $(git ls-files 'examples/*.sh'); do
  sh -n "$f" 2>/dev/null || bad_ex="$bad_ex $f(parse)"
  head -n 20 "$f" | grep -q 'NEEDS:' || bad_ex="$bad_ex $f(NEEDS)"
done
if [ -z "$bad_ex" ]; then
  ok "every example parses and declares what it needs"
else
  bad "examples:$bad_ex. reproduce: sh -n <file>; head -20 <file>"
fi

# ⚠ The console driver exists in two languages on purpose, and they must carry
# the SAME two measured rules. A copy that lost one is a copy that will drop
# characters or match its own echo.
for f in experiments/lib/console.ps1 experiments/lib/console.py; do
  if [ ! -f "$f" ]; then
    bad "missing: $f"
  elif grep -qi 'one character at a time' "$f" && grep -qi 'whitespace removed' "$f"; then
    ok "carries both tty rules: $f"
  else
    bad "$f lost a tty rule. reproduce: grep -i 'one character at a time' $f"
  fi
done

# ⛔ A COUNT CLAIMED IN PROSE MUST MATCH THE TREE. Three documents claimed three
# different numbers of experiments once, because a ninth was added and the prose
# was not. A number written in a sentence is a number that drifts.
#
# ⚠ IT COMPARES THE VALUE, NOT THE SPELLING. "9" and "Nine" are the same claim,
# and a check that rejected one of them would be enforcing a house style while
# calling itself a correctness check. The defect is two documents DISAGREEING.
word_to_number() {
  case "$1" in
    [Oo]ne) echo 1 ;;   [Tt]wo) echo 2 ;;    [Tt]hree) echo 3 ;;
    [Ff]our) echo 4 ;;  [Ff]ive) echo 5 ;;   [Ss]ix) echo 6 ;;
    [Ss]even) echo 7 ;; [Ee]ight) echo 8 ;;  [Nn]ine) echo 9 ;;
    [Tt]en) echo 10 ;;  *) echo "$1" ;;
  esac
}

claimed=$(grep -rhoE '\*\*[A-Za-z0-9]+ (new )?experiments\*\*' \
            CHANGELOG.md TODO/PROGRESS.md TODO/SUMMARY.md 2>/dev/null \
          | sed -E 's/^\*\*([A-Za-z0-9]+).*/\1/' \
          | while read -r w; do word_to_number "$w"; done | sort -u | tr '\n' ' ')
actual=$(git ls-files 'experiments/*.sh' 'experiments/*.ps1' \
         | grep -v '^experiments/lib/' | grep -c -v '10-probe-host' | tr -d ' ')

if [ "$claimed" = "$actual " ]; then
  ok "every document claims the same experiment count, and it matches the tree ($actual)"
elif [ -z "$claimed" ]; then
  bad "no document states the experiment count. reproduce: grep -rn 'experiments\*\*' CHANGELOG.md TODO/"
else
  bad "documents claim [$claimed], tree has $actual. reproduce: grep -rn 'experiments\*\*' CHANGELOG.md TODO/"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
