#!/usr/bin/env bash
# Where a /tixforge:dev run in the PR phase goes on from (skills/dev/pr.md,
# 「再開」), from its Status, the PR of its branch, git and the PR comments.
#
#   pr-resume.sh <ticket-id>
#
# Prints key: value lines, the first is next:
#   next: create          no PR (or only closed ones): 「PR の準備」 from step 1
#   next: gate            pr:awaiting-approval and no PR: show the gate again
#   next: finish-create   pr:awaiting-approval with an open PR: the PR was
#                         created and the run stopped after it (pr.md)
#   next: push-fix        commits not pushed: 「修正の push」 from step 1
#   next: comment-fix     pushed but the verification comment is missing:
#                         「修正の push」 from step 2
#   next: status          「PR の状況確認」
#   next: merged          the PR is merged: 「PR の状況確認」's merged
#   pr: <url>             the PR: an open one, else a merged one, else (once
#                         the PR was made: pr:awaiting-review / ready-to-merge)
#                         a closed one or the URL in ## PR; none
#   closed: <url> ...     closed PRs of the branch, not used
#   head: <short hash>    the PR's head (open PR)
#   comment: present|missing
#                         a PR comment "Verification @ <hash>" for the PR's
#                         head (finish-create) or for HEAD (pr:in-progress)
#
# A short hash in a comment, "PR head @" (## PR) or "PR comment @" (the
# latest in the Implementation Log) matches a commit when it is a prefix of
# its full hash. Runs `git fetch origin <branch>` to see unpushed commits.
#
# Exit: 0 ok, 1 no such run, 2 usage, 3 the Status is not pr:*, 4 gh failed.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

[ $# -eq 1 ] || {
  echo "usage: $(basename "$0") <ticket-id>" >&2
  exit 2
}
top=$(tf_top)
f=$(state_file "$1" "$top")
[ -f "$f" ] || {
  echo "no run: $1" >&2
  exit 1
}
st=$(field "$f" Status)
branch=$(field "$f" Branch)
case $st in pr:*) ;; *)
  echo "Status is $st, not pr:*" >&2
  exit 3
  ;;
esac

# last_key <section index> <key>: the hash after the last "<key> @ " line of a section.
last_key() {
  awk "$_section_awk"'
    { h = heading_index($0); if (h) { on = (h == s); next } }
    on && index($0, k " @ ") { t = substr($0, index($0, k " @ ") + length(k) + 3); sub(/[^0-9a-f].*$/, "", t); if (t != "") v = t }
    END { print v }' s="$1" k="$2" "$f"
}
# is_prefix <short> <full>: a short hash (7 or more digits, as git prints
# them) of the commit.
is_prefix() { [ ${#1} -ge 7 ] && case $2 in "$1"*) true ;; *) false ;; esac }

prs=$(gh pr list --head "$branch" --state all --json number,state,url,headRefOid \
  --jq '.[] | [.state, .url, .number, .headRefOid] | @tsv' 2> /dev/null) || {
  echo "gh pr list failed" >&2
  exit 4
}
tab=$(printf '\t')
open_url="" open_no="" open_head="" merged_url="" closed="" shown=""
while IFS="$tab" read -r state url no head; do
  case $state in
    OPEN) [ -n "$open_url" ] || { open_url=$url open_no=$no open_head=$head; } ;;
    MERGED) [ -n "$merged_url" ] || merged_url=$url ;;
    CLOSED) closed="$closed $url" ;;
  esac
done << EOF
$prs
EOF

# The hashes of the open PR's "Verification @ <hash>" comments (a +dirty one
# stands for no commit, so it is left out). Read here, not in a $(...), so a
# failing gh stops the script.
vhashes=""
if [ -n "$open_url" ]; then
  bodies=$(gh pr view "$open_no" --json comments --jq '.comments[].body' 2> /dev/null) || {
    echo "gh pr view failed" >&2
    exit 4
  }
  vhashes=$(printf '%s\n' "$bodies" | sed -n 's/.*Verification @ \([0-9a-f+]*\).*/\1/p' | grep -v '+' || true)
fi
# comment_for <full hash>: present when a comment has a Verification for it.
comment_for() {
  local h
  for h in $vhashes; do is_prefix "$h" "$1" && {
    echo present
    return
  }; done
  echo missing
}

out() {
  printf 'next: %s\n' "$1"
  printf 'pr: %s\n' "${open_url:-${merged_url:-${shown:-none}}}"
  [ -n "$closed" ] && printf 'closed:%s\n' "$closed"
  [ -n "$open_head" ] && printf 'head: %s\n' "$(git -C "$top" rev-parse --short "$open_head" 2> /dev/null || printf '%.7s' "$open_head")"
  [ -n "${2:-}" ] && printf 'comment: %s\n' "$2"
  exit 0
}

if [ -z "$open_url" ]; then
  [ -n "$merged_url" ] && out merged
  [ "$st" = pr:awaiting-approval ] && out gate
  # After the PR was made, a closed one is the run's PR: the status check reports it.
  case $st in pr:awaiting-review | pr:ready-to-merge)
    shown=${closed# }
    shown=${shown%% *}
    # None found (the branch was renamed?): the URL ## PR recorded.
    [ -n "$shown" ] || shown=$(awk "$_section_awk"'
      { h = heading_index($0); if (h) { on = (h == 6); next } }
      on && match($0, /https:\/\/[^ )>]*\/pull\/[0-9]+/) { u = substr($0, RSTART, RLENGTH) }
      END { print u }' "$f")
    out status
    ;;
  esac
  out create
fi

case $st in
  pr:awaiting-approval) out finish-create "$(comment_for "$open_head")" ;;
  pr:awaiting-review | pr:ready-to-merge) out status ;;
esac

# pr:in-progress with an open PR.
git -C "$top" fetch -q origin "$branch" 2> /dev/null \
  || echo "git fetch origin $branch failed: judged from the last fetched origin/$branch" >&2
ahead=$(git -C "$top" rev-list --count "origin/$branch..$branch" 2> /dev/null || echo 0)
[ "$ahead" -gt 0 ] && out push-fix
headfull=$(git -C "$top" rev-parse "$branch" 2> /dev/null || git -C "$top" rev-parse HEAD)
c=$(comment_for "$headfull")
if is_prefix "$(last_key 6 'PR head')" "$headfull" || is_prefix "$(last_key 4 'PR comment')" "$headfull" || [ "$c" = present ]; then
  out status "$c"
fi
out comment-fix "$c"
