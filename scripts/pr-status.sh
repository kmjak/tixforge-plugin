#!/usr/bin/env bash
# Summarize a PR's state for tixforge Phase 6.
#
# Usage: pr-status.sh <pr-url | pr-number | branch>
#
# First line is the verdict (one of):
#   merged             PR is merged
#   closed             PR is closed without merge
#   conflict           has merge conflicts with the base branch
#   ci_failing         at least one check failed
#   changes_requested  a reviewer requested changes (latest review per reviewer)
#   approved           approved, all checks passed (or none), no conflicts
#   ready              not approved yet, but all checks passed (or none) and no conflicts;
#                      done for review.required: false, pending otherwise
#   pending            anything else (a draft, awaiting review, checks running,
#                      mergeability unknown)
# Following lines are key: value details. `ci: none` means no check is
# registered at all: the repository has no CI, or the checks of a PR just
# opened have not started yet; the caller tells the two apart.
#
# Precedence: merged > closed > conflict > ci_failing > changes_requested > approved > ready > pending
#
# TF_PR_JSON=<file> reads the `gh pr view --json` output from a file
# instead of calling gh (for tests).
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if [ $# -ne 1 ]; then
  echo "usage: $(basename "$0") <pr-url | pr-number | branch>" >&2
  exit 2
fi

filter="${PR_JUDGE_JQ}"'
    . as $p | pr_judge
    | .verdict,
      "url: \($p.url)",
      "review: \(.review)",
      "ci: \(.ci)",
      "mergeable: \($p.mergeable)",
      "draft: \($p.isDraft // false)",
      "failing_checks: \(.failing | join(", "))",
      "changes_requested_by: \(.requesters | join(", "))",
      "approved_by: \(.approvers | join(", "))",
      "commented_by: \(.commenters | join(", "))"
  '

if [ -n "${TF_PR_JSON:-}" ]; then
  jq -r "$filter" "$TF_PR_JSON"
else
  gh pr view "$1" \
    --json url,state,isDraft,mergeable,reviewDecision,latestReviews,statusCheckRollup \
    --jq "$filter"
fi
