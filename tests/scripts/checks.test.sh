#!/usr/bin/env bash
# Tests of checks.sh: the checks table and the manual checks kept as data
# (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

section="checks.sh"
ck() { bash "$scripts/checks.sh" "$@"; }
st init GT-000930 > /dev/null
d=.tixforge/GT-000930
f=$d/state.md
git commit -q --allow-empty -m c1
h1=$(git rev-parse --short HEAD)
sec() { awk -v s="## $1" '$0 == s { on = 1; next } on && /^## / { exit } on' "$f"; }
printf -- '- Base: main\n- commit 1: x\n' > "$tmp/planbody"
awk -v p="$tmp/planbody" '$0 == "## Plan" { print; while ((getline l < p) > 0) print l; next } { print }' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"

cat > "$tmp/table" << 'EOF'
| # | 受け入れ条件 | 確かめ方 | 種別 |
|---|---|---|---|
| 1 | ログインできる | `tests/login.test.ts`「ログインできる」 | 自動 |
| 2 | エラーが出る \| 赤字で | ログイン画面で確かめる | Claude（ブラウザ） |
| 3 | API が 401 を返す | curl で叩く | api |
| 4 | メールが届く | メールボックスで見る | ユーザー |
EOF
eq "4 rows" "$(ck put GT-000930 "$tmp/table")" "put: the rows"
has "<!-- tixforge:checks -->" "$(sec Plan)" "put: the table goes into ## Plan between marks"
has "| 2 | エラーが出る \\| 赤字で | ログイン画面で確かめる | Claude（ブラウザ） |" "$(sec Plan)" "render: a pipe in a cell stays escaped"
has "- commit 1: x" "$(sec Plan)" "render: the rest of ## Plan stays"
has "- #2 未確認（Claude（ブラウザ））" "$(sec 'Implementation Log')" "render: manual rows not checked yet in the Log"
case "$(sec 'Implementation Log')" in *"#1 "*) ng "render: auto rows are not manual records" ;; *) ok ;; esac
ck render GT-000930
eq 1 "$(grep -c '^<!-- tixforge:checks -->$' "$f")" "render again: one table"

# Refused tables write nothing.
printf '| 1 | a | b | 自動 |\n| 3 | c | d | auto |\n' > "$tmp/bad"
has "numbered 1, 2" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: rows in order"
printf '| 1 | a | b | manual |\n' > "$tmp/bad"
has "kind must be" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: a known kind"
printf '| 1 | a | 自動 |\n' > "$tmp/bad"
has "4 columns" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: four columns"
printf 'no table\n' > "$tmp/bad"
ck put GT-000930 "$tmp/bad" > /dev/null 2>&1
eq 3 $? "put: no rows"
eq 4 "$(grep -c '^check' "$d/checks.tsv")" "nothing written for refused tables"

# Manual checks.
printf '1. http://localhost:3000/login を開く\n2. 誤ったパスワードを入れる\n\n赤字でエラーが出た\n' > "$tmp/steps"
ck record GT-000930 2 ok "$h1" claude "$tmp/steps"
has "- #2 ok @ ${h1}（claude）" "$(sec 'Implementation Log')" "record: the result in the Log"
has "  1. http://localhost:3000/login を開く" "$(sec 'Implementation Log')" "record: the steps under it"
ck record GT-000930 1 ok "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 4 $? "record: not an auto row"
ck record GT-000930 9 ok "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 4 $? "record: no such row"
ck record GT-000930 2 fine "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 2 $? "record: ok, ng or skipped"
printf '環境が無い\n' > "$tmp/why"
ck record GT-000930 3 skipped "$h1" claude "$tmp/why"
ck put GT-000930 "$tmp/table" > /dev/null 2>&1
eq 4 $? "put: refused once a check is recorded"

# Re-checks: review-next waits for them, a record clears them.
ck recheck GT-000930 2
has "Review の後にやり直す" "$(sec 'Implementation Log')" "recheck: shown in the Log"
eq "M 2 0" "$(ck _facts GT-000930)" "_facts: the row waiting"
has "recheck: #2" "$(st review-next GT-000930)" "review-next: lists it"
ck record GT-000930 2 ok "$h1" claude "$tmp/steps"
eq "" "$(ck _facts GT-000930)" "record clears the re-check"
ck recheck GT-000930 1 > /dev/null 2>&1
eq 4 $? "recheck: not an auto row"

# show and pr
eq "2	browser	ok	$h1	claude	0	エラーが出る | 赤字で	ログイン画面で確かめる	$d/checks/2.md" \
  "$(ck show GT-000930 | sed -n 2p)" "show: a row"
out=$(ck pr GT-000930 "Verification @ $h1: test pass")
has "- [x] ログインできる — \`tests/login.test.ts\`「ログインできる」" "$out" "pr: an auto row is checked when the verification passed"
has "- [x] エラーが出る | 赤字で — ログイン画面で確かめる（ok @ $h1, claude）" "$out" "pr: a manual ok"
has "- [ ] API が 401 を返す — curl で叩く（skipped @ $h1, claude）" "$out" "pr: skipped is not checked"
has "- [ ] メールが届く — メールボックスで見る（not checked）" "$out" "pr: not checked yet"
has "$(printf '### エラーが出る | 赤字で（#2）\n1. http://localhost:3000/login を開く')" "$out" "pr: the manual section with its steps"
has "- [ ] ログインできる" "$(ck pr GT-000930 "Verification @ $h1: test fail")" "pr: not checked when a test failed"
has "- [ ] ログインできる" "$(ck pr GT-000930 "Verification @ $h1+dirty: test pass")" "pr: not checked for a +dirty line"

# English
printf 'language: en\n' > .tixforge/config.local.yml
ck render GT-000930
has "| # | Acceptance criterion | How to check | Kind |" "$(sec Plan)" "render: English header"
has "| 1 | ログインできる | \`tests/login.test.ts\`「ログインできる」 | auto |" "$(sec Plan)" "render: English kind words"
rm -f .tixforge/config.local.yml
ck render GT-000930

# put --reset after records; rewind and release.
ck put GT-000930 "$tmp/table" --reset > /dev/null
eq "-" "$(ck show GT-000930 | sed -n 2p | cut -f3)" "put --reset: the records go"
ck record GT-000930 2 ok "$h1" claude "$tmp/steps"
st set GT-000930 Status implement:in-progress > /dev/null
st rewind GT-000930 implement > /dev/null
[ -f "$d/checks.tsv" ] && ok || ng "rewind to implement keeps the checks (## Plan stays)"
hist=$(st rewind GT-000930 plan)
[ -f "${hist%.md}-checks/checks.tsv" ] && ok || ng "rewind to plan moves the checks to history"
[ ! -e "$d/checks.tsv" ] && ok || ng "and none are left"
ck put GT-000930 "$tmp/table" > /dev/null
st release GT-000930 > /dev/null
[ ! -e "$d" ] && ok || ng "release: the checks go with the run"

# migrate 4 -> 5: the hand-written table and manual check lines.
section="checks.sh migrate"
st init GT-000931 > /dev/null
f31=.tixforge/GT-000931/state.md
cat > "$tmp/old" << EOF
## Plan
- Base: main

| # | 受け入れ条件 | 確かめ方 | 種別 |
|---|---|---|---|
| 1 | a | t | 自動 |
| 2 | b | ブラウザで | Claude（ブラウザ） |
| 3 | c | メール | ユーザー |

- commit 1: x

## Implementation Log
- 手動確認 @ $h1: #2 ok（Claude：スクリーンショットで確認）・#3 未確認（理由：環境が無い）
- Manual re-check: #2
EOF
awk -v r="$tmp/old" '$0 == "## Plan" { while ((getline l < r) > 0) print l; skip = 1; next } $0 == "## Review" { skip = 0 } !skip' "$f31" > "$tmp/f31"
sed 's/^| Format  | 5 /| Format  | 4 /' "$tmp/f31" > "$f31"
has "- keep the checks table" "$(st migrate --check GT-000931)" "migrate --check: the checks step"
eq "format 4 -> 5: $f31" "$(st migrate GT-000931)" "migrate 4 -> 5"
eq "2 browser ok $h1 claude 1" "$(ck show GT-000931 | sed -n 2p | cut -f1-6 | tr '\t' ' ')" "the manual line and the later re-check"
eq "3 user skipped $h1 claude 0" "$(ck show GT-000931 | sed -n 3p | cut -f1-6 | tr '\t' ' ')" "未確認 is skipped"
eq 1 "$(grep -c '^| 1 | a | t | 自動 |' "$f31")" "the table appears once, rendered"
has "- commit 1: x" "$(awk '$0 == "## Plan" { on = 1; next } on && /^## / { exit } on' "$f31")" "the rest of ## Plan stays"
st init GT-000932 > /dev/null
sed 's/^| Format  | 5 /| Format  | 4 /' .tixforge/GT-000932/state.md > "$tmp/f32" && cat "$tmp/f32" > .tixforge/GT-000932/state.md
eq "format 4 -> 5: .tixforge/GT-000932/state.md" "$(st migrate GT-000932)" "migrate 4 -> 5 without a table"
[ ! -e .tixforge/GT-000932/checks.tsv ] && ok || ng "no table, no data"
rm -rf .tixforge/GT-000931 .tixforge/GT-000932
ck show GT-999999 > /dev/null 2>&1
eq 1 $? "no such run"

done_file
