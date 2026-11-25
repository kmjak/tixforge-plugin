#!/usr/bin/env bash
# Tests of v2 data (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

# --- v2 data ---------------------------------------------------------------
# What v2 left in users' repositories: the plugin update does not rewrite it.
section="v2 data"
# A run in Implement, as v2.2.0 wrote it (format 2: no Format row, placeholder
# comments under the unwritten sections and above a written one). Keep it as
# it is: it stands for files already on users' disks.
cat > "$tmp/v2-state.md" << 'EOF'
# Run: GT-000102

| Field   | Value                              |
|---------|------------------------------------|
| Status  | implement:in-progress              |
| Branch  | GT-000102-logout                   |
| Base    | develop                            |
| Updated | 2026-10-21 16:40                   |

## Research
<!-- Phase 1: organized understanding of the ticket + relevant context -->
ログアウトの要件を整理した。

## Approach
セッションを消してトップに戻す。

## Plan
- Branch: GT-000102-logout
- commit 1: ログアウトのボタン

## Implementation Log
- commit 1: abc1234

## Review
<!-- Phase 5: reviewer findings as rounds, with recommendations and decisions -->

## PR
<!-- Phase 6: title, target branch, URL, review outcome -->
EOF
f2=.tixforge/GT-000102/state.md
mkdir -p .tixforge/GT-000102
cp "$tmp/v2-state.md" "$f2"
eq "$(printf 'format 2 -> 4\n- remove the placeholder comments (3)\n- add the Format row')" \
  "$(st migrate --check GT-000102)" "migrate --check lists the changes"
cmp -s "$tmp/v2-state.md" "$f2" && ok || ng "--check does not write"
eq implement:in-progress "$(st get GT-000102)" "a v2 file is read as it is"
eq "format 2 -> 4: $f2" "$(st migrate GT-000102)" "migrate"
eq 4 "$(st get GT-000102 Format)" "migrate writes the Format"
has "| Format  | 4" "$(grep -A1 '^| Updated' "$f2" | sed -n 2p)" "the Format row ends the header table"
eq 0 "$(grep -c '<!--' "$f2")" "migrate removes the placeholders"
eq "$(grep -v '^<!-- Phase' "$tmp/v2-state.md")" "$(grep -v '^| Format ' "$f2")" \
  "migrate changes nothing else (sections, Status, Updated)"
eq "" "$(st migrate --check GT-000102)" "nothing left to migrate"
st rewind GT-000102 plan > /dev/null && ok || ng "rewind a migrated file"
eq "Research|Approach|Plan|Implementation Log|Review|PR" \
  "$(sed -n 's/^## //p' "$f2" | paste -sd'|' -)" "the six sections stay, in order"
# A table of a section's own with a Format row is not the header's.
cp "$tmp/v2-state.md" "$f2"
printf '| Format | 説明 |\n|---|---|\n| Format | JSON |\n' >> "$f2"
eq "format 2 -> 4" "$(st migrate --check GT-000102 | sed -n 1p)" "a Format row in a section is not the format"
# All sections written: no placeholders to remove, so no line for them.
grep -v '^<!-- Phase' "$tmp/v2-state.md" > "$f2"
eq "$(printf 'format 2 -> 4\n- add the Format row')" "$(st migrate --check GT-000102)" \
  "migrate --check: no line for zero placeholders"
# A done or canceled run goes no further: --check asks for nothing.
for s in done canceled; do
  sed "s/implement:in-progress /$(printf '%-22s' "$s")/" "$tmp/v2-state.md" > "$f2"
  eq "$s" "$(st get GT-000102)" "a $s v2 file"
  eq "" "$(st migrate --check GT-000102)" "migrate --check: nothing for a $s run"
done
# Only v2's own comment lines go: the user's comments, and a placeholder
# quoted in a fence, stay.
{
  sed -n '1,/^## Research/p' "$tmp/v2-state.md"
  printf '<!-- my note -->\n```\n<!-- Phase 2: chosen implementation approach and key design decisions -->\n```\n'
  sed -n '/^## Research/,$p' "$tmp/v2-state.md" | sed 1d
} > "$f2"
st migrate GT-000102 > /dev/null
has "<!-- my note -->" "$(cat "$f2")" "a comment of the user's is kept"
eq 1 "$(grep -c '^<!-- Phase 2' "$f2")" "a fenced placeholder is kept"
sed 's/^| Format  | 4 /| Format  | 9 /' "$f2" > "$tmp/f9" && cat "$tmp/f9" > "$f2"
st migrate --check GT-000102 2> /dev/null
eq 5 $? "a newer format: update the plugin"
sed 's/^| Format  | 9 /| Format  | x /' "$f2" > "$tmp/f9" && cat "$tmp/f9" > "$f2"
st migrate GT-000102 2> /dev/null
eq 2 $? "a Format that is not a number"
rm -rf .tixforge/GT-000102

done_file
