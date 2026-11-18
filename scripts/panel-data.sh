#!/usr/bin/env bash
# The data of the /tixforge-panel pane (the mod in hooks/panel.tsx draws it
# and decides nothing). One record per line, fields separated by tabs, the
# title last (tabs and newlines in it become spaces). The first line is
# always this person's language (user_lang): the pane's words follow it.
#
#   panel-data.sh list
#     lang    <language>
#     me      <login>
#     pr      <number> <verdict> <draft|-> <url> <title>
#             verdict: pr-status.sh's (conflict, ci_failing, changes_requested,
#             approved, ready, pending), the same jq (PR_JUDGE_JQ in lib.sh)
#     ticket  <GT-id> <state> <assignee> <mine|-> <title>
#             open issues with a tixforge state label (PANEL_STATES below):
#             mine first, then unassigned, then others, each by number; at
#             most 30. assignee: - (none), <login>, or <login> +<n> (more)
#     more    <n>    tickets past the 30
#   panel-data.sh issue <number>
#     lang    <language>
#     issue   <GT-id> <state> <assignees|-> <start> <title>
#             state: the tixforge state label without "tixforge:", or -
#             start: yes (todo, unassigned or mine, and no run of it here) |
#             assigned (todo, someone else's) | started (not todo, or a run
#             of it is open in .tixforge/)
#     then the ticket's body (between the markers; the whole issue body when
#     tixforge did not write it, or the markers are broken)
#
# Errors (after the lang line):
#   exit 3  error<TAB>not-tixforge          not in a tixforge repository
#   exit 4  error<TAB>gh-missing            gh is not installed
#           error<TAB>gh-auth<TAB><reason>  gh is not signed in
#           error<TAB>gh<TAB><reason>       gh failed (offline, API error)
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: panel-data.sh list | issue <number>" >&2
  exit 2
}
[ $# -ge 1 ] || usage

top=$(git rev-parse --show-toplevel 2> /dev/null) || top=""
printf 'lang\t%s\n' "$(user_lang "$top")"
[ -n "$top" ] && [ -d "$(tf_dir "$top")" ] || {
  printf 'error\tnot-tixforge\n'
  exit 3
}
gh_fail() { # gh_fail <kind> [<reason>]
  printf 'error\t%s\t%s\n' "$1" "$(printf '%s' "${2:-}" | head -1)"
  exit 4
}
command -v gh > /dev/null 2>&1 || gh_fail gh-missing
err=$(mktemp) || exit 1
trap 'rm -f "$err"' EXIT
if ! me=$(gh api user --jq .login 2> "$err"); then
  if ! gh auth status > /dev/null 2>&1; then gh_fail gh-auth "$(cat "$err")"; fi
  gh_fail gh "$(cat "$err")"
fi
# A login is letters, digits and hyphens: anything else would break the jq
# it is written into below.
case $me in '' | *[!A-Za-z0-9-]*) gh_fail gh "unexpected login: ${me}" ;; esac

# The state labels the panel lists, in the order of the work: label_defs in
# issue-label.sh without done, canceled and out-of-sync (a test holds them
# together).
PANEL_STATES="tixforge:todo tixforge:in-progress tixforge:in-review tixforge:merged"
states="[$(printf '"%s",' $PANEL_STATES | sed 's/,$//')]"
ticket_jq='
  def gt: "GT-" + (tostring | if length < 6 then ("000000" + .)[-6:] else . end);
  def clean: gsub("[\t\r\n]"; " ");
  def state: ([.labels[].name] as $l | ('"$states"' | map(select(. as $s | $l | index($s)))) | .[0] // "");
  def mine: any(.assignees[]; .login == "'"$me"'");
'

case $1 in
  list)
    [ $# -eq 1 ] || usage
    printf 'me\t%s\n' "$me"
    out=$(gh pr list --author @me --state open --limit 100 \
      --json number,title,url,state,isDraft,mergeable,reviewDecision,latestReviews,statusCheckRollup \
      --jq "${PR_JUDGE_JQ}"'
        .[] | . as $p | pr_judge
        | ["pr", ($p.number | tostring), .verdict, (if $p.isDraft then "draft" else "-" end), $p.url,
           ($p.title | gsub("[\t\r\n]"; " "))] | join("\t")' 2> "$err") || gh_fail gh "$(cat "$err")"
    [ -z "$out" ] || printf '%s\n' "$out"
    # Only issues with one of the labels (the search ORs them).
    search="label:$(printf '"%s",' $PANEL_STATES | sed 's/,$//')"
    out=$(gh issue list --state open --search "$search" --limit 1000 --json number,title,labels,assignees \
      --jq "${ticket_jq}"'
        map(select(state != "")
            | . + {rank: (if mine then 0 elif (.assignees | length) == 0 then 1 else 2 end)})
        | sort_by(.rank, .number) as $all
        | ($all[:30][]
           | ["ticket", (.number | gt), (state | ltrimstr("tixforge:")),
              (if (.assignees | length) == 0 then "-"
               else .assignees[0].login + (if (.assignees | length) > 1 then " +\(.assignees | length - 1)" else "" end) end),
              (if mine then "mine" else "-" end), (.title | clean)] | join("\t")),
          (if ($all | length) > 30 then "more\t\($all | length - 30)" else empty end)' 2> "$err") \
      || gh_fail gh "$(cat "$err")"
    [ -z "$out" ] || printf '%s\n' "$out"
    ;;
  issue)
    [ $# -eq 2 ] || usage
    id=$(bash "$(dirname "$0")/ticket-id.sh" normalize "$2" 2> /dev/null) || usage
    n=$(issue_of "$id")
    [ -n "$n" ] || usage
    # A run of it open here: started, whatever the label says yet.
    run=no
    while IFS="$RUN_SEP" read -r rid s _; do
      [ "$rid" = "$id" ] && is_open_status "$s" && run=yes
    done << EOF
$(each_run "$top")
EOF
    # One line of fields, then the body.
    out=$(gh issue view "$n" --json number,title,labels,assignees,body \
      --jq "${ticket_jq}"'
        state as $s
        | (["issue", (.number | gt), (if $s == "" then "-" else ($s | ltrimstr("tixforge:")) end),
            (if (.assignees | length) == 0 then "-" else ([.assignees[].login] | join(",")) end),
            (if $s != "tixforge:todo" or "'"$run"'" == "yes" then "started"
             elif (.assignees | length) == 0 or mine then "yes"
             else "assigned" end),
            (.title | clean)] | join("\t")),
          .body' 2> "$err") || gh_fail gh "$(cat "$err")"
    printf '%s\n' "$out" | sed -n 1p
    body=$(printf '%s\n' "$out" | sed '1d')
    ticket=$(printf '%s\n' "$body" | bash "$(dirname "$0")/ticket-hash.sh" extract 2> /dev/null) || ticket=$body
    printf '%s\n' "$ticket"
    ;;
  *) usage ;;
esac
