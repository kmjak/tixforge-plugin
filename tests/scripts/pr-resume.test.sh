#!/usr/bin/env bash
# Tests of pr-resume.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

# --- pr-resume.sh ----------------------------------------------------------
# Where a run in the PR phase goes on from: Status, the PRs of the branch
# ($GH_DIR/prs.json), the PR's comments ($GH_DIR/pr-view.json), an origin
# (a bare repository here) and the hashes in state.md.
section="pr-resume.sh"
prr() { bash "$scripts/pr-resume.sh" "$@"; }
nxt() { prr GT-000909 | sed -n 's/^next: //p'; }
back=$(git symbolic-ref --short HEAD)
git init -q --bare "$tmp/origin.git"
git remote add origin "$tmp/origin.git"
git switch -q -c GT-000909-x
git commit -q --allow-empty -m pr1
h1=$(git rev-parse HEAD)
git push -q -u origin GT-000909-x 2> /dev/null
st init GT-000909 > /dev/null
st set GT-000909 Branch GT-000909-x > /dev/null
f9=.tixforge/GT-000909/state.md
# prs <state> <head> [<state> <head> ...]: the PRs gh pr list returns.
prs_of() {
  local a="[]" i=1
  while [ $# -ge 2 ]; do
    a=$(printf '%s' "$a" | jq --arg s "$1" --arg h "$2" --argjson n "$i" '. + [{number: $n, state: $s, url: "https://github.com/o/r/pull/\($n)", headRefOid: $h}]')
    i=$((i + 1))
    shift 2
  done
  printf '%s\n' "$a" > "$GH_DIR/prs.json"
}
comments() { jq -n --args '{comments: [$ARGS.positional[] | {body: .}]}' "$@" > "$GH_DIR/pr-view.json"; }
st set GT-000909 Status pr:in-progress > /dev/null
prs_of
eq create "$(nxt)" "no PR: create"
prs_of CLOSED "$h1"
out=$(prr GT-000909)
has "next: create" "$out" "only a closed PR: create"
has "closed: https://github.com/o/r/pull/1" "$out" "and the closed one is named"
has "pr: none" "$out" "but not used"
prs_of MERGED "$h1"
eq merged "$(nxt)" "a merged PR: merged"
st set GT-000909 Status pr:awaiting-approval > /dev/null
prs_of
eq gate "$(nxt)" "awaiting approval, no PR: the gate again"
prs_of OPEN "$h1"
comments "LGTM"
out=$(prr GT-000909)
has "next: finish-create" "$out" "awaiting approval with an open PR: finish the creation"
has "comment: missing" "$out" "and the verification comment is missing"
has "head: $(git rev-parse --short HEAD)" "$out" "the PR's head"
comments "x" "$(printf 'Verification @ %s: test pass\n\n### test' "${h1:0:7}")"
has "comment: present" "$(prr GT-000909)" "a comment for the PR's head"
comments "$(printf 'Verification @ %s+dirty: test pass' "${h1:0:7}")" "$(printf 'Verification @ %s: test pass' "${h1:0:3}")"
has "comment: missing" "$(prr GT-000909)" "a +dirty or too short hash is no comment for the head"
GH_FAIL_PRVIEW=1 prr GT-000909 > /dev/null 2>&1
eq 4 $? "gh pr view fails: exit 4"
st set GT-000909 Status pr:awaiting-review > /dev/null
eq status "$(nxt)" "awaiting review: status"
prs_of CLOSED "$h1"
has "pr: https://github.com/o/r/pull/1" "$(prr GT-000909)" "awaiting review and the PR was closed: status with it"
prs_of
printf '\n## PR\n- URL: https://github.com/o/r/pull/7\n' >> "$f9"
has "pr: https://github.com/o/r/pull/7" "$(prr GT-000909)" "awaiting review, no PR found: the URL in ## PR"
awk '$0 == "## PR" { exit } { print }' "$f9" > "$tmp/f9" && cat "$tmp/f9" > "$f9"
st set GT-000909 Status pr:in-progress > /dev/null
prs_of OPEN "$h1"
comments
printf '\n## PR\nPR head @ %s\n' "${h1:0:7}" >> "$f9"
eq status "$(nxt)" "in progress, HEAD is the PR head: status"
git commit -q --allow-empty -m pr2
h2=$(git rev-parse HEAD)
eq push-fix "$(nxt)" "a commit not pushed: push-fix"
git push -q origin GT-000909-x 2> /dev/null
eq comment-fix "$(nxt)" "pushed, no comment for HEAD: comment-fix"
comments "$(printf 'Verification @ %s: test pass' "${h2:0:9}")"
eq status "$(nxt)" "a comment for HEAD: status"
comments
awk '{ print } $0 == "## Implementation Log" { print "PR comment @ '"${h2:0:7}"'" }' "$f9" > "$tmp/f9" && cat "$tmp/f9" > "$f9"
eq status "$(nxt)" "PR comment @ HEAD in the Log: status"
st set GT-000909 Status review:in-progress > /dev/null
prr GT-000909 > /dev/null 2>&1
eq 3 $? "not in the PR phase"
prr GT-999999 > /dev/null 2>&1
eq 1 $? "no such run"
git switch -q "$back"
git branch -q -D GT-000909-x
git remote remove origin
rm -rf .tixforge/GT-000909 "$tmp/origin.git" "$GH_DIR/prs.json" "$GH_DIR/pr-view.json"

done_file
