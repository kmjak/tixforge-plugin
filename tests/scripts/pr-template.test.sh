#!/usr/bin/env bash
# Tests of pr-template.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- pr-template.sh ---------------------------------------------------------
section="pr-template.sh"
pt="$tmp/prt"
git init -q "$pt"
eq "path: none" "$(cd "$pt" && bash "$scripts/pr-template.sh")" "no template"
mkdir -p "$pt/.github/PULL_REQUEST_TEMPLATE"
eq "$(printf 'path: none\ndirectory: .github/PULL_REQUEST_TEMPLATE/')" "$(cd "$pt" && bash "$scripts/pr-template.sh")" "only the directory"
# Each place alone (compared without case: macOS file systems ignore it),
# and tixforge's order when there are several.
for p in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md pull_request_template.md; do
  rm -rf "$pt/.github" "$pt/docs" "$pt/pull_request_template.md"
  mkdir -p "$pt/$(dirname "$p")" "$pt/docs" && : > "$pt/$p"
  got=$(cd "$pt/docs" && bash "$scripts/pr-template.sh")
  [ "$(printf '%s' "$got" | tr '[:upper:]' '[:lower:]')" = "$(printf 'path: %s' "$p" | tr '[:upper:]' '[:lower:]')" ] && ok || ng "found: $p, got [$got]"
done
# With two of them, the one listed first in pr-template.sh wins.
for pair in ".github/pull_request_template.md docs/pull_request_template.md" \
  ".github/pull_request_template.md pull_request_template.md" \
  "docs/pull_request_template.md pull_request_template.md"; do
  first=${pair% *}
  second=${pair#* }
  (
    rm -rf "$pt/.github" "$pt/docs" "$pt/pull_request_template.md"
    mkdir -p "$pt/.github" "$pt/docs"
    : > "$pt/$first"
    : > "$pt/$second"
  )
  eq "path: $first" "$(cd "$pt" && bash "$scripts/pr-template.sh")" "order: $first before $second"
done
(cd "$tmp" && bash "$scripts/pr-template.sh" > /dev/null 2>&1)
eq 2 $? "not in a repository"

done_file
