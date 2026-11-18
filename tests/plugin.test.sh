#!/usr/bin/env bash
# Tests for the plugin's files other than the scripts:
#   1. the manifests and hooks.json are valid JSON with the keys Claude Code needs
#   2. every script a hook runs exists
#   3. every plugin path the skills, references, agents and README name exists
#      (a renamed file is otherwise read by Claude as missing, silently)
#   4. hooks.json starts the guard only for the tools it decides on
#   5. dev and ticket name the ticket operations, not the GitHub issue details
#   6. every instruction file is split into phases (## Phase N — name)
#
# Needs jq. Usage: bash tests/plugin.test.sh
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1

pass=0
fail=0
section=""
ok() { pass=$((pass + 1)); }
ng() {
  fail=$((fail + 1))
  printf 'FAIL  [%s] %s\n' "$section" "$1"
}

# --- manifests ---------------------------------------------------------------
section="manifests"
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json; do
  jq empty "$f" 2> /dev/null && ok || ng "$f is valid JSON"
done
jq -e '.name == "tixforge"' .claude-plugin/plugin.json > /dev/null && ok || ng "plugin.json: name is tixforge"
jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' .claude-plugin/plugin.json > /dev/null && ok \
  || ng "plugin.json: version is x.y.z"
jq -e '.plugins | map(.name) | index("tixforge") != null' .claude-plugin/marketplace.json > /dev/null && ok \
  || ng "marketplace.json lists tixforge"

# --- hooks -------------------------------------------------------------------
section="hooks"
cmds=$(jq -r '.hooks[][].hooks[].command' hooks/hooks.json)
[ -n "$cmds" ] && ok || ng "hooks.json has commands"
while IFS= read -r c; do
  [ -n "$c" ] || continue
  p=$(printf '%s\n' "$c" | sed -n 's|.*"\${CLAUDE_PLUGIN_ROOT}"/\([^ "]*\).*|\1|p')
  if [ -z "$p" ]; then
    ng "hook command runs a file under \${CLAUDE_PLUGIN_ROOT}: $c"
  elif [ -f "$p" ]; then
    ok
  else
    ng "hook command runs a missing file: $p"
  fi
done <<< "$cmds"

# --- paths named in the documents ---------------------------------------------
# <plugin>/x, ${CLAUDE_PLUGIN_ROOT}/x and bare skills/, references/, scripts/,
# templates/, agents/ paths are relative to the plugin root; <scripts>/x is
# scripts/x. Only full file names are checked (no <placeholder>, * or {}).
section="references"
docs=$(git ls-files 'skills/*.md' 'references/*.md' 'agents/*.md' 'templates/docs/*.md' README.md)
[ -n "$docs" ] && ok || ng "documents found"
refs=$(
  # shellcheck disable=SC2086 # $docs is a list of paths without spaces
  grep -oE '(<plugin>/|<scripts>/|\$\{CLAUDE_PLUGIN_ROOT\}/)?(skills|references|scripts|templates|agents)?/?[A-Za-z0-9_./-]+\.(md|sh|yml|json)' $docs \
    | sed -E 's|^[^:]*:||; s|^(<plugin>/\|\$\{CLAUDE_PLUGIN_ROOT\}/)||; s|^<scripts>/|scripts/|' \
    | grep -E '^(skills|references|scripts|templates|agents)/' | sort -u
)
n=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  n=$((n + 1))
  [ -e "$p" ] && ok || ng "a document names a missing file: $p ($(grep -lF "$p" $docs | tr '\n' ' '))"
done <<< "$refs"
[ "$n" -gt 20 ] && ok || ng "the documents name plugin files ($n found)"

# --- config sample -----------------------------------------------------------
# references/config.md: every key of the YAML sample has a row in the table,
# and every row a key in the sample (commands' entries are the user's).
section="config sample"
yk=$(awk '/^```yaml/ { on = 1; next } /^```/ { on = 0 } on && !/^[ \t]*#/' references/config.md \
  | awk '/^[a-z_]+:/ { p = $1; sub(/:.*/, "", p); if ($0 ~ /:[ \t]*(#.*)?$/) next; print p; next }
         /^  [a-z_]+:/ { k = $1; sub(/:.*/, "", k); if (p == "commands") { print p; next } print p "." k }' | sort -u)
tk=$(sed -n 's/^| `\([a-z_.]*\)` |.*/\1/p' references/config.md | sort -u)
[ -n "$yk" ] && [ "$yk" = "$tk" ] && ok || ng "config.md: sample keys [$(echo $yk)] differ from table keys [$(echo $tk)]"

# --- guard matcher -----------------------------------------------------------
# hooks.json starts the guard only for the tools it decides on: Bash, the
# edit tools and MCP tools whose name contains git (guard.sh skips other
# MCP tools). A tool the guard looks at must match; another MCP must not.
# Claude Code tests the matcher as an unanchored regex (a match anywhere
# in the tool name), so the test does too.
section="guard matcher"
m=$(jq -r '.hooks.PreToolUse[0].matcher' hooks/hooks.json)
for t in Bash Edit Write MultiEdit NotebookEdit mcp__github__merge_pull_request mcp__GitHub__push_files mcp__gitlab__create_merge_request; do
  printf '%s\n' "$t" | grep -Eq "$m" && ok || ng "matcher misses $t"
done
for t in mcp__Neon__run_sql mcp__claude-in-chrome__navigate Read Grep; do
  printf '%s\n' "$t" | grep -Eq "$m" && ng "matcher starts the guard for $t" || ok
done

# --- tracker operations ----------------------------------------------------
# dev and ticket call the ticket operations by name (references/common.md,
# "チケットの操作"); what they do on GitHub issues is written only in
# references/github/. PRs (gh pr) are the code host's, not the ticket's.
section="tracker operations"
hits=$(grep -nE 'closed_as|state_reason|stateReason|NOT_PLANNED|issue-label\.sh|issue-sync\.sh (push|pull|create|adopt)|gh issue|(Closes|Fixes|Resolves) #|tixforge:(todo|in-progress|in-review|merged|done|canceled|out-of-sync|hash|ticket:)' \
  skills/dev/*.md skills/ticket/*.md | grep -v '^[^:]*:[0-9]*:allowed-tools:')
[ -z "$hits" ] && ok || ng "issue details in skills/dev or skills/ticket (use the operation names):
$hits"

# --- phases ------------------------------------------------------------------
# Every instruction file starts its steps with "## Phase 1 — <name>" and
# numbers its phases in order. SKILL.md routes; pr.md is dev's Phase 6.
section="phases"
for f in skills/*/*.md; do
  case $f in */SKILL.md | skills/dev/pr.md) continue ;; esac
  got=$(sed -n 's/^## Phase \([0-9]*\) — .*/\1/p' "$f" | paste -sd' ' -)
  want=$(seq 1 "$(printf '%s\n' "$got" | wc -w)" | paste -sd' ' -)
  [ -n "$got" ] && [ "$got" = "$want" ] && ok || ng "$f: phases are ## Phase 1 — … numbered in order (got: $got)"
  # dev's run.md numbers each phase from 1 (Status names the phase).
  bad=$(awk -v steps="$([ "$f" = skills/dev/run.md ] && echo 0 || echo 1)" '
    /^## Phase/ && !/^## Phase [0-9]+ — ./ { print FILENAME ":" FNR ": not ## Phase N — <name>" }
    /^## Phase / { want = 1; next }
    want && NF { if ($0 !~ /^目的：/) print FILENAME ":" FNR ": no 目的： after the heading"; want = 0 }
    /^```/ { fence = !fence }
    steps && !fence && /^[0-9]+\. / { n = $0 + 0; if (n != last + 1) print FILENAME ":" FNR ": step " n " after " last; last = n }
  ' "$f")
  [ -z "$bad" ] && ok || ng "$bad"
done

echo "plugin: $pass passed, $fail failed"
[ $fail -eq 0 ]
