#!/usr/bin/env bash
# Tests of review.sh: the Review kept as data (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

section="review.sh"
rv() { bash "$scripts/review.sh" "$@"; }
st init GT-000920 > /dev/null
d=.tixforge/GT-000920
f=$d/state.md
git commit -q --allow-empty -m r1
h1=$(git rev-parse --short HEAD)
review() { awk '$0 == "## Review" { on = 1; next } on && /^## / { exit } on' "$f"; }

# A report as the reviewers write it (references/review.md).
cat > "$tmp/rep-r" << 'EOF'
- **R1 [未実装]** 受け入れ条件 2 の処理が無い
  - 合意側：plan.md #2
  - 実装側：該当する変更なし
  - Kind: missing
  - Severity: high
  - Confidence: high
- **R2 [合意外の変更]** 関係ないファイルを変えた
  - 合意側：ticket.md 対象外
  - 実装側：src/x.js:3
  ```text
  - **R9 [x]** in a fence
  ```
  - Kind: out-of-scope
  - Severity: low
  - Confidence: medium
EOF
printf '指摘なし\n' > "$tmp/rep-q"

eq 1 "$(rv round GT-000920 "Verification @ $h1: test pass")" "round: the first is 1"
eq "Round 1 reviewer: 2 findings" "$(rv add GT-000920 1 reviewer "$tmp/rep-r")" "add: one finding per top-level item (a fenced one is body)"
eq "Round 1 quality: 0 findings" "$(rv add GT-000920 1 quality "$tmp/rep-q")" "add: 指摘なし is no finding"
rv add GT-000920 1 quality "$tmp/rep-q" > /dev/null 2>&1
eq 4 $? "add: a report once per reviewer and round"
has "- **R1 [未実装]** 受け入れ条件 2 の処理が無い" "$(review)" "render: the item as written"
has "#### 合意とのズレ（tixforge:reviewer）" "$(review)" "render: the section heading in the person's language"
has "$(printf '#### 品質（tixforge:quality-reviewer）\n指摘なし')" "$(review)" "render: no finding"
has "  - **R9 [x]** in a fence" "$(cat "$d/review/1-R2.md")" "the fenced lines stay in the body"

# Broken reports are refused whole.
printf -- '- **R1 [x]** a\n  - Kind: nope\n  - Severity: big\n' > "$tmp/bad"
rv round GT-000920 "Verification @ $h1: test pass" > /dev/null
out=$(rv add GT-000920 2 reviewer "$tmp/bad" 2>&1)
eq 3 $? "add: a broken report exits 3"
has "Kind nope is not one of" "$out" "add: says which key"
has "Severity must be" "$out" "add: every problem at once"
has "Confidence must be" "$out" "add: a missing Confidence"
printf -- '- **Q1 [バグ]** a\n  - Kind: missing\n  - Severity: low\n  - Confidence: low\n' > "$tmp/bad"
has "is not one of" "$(rv add GT-000920 2 quality "$tmp/bad" 2>&1)" "add: Kind is the reviewer's own word"
printf -- '- **Q1 [未修正]** a\n  - Kind: unfixed\n  - Severity: low\n  - Confidence: low\n' > "$tmp/bad"
has "needs Refers" "$(rv add GT-000920 2 quality "$tmp/bad" 2>&1)" "add: unfixed needs Refers"
printf -- '- **R1 [バグ]** a\n  - Kind: bug\n  - Severity: low\n  - Confidence: low\n' > "$tmp/bad"
has "start with Q" "$(rv add GT-000920 2 quality "$tmp/bad" 2>&1)" "add: the quality reviewer's ids are Q"
eq 0 "$(awk -F'\t' '$1 == "finding" && $2 == 2' "$d/review.tsv" | wc -l | tr -d ' ')" "nothing was written for the refused reports"
rv drop GT-000920 1 > /dev/null 2>&1
eq 4 $? "drop: only the latest round"
rv drop GT-000920 2 > /dev/null
eq 1 "$(awk -F'\t' '$1 == "round"' "$d/review.tsv" | wc -l | tr -d ' ')" "drop: the round is gone"

# judge: the table of review.md step 6.
note() { printf -- '- 推奨：%s\n- 受け入れた場合：%s\n' "$1" "$2" > "$tmp/note"; }
note 修正 "条件 2 を満たさない"
eq "Auto-fix: ○" "$(rv judge GT-000920 1 R1 fix yes "$tmp/note")" "judge: fix, one way inside the agreement, Round 1 -> ○"
eq "Auto-fix: △" "$(rv judge GT-000920 1 R1 fix no "$tmp/note")" "judge: fix, not one way -> △"
eq "Auto-fix: ○" "$(rv judge GT-000920 1 R1 fix yes "$tmp/note")" "judge: judged again"
note 受け入れ "x.js が少し変わる"
eq "Auto-fix: ×" "$(rv judge GT-000920 1 R2 accept yes "$tmp/note")" "judge: accept, low Severity -> ×"
has "$(printf -- '  - 推奨：修正\n  - 受け入れた場合：条件 2 を満たさない\n  - Auto-fix: ○\n  - Decision: fix (auto)')" "$(review)" "render: note, Auto-fix, Decision under the item"
rv judge GT-000920 1 R7 fix yes "$tmp/note" > /dev/null 2>&1
eq 4 $? "judge: no such finding"
# The rest of the table, on findings of a second round.
rv round GT-000920 "Verification @ $h1: test pass" > /dev/null
cat > "$tmp/rep2" << 'EOF'
- **Q1 [バグ]** high and accepted
  - Kind: bug
  - Severity: high
  - Confidence: high
- **Q2 [バグ]** low confidence
  - Kind: bug
  - Severity: medium
  - Confidence: low
- **Q3 [未修正]** Round 1 R1 still
  - Kind: unfixed
  - Refers: Round 1 R1
  - Severity: high
  - Confidence: high
EOF
rv add GT-000920 2 quality "$tmp/rep2" > /dev/null
rv add GT-000920 2 reviewer "$tmp/rep-q" > /dev/null
eq "Auto-fix: △" "$(rv judge GT-000920 2 Q1 accept yes "$tmp/note")" "judge: accept with high Severity -> △"
eq "Auto-fix: △" "$(rv judge GT-000920 2 Q2 fix yes "$tmp/note")" "judge: fix with low Confidence -> △"
eq "Auto-fix: △" "$(rv judge GT-000920 2 Q3 accept yes "$tmp/note")" "judge: unfixed -> △ whatever the recommendation"
rv round GT-000920 "Verification @ $h1: test pass" > /dev/null
printf -- '- **Q1 [バグ]** r3\n  - Kind: bug\n  - Severity: low\n  - Confidence: high\n' > "$tmp/rep3"
rv add GT-000920 3 quality "$tmp/rep3" > /dev/null
rv add GT-000920 3 reviewer "$tmp/rep-q" > /dev/null
eq "Auto-fix: △" "$(rv judge GT-000920 3 Q1 fix yes "$tmp/note")" "judge: a fix from Round 3 on -> △"

# decide, fixed, demote; review-next on the data.
eq "step: 9" "$(st review-next GT-000920 | sed -n 1p)" "review-next: △ open -> 9"
rv decide GT-000920 2 Q1 accept "今回は直さない"
rv decide GT-000920 2 Q2 fix
rv decide GT-000920 2 Q3 fix
rv decide GT-000920 3 Q1 accept
has "  - Decision: accept 今回は直さない" "$(review)" "decide: the reason on the Decision line"
eq "step: implement" "$(st review-next GT-000920 | sed -n 1p)" "review-next: fixes to make -> implement"
rv judge GT-000920 2 Q1 fix yes "$tmp/note" > /dev/null 2>&1
eq 4 $? "judge: not over the user's Decision"
rv fixed GT-000920 1 R2 abc1234 > /dev/null 2>&1
eq 4 $? "fixed: only a finding decided fix"
git commit -q --allow-empty -m fix
h2=$(git rev-parse --short HEAD)
rv fixed GT-000920 1 R1 "$h2"
rv fixed GT-000920 2 Q2 "$h2"
rv fixed GT-000920 2 Q3 "$h2" --no-commit
has "  - Fixed @ $h2 (no commit)" "$(review)" "fixed: --no-commit"
eq "step: 3" "$(st review-next GT-000920 | sed -n 1p)" "review-next: HEAD ahead of the round -> 3"
rv round GT-000920 "Verification @ $h2: test pass" > /dev/null
rv add GT-000920 4 reviewer "$tmp/rep-q" > /dev/null
eq "step: 3" "$(st review-next GT-000920 | sed -n 1p)" "review-next: a round with one report is cut short -> 3"
has "drop: Round 4" "$(st review-next GT-000920)" "review-next: and dropped"
rv add GT-000920 4 quality "$tmp/rep-q" > /dev/null
eq "step: 10" "$(st review-next GT-000920 | sed -n 1p)" "review-next: all decided and fixed -> 10"
# demote: a ○ that cannot be fixed goes back to △.
rv round GT-000920 "Verification @ $h2: test pass" > /dev/null
printf -- '- **Q1 [バグ]** r5\n  - Kind: bug\n  - Severity: low\n  - Confidence: high\n' > "$tmp/rep5"
rv add GT-000920 5 quality "$tmp/rep5" > /dev/null
rv add GT-000920 5 reviewer "$tmp/rep-q" > /dev/null
rv judge GT-000920 5 Q1 fix yes "$tmp/note" > /dev/null
eq "step: 9" "$(st review-next GT-000920 | sed -n 1p)" "review-next: a △ of Round 5 is asked"
st init GT-000922 > /dev/null
rv round GT-000922 "Verification @ $h2: test pass" > /dev/null
rv add GT-000922 1 quality "$tmp/rep5" > /dev/null
rv add GT-000922 1 reviewer "$tmp/rep-q" > /dev/null
rv judge GT-000922 1 Q1 fix yes "$tmp/note" > /dev/null
rv demote GT-000922 1 Q1 "直し方が合意の外に出る"
has "  - 直し方が合意の外に出る" "$(awk '$0 == "## Review" { on = 1; next } on && /^## / { exit } on' .tixforge/GT-000922/state.md)" "demote: the reason under the finding"
eq "step: 9" "$(st review-next GT-000922 | sed -n 1p)" "review-next: a demoted finding is asked"
rv demote GT-000922 1 Q1 "again" > /dev/null 2>&1
eq 4 $? "demote: only a ○"
rm -rf .tixforge/GT-000922

# own: the implementer's finding.
printf -- '- **X9 [見落とし]** 自分で気づいた\n  - Kind: test\n  - Severity: low\n  - Confidence: high\n' > "$tmp/own"
eq I1 "$(rv own GT-000920 5 "$tmp/own")" "own: numbered I1"
eq I2 "$(rv own GT-000920 5 "$tmp/own")" "own: then I2"
has "#### 実装者による追加" "$(review)" "own: its own section"
has "- **I2 [見落とし]** 自分で気づいた" "$(review)" "own: the id given here"

# list
out=$(rv list GT-000920 ask)
eq "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "list ask: the △ without a Decision"
eq "5" "$(printf '%s\n' "$out" | sed -n 1p | cut -f1)" "list ask: round first column"
has "$d/review/5-Q1.md" "$out" "list: the body file"
eq "R1 R2" "$(rv list GT-000920 auto | cut -f2 | paste -sd' ' -)" "list auto: ○ and × decided by the table"

# The notes at the end of ## Review stay; English headings.
st set GT-000920 Status review:in-progress > /dev/null
st pass GT-000920 review > /dev/null
rv render GT-000920
has "> ゲート自動通過" "$(review)" "render: a note at the end stays"
printf 'language: en\n' > .tixforge/config.local.yml
rv render GT-000920
has "#### Agreement (tixforge:reviewer)" "$(review)" "render: English headings"
has "No findings" "$(review)" "render: English no finding"
rm -f .tixforge/config.local.yml

# Events: a review_round per round when Review is left; a rewind moves the
# data with ## Review into history.
n=$(grep -c '"review_round"' "$evf")
st set GT-000920 Status review:in-progress > /dev/null
st set GT-000920 Status implement:in-progress > /dev/null
eq $((n + 5)) "$(grep -c '"review_round"' "$evf")" "events: a review_round per round"
eq '{"id":"R1","label":"未実装","auto_fix":"fix","decision":"fix (auto)","fixed":"'"$h2"'"}' \
  "$(grep '"review_round"' "$evf" | grep '"round":1' | tail -1 | jq -c '.findings[0]')" "events: from the data"
eq '"Q3"' "$(grep '"review_round"' "$evf" | grep '"round":2' | tail -1 | jq -c '.findings[2].id')" "events: every finding"
hist=$(st rewind GT-000920 implement)
[ -f "${hist%.md}-review/review.tsv" ] && ok || ng "rewind: review.tsv goes to history"
[ -d "${hist%.md}-review/review" ] && ok || ng "rewind: the bodies go too"
[ ! -e "$d/review.tsv" ] && ok || ng "rewind: no Review data left"
eq 1 "$(rv round GT-000920 "Verification @ $h2: test pass")" "after a rewind, rounds start at 1"
st release GT-000920 > /dev/null
[ ! -e "$d" ] && ok || ng "release: the run folder with its Review data is gone"
rv round GT-999999 x > /dev/null 2>&1
eq 1 $? "no such run"

# migrate 3 -> 4: ## Review written by hand (3.1, and 3.0's decision lines).
section="review.sh migrate"
st init GT-000921 > /dev/null
f21=.tixforge/GT-000921/state.md
git commit -q --allow-empty -m m1
m1=$(git rev-parse --short HEAD)
cat > "$tmp/old-review" << EOF
## Review

### Round 1
Verification @ $m1: test pass

#### 合意とのズレ（tixforge:reviewer）
- **R1 [未実装]** a
  - 重大度：高
  - 推奨：修正
  - 決定：修正
- **R2 [相違]** b
  - 決定：受け入れ — 誤検知

#### 品質（tixforge:quality-reviewer）
指摘なし

### Round 2
Verification @ $m1: test pass

#### 合意とのズレ（tixforge:reviewer）
- **R1 [未実装]** c
  - 決定：修正

#### 品質（tixforge:quality-reviewer）
- **Q1 [バグ]** d
  - Auto-fix: ○
  - Decision: fix (auto)
  - Fixed @ $m1
- 実装者による追加：e
  - Auto-fix: △
EOF
awk -v r="$tmp/old-review" '$0 == "## Review" { while ((getline l < r) > 0) print l; skip = 1; next } /^## / { skip = 0 } !skip' "$f21" > "$tmp/f21"
sed 's/^| Format  | 4 /| Format  | 3 /' "$tmp/f21" > "$f21"
has "- keep ## Review as data (2 rounds" "$(st migrate --check GT-000921)" "migrate --check: the Review step"
eq "format 3 -> 4: $f21" "$(st migrate GT-000921)" "migrate 3 -> 4"
eq 4 "$(st get GT-000921 Format)" "migrate: Format 4"
t21=.tixforge/GT-000921/review.tsv
fld() { awk -F'\t' -v r="$1" -v id="$2" -v k="$3" '$1 == "finding" && $2 == r && $3 == id { print $k }' "$t21"; }
eq "fix|3.0" "$(fld 1 R1 12)|$(fld 1 R1 14)" "3.0 修正 in an earlier round: fixed"
eq "accept|誤検知" "$(fld 1 R2 12)|$(fld 1 R2 13)" "3.0 受け入れ with its reason"
eq "fix|-" "$(fld 2 R1 12)|$(fld 2 R1 14)" "3.0 修正 in the latest round with HEAD at its Verification: not fixed yet"
eq "fix|fix (auto)|$m1" "$(fld 2 Q1 11)|$(fld 2 Q1 12)|$(fld 2 Q1 14)" "3.1 keys"
eq "implementer|ask" "$(fld 2 I1 4)|$(fld 2 I1 11)" "an item without an id is the implementer's"
has "  - 重大度：高" "$(cat .tixforge/GT-000921/review/1-R1.md)" "the other lines stay in the body"
eq "step: 9" "$(st review-next GT-000921 | sed -n 1p)" "review-next after migrate (the open △ before the 3.0 fix)"
rm -rf .tixforge/GT-000921

done_file
