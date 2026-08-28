#!/bin/sh
# reap.sh - what did this project leave on the machine, and take it back.
#
# ── ⛔ WHY IT EXISTS, AND IT IS A MEASUREMENT ────────────────────────────────
#
# On 2026-08-28 the development machine was found carrying 435 container images
# totalling 37.27 GB, of which podman reported 100 percent reclaimable. Sampled
# layers carry `org.opencontainers.image.source` pointing at this repository and
# this repository's own `BSD_ROOT_LABEL` and `BSD_MEM` environment, so they are
# THIS PROJECT'S build layers: a `podman build` of a 2.3 GB image leaves 2.3 GB
# of dangling layers behind on every single run, and nothing had ever pruned.
#
# ⭐ THE CONTAINERS WERE FINE AND THAT IS THE USEFUL HALF. Zero exited
# containers were found, because every `podman run` in this repository passes
# `--rm`. ⛔ The leak is entirely in `podman build`, which has no `--rm` to pass.
#
# ── ⛔ AND IT REFUSES WHILE A GUEST IS RUNNING ───────────────────────────────
#
# ⭐ THAT IS THE POINT OF IT, not a safety catch. `TODO/RULES.md` step 0 says a
# session with a measurement in flight has not ended, and a session that has
# forgotten will run this on its way out. A running guest is either work in
# flight, in which case finishing it is the task, or it is abandoned, in which
# case somebody should be told rather than have it tidied away underneath them.
#
# ⛔ SO A RUNNING GUEST EXITS 1 AND REMOVES NOTHING. Not even with --apply.
# `--force-stop` is the deliberate way to say the guest is abandoned.
#
# ── ⛔ WHAT IT WILL NEVER TOUCH ──────────────────────────────────────────────
#
# ⚠ This machine runs more than this project, and a reaper that takes a
# neighbour's data is worse than the disk it saved.
#
#   volumes                 ⛔ NEVER. This project creates none. The four on this
#                           machine belong to something else and this script does
#                           not so much as list them for removal.
#   another project's images  ⛔ NEVER. Only images whose repository matches this
#                           project's names, plus dangling layers whose config
#                           carries this project's own markers.
#   the podman machine      ⛔ NEVER. It is the host for everything else here.
#   anything, without --apply  ⭐ the default is a report. A reaper that deletes
#                           by default is a reaper nobody dares run.
#
# ── ⚠ WHY NO POWERSHELL TWIN ────────────────────────────────────────────────
#
# `scripts/common/check-twins.sh` states the rule: a twin exists only where a
# single implementation cannot run. This runs AFTER the probe has reported, at
# the end of a session, on a host already known to have a POSIX shell and a
# container engine. ⛔ A second implementation would be a second place for the
# "never touch a volume" rule to be wrong.
#
# Usage:
#   sh scripts/common/reap.sh                 report, remove nothing
#   sh scripts/common/reap.sh --apply         remove this project's reclaimable images
#   sh scripts/common/reap.sh --force-stop    also stop this project's running guests
#   sh scripts/common/reap.sh --json
#
# Exit codes: 0 nothing running and nothing to reclaim, 1 a guest is running or
# something is reclaimable, 2 could not run.
#
# ⛔ Read the exit code from this process, unpiped.

set -u

APPLY=0
FORCE_STOP=0
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)      APPLY=1 ;;
    --force-stop) FORCE_STOP=1 ;;
    --json)       JSON=1 ;;
    -h|--help) awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else exit }' "$0"; exit 0 ;;
    *) printf 'reap: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

ENGINE="${ENGINE:-}"
if [ -z "$ENGINE" ]; then
  for e in podman docker; do
    if command -v "$e" >/dev/null 2>&1; then ENGINE=$e; break; fi
  done
fi
[ -n "$ENGINE" ] || { printf 'reap: neither podman nor docker is on PATH\n' >&2; exit 2; }
"$ENGINE" info >/dev/null 2>&1 || {
  printf 'reap: %s is on PATH and not answering. Nothing was read.\n' "$ENGINE" >&2
  exit 2; }

# ⚠ THE NAMES THIS PROJECT PUBLISHES UNDER, and nothing else is a candidate.
# ⛔ Kept here rather than in scripts/sources because sources is the artefact
# matrix and this is a list of things this repository CREATES on a machine.
MINE='localhost/netbsd|ghcr.io/pkgforge-dev/netbsd|ghcr.io/pkgforge-dev/freebsd|ghcr.io/pkgforge-dev/openbsd|localhost/netbsd-bench-host|localhost/bench-host'

say() { [ "$JSON" = 1 ] || printf '%s\n' "$*"; }

# ── 1. is anything of ours RUNNING ──────────────────────────────────────────
#
# ⛔ MATCHED ON THE IMAGE, NOT ON THE COMMAND. An experiment overrides the
# entrypoint, so the command line says `/bin/sh` and tells you nothing; the
# image is what says whose guest it is.
RUNNING=$("$ENGINE" ps --format '{{.ID}} {{.Image}} {{.Status}}' 2>/dev/null \
          | grep -E "$MINE" || true)
RUNNING_N=$(printf '%s' "$RUNNING" | grep -c . || true)

# ── 2. what is reclaimable and OURS ─────────────────────────────────────────
#
# ⛔ TWO CLASSES, AND THEY ARE FOUND DIFFERENTLY. A tagged image of ours is
# matched by name. A DANGLING layer has no name at all, so it is matched by the
# markers this project's own Containerfile puts in every image it builds: the
# OCI source label, and the BSD_ROOT_LABEL the entrypoint needs.
#
# ⚠ THE MARKER TEST IS WHAT KEEPS A NEIGHBOUR'S LAYERS SAFE. A bare
# `image prune` would take every dangling layer on the machine, including ones
# this project never built, and it is exactly the shortcut this script exists
# not to take.
#
# ⛔ THREE MARKERS, AND THE THIRD IS WHAT CLOSED THE GAP. The first run of this
# could prove only 14.1 GB of 37.27 GB was ours, because the `fetch` stage of
# images/netbsd/Containerfile sets no label and no BSD_ env before it is
# discarded. ⚠ Reading the remaining layers rather than guessing at them showed
# that every one carries, in its BUILD HISTORY, something this repository owns:
#
#   https://smolbsd.org/assets/netbsd-SMOL          a pin in scripts/sources
#   https://github.com/NetBSDfr/smolBSD/releases/   a pin in scripts/sources
#   sh /grow-rootfs.sh rootfs.img ...               a file in this repository
#
# ⭐ THAT IS PROOF RATHER THAN A HEURISTIC. Those strings are this project's own
# pins and its own filename, and a neighbour's layer does not contain them.
# ⛔ It is still far narrower than `image prune`, which takes every unnamed layer
# on a machine that runs more than this project.
EXITED=$("$ENGINE" ps -a --filter status=exited --format '{{.ID}} {{.Image}}' 2>/dev/null \
         | grep -E "$MINE" || true)
EXITED_N=$(printf '%s' "$EXITED" | grep -c . || true)

DANGLING=""
DANGLING_BYTES=0
# ⚠ THE HISTORY IS PART OF THE EVIDENCE, so it is part of what is read. A
# discarded build stage keeps no label and no env, and its history is the only
# place its origin survives.
for id in $("$ENGINE" images --filter dangling=true --quiet 2>/dev/null); do
  meta=$("$ENGINE" image inspect "$id" \
           --format '{{.Labels}}|{{range .Config.Env}}{{.}} {{end}}|{{range .History}}{{.CreatedBy}} {{end}}|{{.Size}}' 2>/dev/null) || continue
  case "$meta" in
    *pkgforge-dev/docker-bsd*|*BSD_ROOT_LABEL*|*smolbsd.org/assets*|*NetBSDfr/smolBSD*|*grow-rootfs.sh*|*/opt/bsd/*)
      bytes=${meta##*|}
      DANGLING="$DANGLING $id"
      DANGLING_BYTES=$((DANGLING_BYTES + bytes))
      ;;
  esac
done
DANGLING_N=$(printf '%s' "$DANGLING" | wc -w | tr -d ' ')

human() {
  # ⚠ Integer arithmetic to one place. sh has no floating point and a byte count
  # printed to six digits would be claiming a precision nobody needs.
  b=$1
  if [ "$b" -ge 1073741824 ]; then
    printf '%s.%s GB' $((b / 1073741824)) $(((b % 1073741824) * 10 / 1073741824))
  elif [ "$b" -ge 1048576 ]; then
    printf '%s MB' $((b / 1048576))
  else
    printf '%s bytes' "$b"
  fi
}

if [ "$JSON" = 1 ]; then
  printf '{"running":%s,"exited":%s,"dangling":%s,"dangling_bytes":%s,"applied":%s}\n' \
    "$RUNNING_N" "$EXITED_N" "$DANGLING_N" "$DANGLING_BYTES" "$APPLY"
else
  printf 'reap  engine=%s\n\n' "$ENGINE"
  printf '  running guests      %s\n' "$RUNNING_N"
  printf '  exited containers   %s\n' "$EXITED_N"
  printf '  dangling layers     %s, %s\n' "$DANGLING_N" "$(human "$DANGLING_BYTES")"
  printf '\n'
  [ -z "$RUNNING" ] || printf '%s\n' "$RUNNING" | sed 's/^/  RUNNING  /'
fi

# ── 3. a running guest stops everything ─────────────────────────────────────
if [ "$RUNNING_N" -gt 0 ] && [ "$FORCE_STOP" = 0 ]; then
  say ''
  say 'reap: a guest of this project is still running, so nothing was removed.'
  say '      TODO/RULES.md step 0: a session with a measurement in flight has'
  say '      not ended. Finish it, or say it is abandoned with --force-stop.'
  exit 1
fi

if [ "$RUNNING_N" -gt 0 ] && [ "$FORCE_STOP" = 1 ]; then
  for id in $(printf '%s\n' "$RUNNING" | awk '{print $1}'); do
    say "  stopping $id"
    "$ENGINE" stop -t 10 "$id" >/dev/null 2>&1 || true
  done
fi

if [ "$APPLY" = 0 ]; then
  if [ "$EXITED_N" -gt 0 ] || [ "$DANGLING_N" -gt 0 ]; then
    say ''
    say 'reap: nothing was removed. Pass --apply to take it back.'
    exit 1
  fi
  say 'reap: nothing of this project is running and nothing is reclaimable.'
  exit 0
fi

# ── 4. take it back ─────────────────────────────────────────────────────────
#
# ⛔ ONE AT A TIME, AND A FAILURE IS REPORTED RATHER THAN SWALLOWED. An image
# another container still references refuses to be removed, which is correct;
# a loop that hid that would report a reclaim that did not happen.
removed=0
failed=0
for id in $(printf '%s\n' "$EXITED" | awk '{print $1}'); do
  [ -n "$id" ] || continue
  if "$ENGINE" rm "$id" >/dev/null 2>&1; then removed=$((removed + 1)); else failed=$((failed + 1)); fi
done
for id in $DANGLING; do
  if "$ENGINE" rmi "$id" >/dev/null 2>&1; then removed=$((removed + 1)); else failed=$((failed + 1)); fi
done

say ''
say "reap: removed $removed, refused $failed"
[ "$failed" -eq 0 ] || {
  say 'reap: something refused to be removed. It is still referenced, which is'
  say '      information rather than an error. Nothing was forced.'
  exit 1; }
exit 0
