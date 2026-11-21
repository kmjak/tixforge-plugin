#!/usr/bin/env bash
# Hook for the event log: when the person is waited on. Claude Code runs it on
# Stop (the turn ended: the person's move), UserPromptSubmit (they answered),
# and before and after AskUserQuestion (a question within a turn). It appends
#   wait_start / wait_end   cause: turn | question, session: the session id
# to .tixforge/events.jsonl (lib.sh event), for the open run of this
# directory: the run on the current branch, or the only open run before
# Implement. With no such run, or more than one, it writes nothing (the wait
# cannot be put on a run). A wait is from a wait_start to the next wait_end
# of the same session and cause; a turn interrupted with Esc has no Stop, so
# a wait_end may come without a start.
#
# Prints nothing and always exits 0: UserPromptSubmit adds what it prints to
# the context, and a log must never stop the session. Reads the hook input
# with json_get, not jq (like the guard).
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
. "$here/lib.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | json_get cwd)
[ -n "$cwd" ] && [ -d "$cwd" ] && { cd "$cwd" || exit 0; }
top=$(git rev-parse --show-toplevel 2> /dev/null) || exit 0
[ -d "$(tf_dir "$top")" ] || exit 0

case $(printf '%s' "$input" | json_get hook_event_name) in
  Stop) type=wait_start cause=turn ;;
  UserPromptSubmit) type=wait_end cause=turn ;;
  PreToolUse) type=wait_start cause=question ;;
  PostToolUse) type=wait_end cause=question ;;
  *) exit 0 ;;
esac
case $cause in question)
  [ "$(printf '%s' "$input" | json_get tool_name)" = AskUserQuestion ] || exit 0
  ;;
esac

branch=$(git symbolic-ref --short -q HEAD 2> /dev/null || true)
runs=$(current_runs "$top" "$branch")
[ -n "$runs" ] && [ "$(printf '%s\n' "$runs" | wc -l)" -eq 1 ] || exit 0
id=${runs%/state.md}
id=${id##*/}
event "$top" "$id" "$type" cause "$(json_str "$cause")" \
  session "$(json_str "$(printf '%s' "$input" | json_get session_id)")"
exit 0
