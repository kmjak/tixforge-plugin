#!/usr/bin/env bash
# Tests of session-start.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
run_901

# --- session-start.sh ------------------------------------------------------
section="session-start.sh"
git switch -q GT-000901-a
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run GT-000901" "$out" "run on this branch"
has "skills/dev/run.md" "$out" "tells to re-read run.md"
case "$out" in *"skills/dev/pr.md"*) ng "pr.md only in the PR phase" ;; *) ok ;; esac
has "skills/dev/phase/implement.md" "$out" "and the file of the phase in Status"
[ -f "$scripts/../skills/dev/phase/implement.md" ] && ok || ng "the phase file it names exists"
bash "$scripts/run-state.sh" set GT-000901 Status pr:awaiting-review > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr.md" "$out" "the PR phase also re-reads pr.md"
has "skills/dev/pr/follow.md" "$out" "pr:awaiting-review: the file for after the PR"
case "$out" in *"skills/dev/pr/create.md"*) ng "pr:awaiting-review: not the file for creating it" ;; *) ok ;; esac
bash "$scripts/run-state.sh" set GT-000901 Status pr:awaiting-approval > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr/create.md" "$out" "pr:awaiting-approval: the file for creating the PR"
bash "$scripts/run-state.sh" set GT-000901 Status pr:in-progress > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr/create.md" "$out" "pr:in-progress: both files (the PR may or may not exist)"
has "skills/dev/pr/follow.md" "$out" "pr:in-progress: both files"
for f in pr.md pr/create.md pr/follow.md; do [ -f "$scripts/../skills/dev/$f" ] && ok || ng "skills/dev/$f exists"; done
case "$out" in *"skills/dev/phase/"*) ng "no phase file in the PR phase" ;; *) ok ;; esac
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
git switch -q main
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
eq "" "$out" "no run on main"
bash "$scripts/run-state.sh" set GT-000901 Status approach:in-progress > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run GT-000901" "$out" "the only run before Implement, with no branch yet"
bash "$scripts/run-state.sh" init GT-000902 > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "複数" "$out" "several runs before Implement: ask which"
has "GT-000901 GT-000902" "$out" "both are listed"
rm -rf .tixforge/GT-000902
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null

# A v2 local run waits for the migration: it is not a run to go on with.
mkdir -p .tixforge/LT-000020
printf '| Field | Value |\n|---|---|\n| Status | implement:in-progress |\n| Branch | LT-000020-x |\n' > .tixforge/LT-000020/state.md
git switch -q -c LT-000020-x
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
case "$out" in *LT-000020*) ng "session-start skips a v2 local run" ;; *) ok ;; esac
git switch -q main
git branch -q -D LT-000020-x
rm -rf .tixforge/LT-000020

done_file
