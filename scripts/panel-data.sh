#!/usr/bin/env bash
# The data of the /tixforge:panel pane (the mod in hooks/panel.tsx draws it
# and decides nothing). One record per line, fields separated by tabs, the
# title last (tabs in it become spaces).
#
#   panel-data.sh list
#     me      <login>
#     lang    <language>   this person's (user_lang): the pane's words follow it
#     pr      <number> <verdict> <draft|-> <url> <title>
#             verdict: pr-status.sh's (conflict, ci_failing, changes_requested,
#             approved, ready, pending), the same jq (PR_JUDGE_JQ in lib.sh)
#     ticket  <GT-id> <state> <assignee> <mine|-> <title>
#             open issues with a tixforge state label (todo, in-progress,
#             in-review, merged): mine first, then unassigned, then others,
#             each by number; at most 30
#             assignee: - (none), <login>, or <login> +<n> (more)
#     more    <n>    tickets past the 30
#   panel-data.sh issue <number>
#     issue   <GT-id> <state> <assignees|-> <start> <title>
#             state: the tixforge state label without "tixforge:", or -
#             start: yes (todo, and unassigned or mine) | assigned (todo,
#             someone else's) | started (not todo)
#     then the ticket's body (between the markers; the whole issue body when
#     tixforge did not write it)
#
# Exit 3 (one line: "error<TAB>not-tixforge") outside a tixforge repository;
# exit 4 ("error<TAB>gh<TAB><reason>") when gh is missing or fails (not
# signed in, offline).
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: panel-data.sh list | issue <number>" >&2
  exit 2
}
[ $# -ge 1 ] || usage

top=$(git rev-parse --show-toplevel 2> /dev/null) && [ -d "$(tf_dir "$top")" ] || {
  printf 'error\tnot-tixforge\n'
  exit 3
}
gh_fail() {
  printf 'error\tgh\t%s\n' "$(printf '%s' "$1" | head -1)"
  exit 4
}
command -v gh > /dev/null 2>&1 || gh_fail "gh が無い"
me=$(gh api user --jq .login 2>&1) || gh_fail "$me"

# The state labels the panel lists, in the order of the work.
states='["tixforge:todo","tixforge:in-progress","tixforge:in-review","tixforge:merged"]'
ticket_jq='
  def gt: "GT-" + (tostring | if length < 6 then ("000000" + .)[-6:] else . end);
  def clean: gsub("[\t\r\n]"; " ");
  def state: ([.labels[].name] as $l | ('"$states"' | map(select(. as $s | $l | index($s)))) | .[0] // "");
  def mine: any(.assignees[]; .login == "'"$me"'");
'

case $1 in
  list)
    [ $# -eq 1 ] || usage
    printf 'me\t%s\nlang\t%s\n' "$me" "$(user_lang "$top")"
    out=$(gh pr list --author @me --state open --limit 100 \
      --json number,title,url,state,isDraft,mergeable,reviewDecision,latestReviews,statusCheckRollup \
      --jq "${PR_JUDGE_JQ}"'
        .[] | . as $p | pr_judge
        | ["pr", ($p.number | tostring), .verdict, (if $p.isDraft then "draft" else "-" end), $p.url,
           ($p.title | gsub("[\t\r\n]"; " "))] | join("\t")' 2>&1) || gh_fail "$out"
    [ -z "$out" ] || printf '%s\n' "$out"
    out=$(gh issue list --state open --limit 1000 --json number,title,labels,assignees \
      --jq "${ticket_jq}"'
        map(select(state != "")
            | . + {rank: (if mine then 0 elif (.assignees | length) == 0 then 1 else 2 end)})
        | sort_by(.rank, .number) as $all
        | ($all[:30][]
           | ["ticket", (.number | gt), (state | ltrimstr("tixforge:")),
              (if (.assignees | length) == 0 then "-"
               else .assignees[0].login + (if (.assignees | length) > 1 then " +\(.assignees | length - 1)" else "" end) end),
              (if mine then "mine" else "-" end), (.title | clean)] | join("\t")),
          (if ($all | length) > 30 then "more\t\($all | length - 30)" else empty end)' 2>&1) || gh_fail "$out"
    [ -z "$out" ] || printf '%s\n' "$out"
    ;;
  issue)
    [ $# -eq 2 ] || usage
    n=$(issue_of "$(bash "$(dirname "$0")/ticket-id.sh" normalize "$2" 2> /dev/null || true)")
    [ -n "$n" ] || usage
    head=$(gh issue view "$n" --json number,title,labels,assignees \
      --jq "${ticket_jq}"'
        state as $s
        | ["issue", (.number | gt), (if $s == "" then "-" else ($s | ltrimstr("tixforge:")) end),
           (if (.assignees | length) == 0 then "-" else ([.assignees[].login] | join(",")) end),
           (if $s != "tixforge:todo" then "started"
            elif (.assignees | length) == 0 or mine then "yes"
            else "assigned" end),
           (.title | clean)] | join("\t")' 2>&1) || gh_fail "$head"
    body=$(gh issue view "$n" --json body --jq .body 2>&1) || gh_fail "$body"
    printf '%s\n' "$head"
    printf '%s\n' "$body" | bash "$(dirname "$0")/ticket-hash.sh" extract 2> /dev/null || printf '%s\n' "$body"
    ;;
  *) usage ;;
esac
