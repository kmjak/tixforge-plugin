#!/usr/bin/env bash
# Tests of pr-status.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

# --- pr-status.sh ----------------------------------------------------------
section="pr-status.sh"
prs() { TF_PR_JSON="$tmp/pr.json" bash "$scripts/pr-status.sh" x | sed -n 1p; }
# pr <state> <mergeable> <reviewDecision> <latestReviews-json> <checks-json>
pr() {
  jq -n --arg s "$1" --arg m "$2" --arg d "$3" --argjson r "$4" --argjson c "$5" \
    '{url: "https://github.com/o/r/pull/9", state: $s, isDraft: false, mergeable: $m, reviewDecision: $d, latestReviews: $r, statusCheckRollup: $c}' > "$tmp/pr.json"
}
ok_check='[{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"SUCCESS"}]'
bad_check='[{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"FAILURE"}]'
run_check='[{"__typename":"CheckRun","name":"test","status":"IN_PROGRESS","conclusion":""}]'
approved='[{"state":"APPROVED","author":{"login":"a"}}]'
pr MERGED MERGEABLE "" '[]' "$ok_check"
eq merged "$(prs)" "merged"
pr CLOSED MERGEABLE "" '[]' "$ok_check"
eq closed "$(prs)" "closed"
pr OPEN CONFLICTING APPROVED "$approved" "$ok_check"
eq conflict "$(prs)" "conflict"
pr OPEN MERGEABLE APPROVED "$approved" "$bad_check"
eq ci_failing "$(prs)" "ci failing"
pr OPEN MERGEABLE CHANGES_REQUESTED '[{"state":"CHANGES_REQUESTED","author":{"login":"a"}}]' "$ok_check"
eq changes_requested "$(prs)" "changes requested"
pr OPEN MERGEABLE APPROVED "$approved" "$ok_check"
eq approved "$(prs)" "approved"
pr OPEN MERGEABLE "" '[]' "$ok_check"
eq ready "$(prs)" "ready without review"
pr OPEN MERGEABLE "" '[]' '[]'
eq ready "$(prs)" "ready, no checks"
pr OPEN MERGEABLE "" '[]' "$run_check"
eq pending "$(prs)" "checks running"
pr OPEN UNKNOWN "" '[]' "$ok_check"
eq pending "$(prs)" "mergeability unknown"
# A draft cannot be merged: never ready or approved.
pr OPEN MERGEABLE APPROVED "$approved" "$ok_check"
jq '.isDraft = true' "$tmp/pr.json" > "$tmp/pr2.json" && mv "$tmp/pr2.json" "$tmp/pr.json"
eq pending "$(prs)" "draft"
has "draft: true" "$(TF_PR_JSON="$tmp/pr.json" bash "$scripts/pr-status.sh" x)" "draft detail"
# No check at all is reported as such, so the caller can tell it from success.
pr OPEN MERGEABLE "" '[]' '[]'
has "ci: none" "$(TF_PR_JSON="$tmp/pr.json" bash "$scripts/pr-status.sh" x)" "no checks detail"
pr OPEN MERGEABLE "" '[]' "$ok_check"
has "ci: success" "$(TF_PR_JSON="$tmp/pr.json" bash "$scripts/pr-status.sh" x)" "checks detail"

done_file
