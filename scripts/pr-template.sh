#!/usr/bin/env bash
# The repository's default pull request template, the one GitHub fills a new
# PR with. dev's PR step writes the body along its headings; init adds
# tixforge's headings to it (or creates it).
#
#   pr-template.sh
#
# Prints `path: <path from the repository root>` for the first of these
# (tixforge's order; GitHub's docs do not say which wins when there are
# several)
#   .github/pull_request_template.md  .github/PULL_REQUEST_TEMPLATE.md
#   docs/pull_request_template.md     pull_request_template.md
# or `path: none`. When there is none but .github/PULL_REQUEST_TEMPLATE/ (a
# directory of templates, which GitHub does not use by default) exists, a
# second line `directory: .github/PULL_REQUEST_TEMPLATE/` says so.
#
# Exit: 0 ok, 2 usage or not in a git repository.
set -uo pipefail

[ $# -eq 0 ] || {
  echo "usage: pr-template.sh" >&2
  exit 2
}
top=$(git rev-parse --show-toplevel 2> /dev/null) || {
  echo "not in a git repository" >&2
  exit 2
}
for p in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md pull_request_template.md; do
  if [ -f "$top/$p" ]; then
    echo "path: $p"
    exit 0
  fi
done
echo "path: none"
[ -d "$top/.github/PULL_REQUEST_TEMPLATE" ] && echo "directory: .github/PULL_REQUEST_TEMPLATE/"
exit 0
