#!/usr/bin/env bash
# Tests of wait-hook.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- wait-hook.sh ------------------------------------------------------------
# When the person is waited on: Stop / UserPromptSubmit and around
# AskUserQuestion, put on the one open run of the directory. Without jq.
section="wait-hook.sh"
nojq="$tmp/nojq-bin"
mkdir -p "$nojq"
for t in bash git awk grep sed tr head cat dirname wc date mkdir; do
  p=$(command -v "$t") && ln -s "$p" "$nojq/$t"
done
wh="$tmp/wh"
git init -q -b main "$wh"
(cd "$wh" && git commit -q --allow-empty -m init)
# hook <event> [tool] [cwd]: run the hook as Claude Code does, print its output.
hook() {
  printf '{"session_id":"s-1","cwd":"%s","hook_event_name":"%s","tool_name":"%s","prompt":"x"}' "${3:-$wh}" "$1" "${2:-}" \
    | PATH="$nojq" bash "$scripts/wait-hook.sh"
}
eq "" "$(hook Stop)" "no .tixforge: nothing printed"
[ -e "$wh/.tixforge" ] && ng "no .tixforge: nothing created" || ok
(cd "$wh" && bash "$scripts/run-state.sh" init GT-000801 > /dev/null)
whev="$wh/.tixforge/events.jsonl"
n=$(wc -l < "$whev" | tr -d ' ')
eq "" "$(hook Stop)" "Stop prints nothing"
eq "" "$(hook UserPromptSubmit)" "UserPromptSubmit prints nothing (it would go into the context)"
hook PreToolUse AskUserQuestion > /dev/null
hook PostToolUse AskUserQuestion > /dev/null
hook PreToolUse Bash > /dev/null
eq $((n + 4)) "$(wc -l < "$whev" | tr -d ' ')" "four waits logged, another tool ignored"
eq 'wait_start turn|wait_end turn|wait_start question|wait_end question' \
  "$(tail -4 "$whev" | jq -r '"\(.type) \(.cause)"' | paste -sd'|' -)" "type and cause"
eq '{"ticket":"GT-000801","session":"s-1"}' "$(tail -1 "$whev" | jq -c '{ticket, session}')" "the run and the session"
mkdir -p "$wh/sub"
hook Stop "" "$wh/sub" > /dev/null
eq $((n + 5)) "$(wc -l < "$whev" | tr -d ' ')" "from a subdirectory too"
# Two open runs before Implement: which one is waiting is unknown.
(cd "$wh" && bash "$scripts/run-state.sh" init GT-000802 > /dev/null)
n=$(wc -l < "$whev" | tr -d ' ')
hook Stop > /dev/null
eq "$n" "$(wc -l < "$whev" | tr -d ' ')" "two candidate runs: nothing logged"
# The run on the current branch wins over the early ones.
(cd "$wh" && git switch -q -c GT-000801-a && bash "$scripts/run-state.sh" set GT-000801 Branch GT-000801-a > /dev/null \
  && bash "$scripts/run-state.sh" set GT-000801 Status implement:in-progress > /dev/null)
n=$(wc -l < "$whev" | tr -d ' ')
hook Stop > /dev/null
eq GT-000801 "$(tail -1 "$whev" | jq -r .ticket)" "the run on the branch"
mv "$whev" "$tmp/whev" && chmod 500 "$wh/.tixforge"
out=$(hook Stop 2>&1)
eq "0:" "$?:$out" "an unwritable log: exit 0, nothing printed"
chmod 700 "$wh/.tixforge"
eq 0 "$(
  printf 'not json' | PATH="$nojq" bash "$scripts/wait-hook.sh" > /dev/null 2>&1
  echo $?
)" "bad input: exit 0"

done_file
