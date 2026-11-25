# Shared setup of tests/scripts/*.test.sh, sourced first by each: helpers,
# a temporary repository with a config (the working directory), and
# use_gh_stub for the files that talk to GitHub. Each file prints
# "scripts/<name>: N passed, M failed" and fails when M > 0.
# shellcheck shell=bash
# shellcheck disable=SC2034 # variables used by the files that source this

set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scripts="$here/../scripts"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# The event log is sent only where a test turns it on.
unset TIXFORGE_EVENTS_TOKEN
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

pass=0
fail=0
section=""
ok() { pass=$((pass + 1)); }
ng() {
  fail=$((fail + 1))
  printf 'FAIL  [%s] %s\n' "$section" "$1"
}
# eq <want> <got> <what>
eq() { if [ "$1" = "$2" ]; then ok; else ng "$3: want [$1], got [$2]"; fi; }
# has <text> <haystack> <what>
has() { case "$2" in *"$1"*) ok ;; *) ng "$3: [$1] not in [$2]" ;; esac }

repo="$tmp/repo"
git init -q -b main "$repo"
cd "$repo" || exit 1
mkdir -p .tixforge
cat > .tixforge/config.yml << 'EOF'
# tixforge settings (shared, committed)
language: ja   # comment
commands:      # run in order
  test: echo testing && exit 0
  lint: "echo 'a # not a comment' ; exit 1"
ticket:
  tracker: github
repository:
  base_branch: main
review:
  required: false
gates: [approach, plan, pr]
EOF
git add -A && git commit -q -m init # .tixforge/.gitignore comes with the first run

# The scripts' own helpers (json_str, field, ...) and the short forms the
# files use.
# shellcheck source=scripts/lib.sh
. "$scripts/lib.sh"
st() { bash "$scripts/run-state.sh" "$@"; }
tid() { bash "$scripts/ticket-id.sh" "$@"; }
evf=.tixforge/events.jsonl

# run_901: the run several files start from (what the run-state tests leave):
# GT-000901 in implement:in-progress on branch GT-000901-a, with a v2
# ticket.md, and .tixforge/.gitignore committed.
run_901() {
  mkdir -p .tixforge/GT-000901 && printf '# GT-000901: A\n\n## 背景\n' > .tixforge/GT-000901/ticket.md
  st init GT-000901 > /dev/null
  git add .tixforge/.gitignore && git commit -q -m gitignore
  git branch GT-000901-a
  st set GT-000901 Branch GT-000901-a > /dev/null
  st set GT-000901 Status implement:in-progress > /dev/null
}

# use_gh_stub: put the gh stub first on PATH.
use_gh_stub() {
  bin="$tmp/bin"
  mkdir -p "$bin"
  GH_DIR="$tmp/gh"
  mkdir -p "$GH_DIR"
  export GH_DIR
  cat > "$bin/gh" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_DIR/calls"
jqf=""; args=()
while [ $# -gt 0 ]; do
  case $1 in --jq) jqf=$2; shift 2 ;; --json) shift 2 ;; *) args+=("$1"); shift ;; esac
done
set -- "${args[@]}"
case "$1 $2" in
  "issue view") jq -r "$jqf" "$GH_DIR/issue-$3.json" ;;
  "pr list") jq -r "$jqf" "$GH_DIR/prs.json" 2>/dev/null || jq -rn "[] | $jqf" ;;
  "pr view") [ -z "${GH_FAIL_PRVIEW:-}" ] || exit 1
    jq -r "$jqf" "$GH_DIR/pr-view.json" 2>/dev/null || jq -rn "{comments: []} | $jqf" ;;
  "issue list") [ -z "${GH_FAIL_ISSUES:-}" ] || { echo "${GH_FAIL_ISSUES}" >&2; exit 1; }
    printf '%s\n' "$*" | grep -q -- 'label:"tixforge:todo","tixforge:in-progress","tixforge:in-review","tixforge:merged"' || { echo "stub gh: issue list without the label search" >&2; exit 1; }
    jq -r "$jqf" "$GH_DIR/issues.json" 2>/dev/null || jq -rn "[] | $jqf" ;;
  "api user") [ -z "${GH_FAIL_USER:-}" ] || { echo "${GH_FAIL_USER}" >&2; exit 1; }; echo "${GH_LOGIN:-me}" ;;
  "api repos/"*)   # .../issues/<n>: an issue, or a PR when the fixture has pull_request; .../issues/<n>/events
    case $2 in
      */events) n=${2%/events}; n=${n##*/}; jq -r "(.events // []) | $jqf" "$GH_DIR/issue-$n.json" ;;
      *) f="$GH_DIR/issue-${2##*/}.json"
         if [ -f "$f" ]; then jq -r "$jqf" "$f"; else echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi ;;
    esac ;;
  "auth status") [ -z "${GH_NO_AUTH:-}" ] ;;
  "repo view") echo o/r ;;
  "label list") cat "$GH_DIR/labels" 2>/dev/null || true ;;
  "label create") echo "$3" >> "$GH_DIR/labels" ;;
  "issue comment")
    n=$3; shift 3
    while [ $# -gt 0 ]; do
      case $1 in
        --body-file) jq --rawfile b "$2" '.comments += [{body: $b}]' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  "issue create")
    echo "https://github.com/o/r/issues/42" ;;
  "issue edit")
    n=$3; shift 3
    while [ $# -gt 0 ]; do
      case $1 in
        --body-file) jq --rawfile b "$2" '.body = $b' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --title) jq --arg t "$2" '.title = $t' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --remove-label) jq --arg l "$2" '.labels |= map(select(.name != $l))' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$bin/gh"
  PATH="$bin:$PATH"

  # issue <n> <title> <body-file> [state] [reason] [labels-json]
  issue() {
    jq -n --arg t "$2" --rawfile b "$3" --arg s "${4:-OPEN}" --arg r "${5:-}" --argjson l "${6:-[]}" \
      '{title: $t, body: $b, state: $s, stateReason: $r, labels: $l, assignees: [], comments: [], closedByPullRequestsReferences: [], events: []}' \
      > "$GH_DIR/issue-$1.json"
  }
}

# done_file: the summary line and the exit status of a file.
done_file() {
  echo "scripts/$(basename "$0" .test.sh): $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}
