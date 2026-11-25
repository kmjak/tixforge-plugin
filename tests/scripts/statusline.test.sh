#!/usr/bin/env bash
# Tests of statusline.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
run_901

# --- statusline.sh ---------------------------------------------------------
section="statusline.sh"
sl() { printf '%s' "$1" | bash "$scripts/statusline.sh"; }
git switch -q GT-000901-a
eq "GT-000901 · implement:in-progress" "$(sl "{\"cwd\":\"$repo\"}")" "the run on this branch"
eq "GT-000901 · implement:in-progress" "$(sl "{\"workspace\":{\"current_dir\":\"$repo\"}}")" "workspace.current_dir when there is no cwd"
mkdir -p sub
eq "GT-000901 · implement:in-progress" "$(sl "{\"cwd\":\"$repo/sub\"}")" "from a subdirectory"
rmdir sub
# A finished run on this branch is not shown (current_runs: open runs only).
bash "$scripts/run-state.sh" set GT-000901 Status done > /dev/null
eq "" "$(sl "{\"cwd\":\"$repo\"}")" "a done run on this branch is not the current run"
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
git switch -q main
eq "" "$(sl "{\"cwd\":\"$repo\"}")" "nothing on main with no run before Implement"
bash "$scripts/run-state.sh" set GT-000901 Status plan:awaiting-approval > /dev/null
eq "GT-000901 · plan:awaiting-approval" "$(sl "{\"cwd\":\"$repo\"}")" "the only run before Implement"
bash "$scripts/run-state.sh" init GT-000902 > /dev/null
eq "GT-000901 · plan:awaiting-approval (+1)" "$(sl "{\"cwd\":\"$repo\"}")" "several runs before Implement"
rm -rf .tixforge/GT-000902
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
eq "" "$(sl "{\"cwd\":\"$tmp\"}")" "nothing outside a repository"
eq "" "$(sl '{}')" "nothing without a directory"
eq "" "$(sl "{\"cwd\":\"$repo/missing\"}")" "nothing for a missing directory"

done_file
