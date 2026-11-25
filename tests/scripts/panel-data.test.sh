#!/usr/bin/env bash
# Tests of panel-data.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub
run_check='[{"__typename":"CheckRun","name":"test","status":"IN_PROGRESS","conclusion":""}]'

# --- panel-data.sh ---------------------------------------------------------
section="panel-data.sh"
pd() { bash "$scripts/panel-data.sh" "$@"; }
out=$(cd "$tmp" && bash "$scripts/panel-data.sh" list)
eq 3 $? "outside a tixforge repository: exit 3"
eq "$(printf 'lang\tja\nerror\tnot-tixforge')" "$out" "outside a tixforge repository: says so, after the language"
# The labels the panel lists are label_defs' states, without the ends.
eq "$(sed -n '/^label_defs() {/,/^}/p' "$scripts/issue-label.sh" | grep -o 'tixforge:[a-z-]*' | grep -v -e done -e canceled -e out-of-sync | paste -sd' ' -)" \
  "$(sed -n 's/^PANEL_STATES="\(.*\)"$/\1/p' "$scripts/panel-data.sh")" "PANEL_STATES are label_defs' open states"
# Two PRs (one in conflict, one draft with checks running) and tickets in
# every order the panel sorts: mine, unassigned, others; a closed-state
# label and a plain issue are left out.
jq -n --argjson c "$run_check" '[
  {number: 7, title: "Fix\tit", url: "https://github.com/o/r/pull/7", state: "OPEN", isDraft: false, mergeable: "CONFLICTING", reviewDecision: "", latestReviews: [], statusCheckRollup: []},
  {number: 8, title: "Wip", url: "https://github.com/o/r/pull/8", state: "OPEN", isDraft: true, mergeable: "MERGEABLE", reviewDecision: "", latestReviews: [], statusCheckRollup: $c}
]' > "$GH_DIR/prs.json"
jq -n '[
  {number: 5, title: "Others", labels: [{name: "tixforge:in-progress"}], assignees: [{login: "ann"}, {login: "bob"}]},
  {number: 3, title: "Free", labels: [{name: "bug"}, {name: "tixforge:todo"}], assignees: []},
  {number: 9, title: "Mine", labels: [{name: "tixforge:in-review"}], assignees: [{login: "me"}]},
  {number: 1, title: "Done", labels: [{name: "tixforge:done"}], assignees: []},
  {number: 2, title: "Plain", labels: [], assignees: []}
]' > "$GH_DIR/issues.json"
out=$(pd list)
eq 0 $? "list: exit 0"
eq "$(printf 'lang\tja
me\tme
pr\t7\tconflict\t-\thttps://github.com/o/r/pull/7\tFix it
pr\t8\tpending\tdraft\thttps://github.com/o/r/pull/8\tWip
ticket\tGT-000009\tin-review\tme\tmine\tMine
ticket\tGT-000003\ttodo\t-\t-\tFree
ticket\tGT-000005\tin-progress\tann +1\t-\tOthers')" "$out" "list: PRs with pr-status's verdict, tickets mine / unassigned / others"
jq -n '[range(1; 33) | {number: ., title: "t", labels: [{name: "tixforge:todo"}], assignees: []}]' > "$GH_DIR/issues.json"
out=$(pd list)
eq 30 "$(printf '%s\n' "$out" | grep -c '^ticket')" "list: at most 30 tickets"
has "$(printf 'more\t2')" "$out" "list: says how many more"
eq "$(printf 'ticket\tGT-1234567\ttodo\t-\t-\tbig')" "$(
  jq -n '[{number: 1234567, title: "big", labels: [{name: "tixforge:todo"}], assignees: []}]' > "$GH_DIR/issues.json"
  pd list | grep '^ticket'
)" "list: a number past six digits is not cut"
rm -f "$GH_DIR/prs.json" "$GH_DIR/issues.json"
eq "$(printf 'lang\tja\nme\tme')" "$(pd list)" "list: nothing open"
# issue: the header, whether it can be started, and the ticket's body.
printf '## 背景\n本文\n' > "$tmp/pd-ticket.md"
issue 21 "Detail" "$tmp/pd-ticket.md" OPEN "" '[{"name":"tixforge:todo"}]'
body=$(bash "$scripts/issue-sync.sh" body "$tmp/pd-ticket.md" 2> /dev/null) || body=""
[ -n "$body" ] && jq --arg b "$body" '.body = $b | .number = 21' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
out=$(pd issue 21)
eq "$(printf 'issue\tGT-000021\ttodo\t-\tyes\tDetail')" "$(printf '%s\n' "$out" | sed -n 2p)" "issue: an unassigned todo can be started"
mkdir -p .tixforge/GT-000021 && printf '| Field | Value |\n|---|---|\n| Status | plan:in-progress |\n| Branch | — |\n' > .tixforge/GT-000021/state.md
has "$(printf '\tstarted\t')" "$(pd issue 21 | sed -n 2p)" "issue: a run of it open here is started"
rm -rf .tixforge/GT-000021
has "本文" "$out" "issue: the ticket's body"
case "$out" in *"tixforge:"*"-->"*) ng "issue: the markers are left out" ;; *) ok ;; esac
jq '.assignees = [{login: "ann"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tann\tassigned\t')" "$(pd issue GT-000021 | sed -n 2p)" "issue: someone else's todo"
jq '.assignees = [{login: "me"}, {login: "ann"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tme,ann\tyes\t')" "$(pd issue 21 | sed -n 2p)" "issue: a todo of mine"
jq '.labels = [{name: "tixforge:in-progress"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tin-progress\tme,ann\tstarted\t')" "$(pd issue 21 | sed -n 2p)" "issue: started already"
printf 'no markers\n' > "$tmp/pd-plain.md"
issue 22 "Plain" "$tmp/pd-plain.md"
jq '.number = 22' "$GH_DIR/issue-22.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-22.json"
out=$(pd issue 22)
has "$(printf 'issue\tGT-000022\t-\t-\tstarted\tPlain')" "$out" "issue: no state label"
has "no markers" "$out" "issue: the whole body when tixforge did not write it"
# A blank line in the body stays; broken markers give the whole body once.
printf '## 背景\n\n段落\n' > "$tmp/pd-blank.md"
body=$(bash "$scripts/issue-sync.sh" body "$tmp/pd-blank.md" 2> /dev/null)
jq --arg b "$body" '.body = $b' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '## 背景\n\n段落')" "$(pd issue 21)" "issue: blank lines in the body stay"
jq --arg b "$(printf '<!-- tixforge:ticket -->\n## 背景\nhalf\n')" '.body = $b' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
eq 1 "$(pd issue 21 | grep -c half)" "issue: broken markers: the body once"
nogh="$tmp/panel-nogh"
mkdir -p "$nogh"
for t in bash git awk sed grep tr head cat dirname paste mktemp rm; do
  p=$(command -v "$t") && ln -sf "$p" "$nogh/$t"
done
out=$(PATH="$nogh" bash "$scripts/panel-data.sh" list)
eq 4 $? "no gh: exit 4"
has "$(printf 'error\tgh-missing')" "$out" "no gh: says so"
out=$(GH_FAIL_USER="HTTP 401: Bad credentials" bash "$scripts/panel-data.sh" list)
eq 4 $? "not signed in: exit 4"
has "$(printf 'error\tgh-auth\t')" "$out" "not signed in: says so"
out=$(GH_NO_AUTH=1 GH_FAIL_USER=offline bash "$scripts/panel-data.sh" list)
has "$(printf 'error\tgh\toffline')" "$out" "offline: not taken for signed out"
out=$(GH_FAIL_ISSUES=boom bash "$scripts/panel-data.sh" list)
eq "$(printf 'lang\tja\nerror\tgh\tboom')" "$out" "a list that fails half way: the error right after the language"
has "$(printf 'me\tm_e1')" "$(GH_LOGIN=m_e1 bash "$scripts/panel-data.sh" list)" "an EMU login (with _) is fine"
out=$(GH_LOGIN='a"b' bash "$scripts/panel-data.sh" list)
has "$(printf 'error\tgh\tunexpected login')" "$out" "a login that would break the jq is refused"

done_file
