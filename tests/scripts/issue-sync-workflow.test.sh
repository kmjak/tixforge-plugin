#!/usr/bin/env bash
# Tests of tixforge-issue-sync.yml (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

# --- tixforge-issue-sync.yml ----------------------------------------------
# The workflow's script, run as Actions runs it (bash -e) against a gh that
# serves issue states and a PR's commit messages and logs every write.
section="tixforge-issue-sync.yml"
wf="$tmp/issue-sync-run.sh"
awk '/^        run: \|$/ { on = 1; next } on { sub(/^          /, ""); print }' "$here/../templates/github/tixforge-issue-sync.yml" > "$wf"
wfbin="$tmp/wf-bin"
mkdir -p "$wfbin"
cat > "$wfbin/gh" << 'EOF'
#!/usr/bin/env bash
jqf=""; args=()
while [ $# -gt 0 ]; do
  case $1 in --jq) jqf=$2; shift 2 ;; --paginate) shift ;; *) args+=("$1"); shift ;; esac
done
set -- "${args[@]}"
case "$1 $2" in
  "issue view") n=$3; v=$(grep "^$n " "$WF_DIR/issues" | cut -d' ' -f2-); [ -n "$v" ] || exit 1; echo "$v" ;;
  "api repos/o/r/compare/"*) [ -z "${WF_API_FAIL:-}" ] || { echo "HTTP 403" >&2; exit 1; }; jq -r "$jqf" "$WF_DIR/compare.json" ;;
  "api repos/o/r/commits/"*) [ -z "${WF_PULLS_FAIL:-}" ] || { echo "HTTP 502" >&2; exit 1; }
    sha=${2#repos/o/r/commits/}; sha=${sha%/pulls}
    echo "$sha" >> "$WF_DIR/pulls-asked"
    if [ -f "$WF_DIR/pulls-$sha.json" ]; then jq -r "$jqf" "$WF_DIR/pulls-$sha.json"; fi ;;
  "issue list") awk '$2 == "OPEN" && $3 ~ /tixforge:merged/ { print $1 }' "$WF_DIR/issues" ;;
  "issue edit") echo "$*" >> "$WF_DIR/calls" ;;
  "issue close") echo "$*" >> "$WF_DIR/calls"; sed "s/^$3 OPEN /$3 CLOSED /" "$WF_DIR/issues" > "$WF_DIR/t" && mv "$WF_DIR/t" "$WF_DIR/issues" ;;
  *) echo "wf gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$wfbin/gh"
WF_DIR="$tmp/wf"
mkdir -p "$WF_DIR"
# wfrun <base> <body> [action] [draft]: a PR event (merged when closed) into
# <base>, the default branch being main. Prints the writes; wf_code reads
# the exit code.
wf_code() { cat "$WF_DIR/code"; }
wfrun() {
  : > "$WF_DIR/calls"
  : > "$WF_DIR/pulls-asked"
  WF_DIR=$WF_DIR PATH="$wfbin:$PATH" EVENT=pull_request ACTION=${3:-closed} MERGED=true DRAFT=${4:-false} \
    PR_STATE=${5:-$([ "${3:-closed}" = closed ] && echo closed || echo open)} BODY=$2 PR_URL=https://github.com/o/r/pull/9 \
    BASE_REF=$1 BASE_SHA=b0 HEAD_SHA=h1 DEFAULT_BRANCH=main GH_REPO=o/r \
    bash -e "$wf" > /dev/null 2>&1
  echo $? > "$WF_DIR/code"
  cat "$WF_DIR/calls"
}
# wfissue <reason> <labels>: the issue closed event of #2.
wfissue() {
  : > "$WF_DIR/calls"
  WF_DIR=$WF_DIR PATH="$wfbin:$PATH" EVENT=issues ACTION=closed ISSUE=2 ISSUE_REASON=$1 ISSUE_LABELS=$2 \
    bash -e "$wf" > /dev/null 2>&1
  cat "$WF_DIR/calls"
}
printf '1 OPEN tixforge:in-review\n2 OPEN tixforge:merged\n3 OPEN tixforge:in-review\n4 OPEN tixforge:merged\n5 CLOSED tixforge:merged\n6 OPEN tixforge:merged\n' > "$WF_DIR/issues"
printf '{"commits": []}' > "$WF_DIR/compare.json"
out=$(wfrun develop "Closes #1")
eq 0 "$(wf_code)" "into develop: exit 0"
has "issue edit 1 --remove-label tixforge:in-review --add-label tixforge:merged" "$out" "into develop: merged"
case "$out" in *"issue close"*) ng "into develop: not closed" ;; *) ok ;; esac
out=$(wfrun main "Closes #1")
has "--add-label tixforge:done" "$out" "into main: done"
has "issue close 1" "$out" "into main: closed"
# A release PR: its commits' messages and the PRs that brought them into
# develop name the issues; only open tixforge:merged ones, by whole words.
jq -n '{commits: [
  {sha: "s1", commit: {message: "feat: a\n\nCloses #2"}},
  {sha: "s2", commit: {message: "fix: b (squashed, no trailer)"}},
  {sha: "s3", commit: {message: "chore: hotfix #4, hot_fix #4, Fixes: #7"}}]}' > "$WF_DIR/compare.json"
printf '[{"body": "Resolves #6", "merged_at": "x"}, {"body": "Closes #4", "merged_at": null}]' > "$WF_DIR/pulls-s2.json"
printf '[{"body": "Closes #5", "merged_at": "x"}]' > "$WF_DIR/pulls-s1.json"
wfissues() { printf '1 OPEN tixforge:in-review\n2 OPEN tixforge:merged\n3 OPEN tixforge:in-review\n4 OPEN tixforge:merged\n5 CLOSED tixforge:merged\n6 OPEN tixforge:merged\n7 OPEN tixforge:merged\n' > "$WF_DIR/issues"; }
wfissues
out=$(wfrun main "Release 1.2.0")
eq 0 "$(wf_code)" "release: exit 0"
has "issue edit 2 --remove-label tixforge:merged --add-label tixforge:done" "$out" "release: a merged issue in a commit message is done"
has "issue close 2" "$out" "release: and closed"
has "issue close 6" "$out" "release: one named only by the PR that brought the commit (squash) too"
case "$out" in *"issue edit 4"*) ng "release: hotfix #4 / hot_fix #4 and an unmerged PR's body are not links" ;; *) ok ;; esac
has "issue close 7" "$out" "release: Fixes: #7 (with a colon) is a link, as GitHub reads it"
case "$out" in *"issue edit 3"*) ng "release: an issue not in tixforge:merged is left" ;; *) ok ;; esac
case "$out" in *"issue edit 5"*) ng "release: a closed issue is left" ;; *) ok ;; esac
wfissues
out=$(wfrun main "Release, Closes #2")
eq 1 "$(printf '%s\n' "$out" | grep -c 'issue close 2')" "release: an issue the body names too is closed once"
wfissues
out=$(WF_API_FAIL=1 wfrun main "Closes #1")
eq 1 "$([ "$(wf_code)" -ne 0 ] && echo 1)" "release: a failed API call fails the job"
has "issue close 1" "$out" "release: the PR's own issue moves before the release part fails"
wfissues
WF_PULLS_FAIL=1 wfrun main "Release" > /dev/null
eq 1 "$([ "$(wf_code)" -ne 0 ] && echo 1)" "release: a failed pulls call fails the job"
# The PR bodies are read only while a waiting issue is not found yet, and
# nothing is read with no issue waiting.
jq -n '{commits: [{sha: "s1", commit: {message: "Closes #2"}}, {sha: "s2", commit: {message: "x"}}]}' > "$WF_DIR/compare.json"
printf '2 OPEN tixforge:merged\n' > "$WF_DIR/issues"
wfrun main "Release" > /dev/null
eq "" "$(cat "$WF_DIR/pulls-asked")" "release: no PR bodies once every waiting issue is found"
printf '2 CLOSED tixforge:done\n' > "$WF_DIR/issues"
eq "" "$(wfrun main "Release")" "release: nothing waiting, nothing read or written"
eq "" "$(cat "$WF_DIR/pulls-asked")" "release: nothing waiting, no PR bodies"
printf '{"commits": []}' > "$WF_DIR/compare.json"
eq "" "$(wfrun main "Release")" "release: no commits, no linked issue: nothing"
wfissues
eq "" "$(wfrun develop "Closes #1" edited false closed)" "an edit of a closed PR moves nothing (W4)"
wfissues
eq "" "$(wfrun develop "Closes #2" opened)" "opened: a merged issue stays merged (a release PR links it again)"
has "--add-label tixforge:in-review" "$(wfrun develop "Closes #1" opened)" "opened: in review"
eq "" "$(wfrun develop "Closes #1" opened true)" "a draft does not move it"
has "--add-label tixforge:done" "$(wfissue completed tixforge:merged)" "issue closed as completed while merged: done"
eq "" "$(wfissue not_planned tixforge:merged)" "issue closed as not planned: left"

done_file
