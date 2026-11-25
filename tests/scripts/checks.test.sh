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
# A closing mark lost by an edit: the block ends at the next section, and
# nothing after it goes.
printf '\n## PR\n- URL: https://github.com/o/r/pull/9\n' >> "$f"
grep -v '^<!-- /tixforge:checks -->$' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"
ck render GT-000930
has "https://github.com/o/r/pull/9" "$(cat "$f")" "render: a lost closing mark deletes nothing after the section"
eq 1 "$(grep -c '^<!-- /tixforge:checks -->$' "$f")" "render: and the mark is back"
# Text after a block whose closing mark was lost stays.
printf -- '- Commits: X\n' > "$tmp/after"
awk -v a="$tmp/after" '{ print } $0 == "<!-- /tixforge:checks -->" { while ((getline l < a) > 0) print l }' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"
grep -v '^<!-- /tixforge:checks -->$' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"
ck render GT-000930
has "- Commits: X" "$(sec Plan)" "render: text after a lost closing mark stays"
# A mark inside a code fence is text.
printf 'see:\n```\n<!-- tixforge:manual -->\n```\nafter the fence\n' > "$tmp/fenced"
awk -v a="$tmp/fenced" '{ print } $0 == "## Research" { while ((getline l < a) > 0) print l }' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"
ck render GT-000930
has "$(printf '```\n<!-- tixforge:manual -->\n```\nafter the fence')" "$(sec Research)" "render: a fenced mark stays as it is"
grep -q '^## PR' "$f" && ok || ng "render: the sections after a fenced mark are found"
awk '$0 == "## Research" { print; skip = 1; next } /^## / { skip = 0 } !skip' "$f" > "$tmp/f" && cat "$tmp/f" > "$f"
ck render GT-000930
grep -v '^- Commits: X$' "$f" | awk '/^<!-- tixforge:checks -->$/ { n++ } n > 1 && /^\| 1 / { next } { print }' > "$tmp/f" && cat "$tmp/f" > "$f"

# Refused tables write nothing.
printf '| 1 | a | b | 自動 |\n| 3 | c | d | auto |\n' > "$tmp/bad"
has "numbered 1, 2" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: rows in order"
printf '| 1 | a | b | manual |\n' > "$tmp/bad"
has "kind must be" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: a known kind"
printf '| 1 | a | 自動 |\n' > "$tmp/bad"
has "4 columns" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: four columns"
printf '| 1 | a | b | auto |\n| 2. | c | d | auto |\n' > "$tmp/bad"
has "is a number" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: a # like 2. is refused, not dropped"
printf '| 1 | a | b | auto |\n| #2 | c | d | auto |\n' > "$tmp/bad"
has "has no number" "$(ck put GT-000930 "$tmp/bad" 2>&1)" "put: a row without a number after the first is refused"
printf 'no table\n' > "$tmp/bad"
ck put GT-000930 "$tmp/bad" > /dev/null 2>&1
eq 3 $? "put: no rows"
eq 4 "$(grep -c '^check' "$d/checks.tsv")" "nothing written for refused tables"

# Manual checks.
printf '1. http://localhost:3000/login を開く\n2. 誤ったパスワードを入れる\n\n赤字でエラーが出た\n' > "$tmp/steps"
ck record GT-000930 02 ok "$h1" claude "$tmp/steps"
has "- #2 ok @ ${h1}（claude）" "$(sec 'Implementation Log')" "record: the result in the Log (02 is row 2)"
has "    1. http://localhost:3000/login を開く" "$(sec 'Implementation Log')" "record: the steps under it, four spaces in"
ck record GT-000930 1 ok "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 4 $? "record: not an auto row"
ck record GT-000930 9 ok "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 4 $? "record: no such row"
ck record GT-000930 2 fine "$h1" claude "$tmp/steps" > /dev/null 2>&1
eq 2 $? "record: ok, ng or skipped"
printf '```\nopen\n' > "$tmp/badsteps"
ck record GT-000930 2 ok "$h1" claude "$tmp/badsteps" > /dev/null 2>&1
eq 3 $? "record: steps with an unclosed fence are refused"
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
has "- [ ] ログインできる" "$(ck pr GT-000930 "Verification @ $h1: 検証コマンドなし")" "pr: not checked when no command ran"
ck recheck GT-000930 2
has "- [ ] エラーが出る | 赤字で — ログイン画面で確かめる（ok @ $h1, claude, to check again）" "$(ck pr GT-000930 "Verification @ $h1: test pass")" "pr: an ok waiting for a re-check is not checked"
ck record GT-000930 2 ok "$h1" claude "$tmp/steps"

# English
printf 'language: en\n' > .tixforge/config.local.yml
ck render GT-000930
has "| # | Acceptance criterion | How to check | Kind |" "$(sec Plan)" "render: English header"
has "| 1 | ログインできる | \`tests/login.test.ts\`「ログインできる」 | auto |" "$(sec Plan)" "render: English kind words"
rm -f .tixforge/config.local.yml
ck render GT-000930

# A fence Claude left open above the marks: render adds nothing, each time.
cp "$f" "$tmp/keep"
awk '{ print } $0 == "## Plan" { print "```sh" }' "$tmp/keep" > "$f"
ck render GT-000930
ck render GT-000930
eq 1 "$(grep -c '^<!-- tixforge:checks -->$' "$f")" "render: no block added under an open fence"
cp "$tmp/keep" "$f"
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

\`\`\`markdown
| 9 | an example | x | 自動 |
\`\`\`

| key | value |
|---|---|
| Base | main |

| # | 受け入れ条件 | 確かめ方 | 種別 |
|---|---|---|---|
| 1 | a | t | 自動 |
| 2 | b | ブラウザで | Claude（ブラウザ） |
| 3 | c | メール | ユーザー |
| 4 | d | 手で | ユーザー |
| 5 | e | 手で | user |
| 6 | f | 手で | user |

| commit | what |
|---|---|
| 1 | x |

- commit 1: x

## Implementation Log
- 手動確認 @ $h1: #2 ok（Claude：スクリーンショットで確認）・#3 未確認（理由：環境が無い）
- Manual re-check: #2
- 手動確認 @ $h1: #4 ok（ユーザー）
- manual @ $h1: #5 ok (user)
- manual @ $h1: #6 ok (user)
- manual @ $h1: #6 failed (user)
EOF
awk -v r="$tmp/old" '$0 == "## Plan" { while ((getline l < r) > 0) print l; skip = 1; next } $0 == "## Review" { skip = 0 } !skip' "$f31" > "$tmp/f31"
sed 's/^| Format  | 5 /| Format  | 4 /' "$tmp/f31" > "$f31"
has "- keep the checks table" "$(st migrate --check GT-000931)" "migrate --check: the checks step"
eq "format 4 -> 5: $f31" "$(st migrate GT-000931)" "migrate 4 -> 5"
eq "2 browser ok $h1 claude 1" "$(ck show GT-000931 | sed -n 2p | cut -f1-6 | tr '\t' ' ')" "the manual line and the later re-check"
eq "3 user skipped $h1 claude 0" "$(ck show GT-000931 | sed -n 3p | cut -f1-6 | tr '\t' ' ')" "未確認 is skipped"
eq "4 user ok $h1 user 0" "$(ck show GT-000931 | sed -n 4p | cut -f1-6 | tr '\t' ' ')" "（ユーザー） is the user"
eq "5 user ok $h1 user 0" "$(ck show GT-000931 | sed -n 5p | cut -f1-6 | tr '\t' ' ')" "(user) is the user"
eq "6 ng" "$(ck show GT-000931 | sed -n 6p | cut -f1,3 | tr '\t' ' ')" "a later failed is ng"
eq 6 "$(ck show GT-000931 | wc -l | tr -d ' ')" "only the first table outside fences is the checks table"
has "| 9 | an example | x | 自動 |" "$(cat "$f31")" "the fenced example stays"
has "| 1 | x |" "$(cat "$f31")" "the commit table stays"
has "| Base | main |" "$(cat "$f31")" "a table before the checks table stays, and is not taken"
eq 1 "$(grep -c '^| 1 | a | t | 自動 |' "$f31")" "the table appears once, rendered"
st init GT-000933 > /dev/null
f33=.tixforge/GT-000933/state.md
printf '## Plan\n| # | a | b | c |\n|---|---|---|---|\n| 1 | x | y | someday |\n' > "$tmp/old33"
awk -v r="$tmp/old33" '$0 == "## Plan" { while ((getline l < r) > 0) print l; skip = 1; next } $0 == "## Implementation Log" { skip = 0 } !skip' "$f33" > "$tmp/f33"
sed 's/^| Format  | 5 /| Format  | 4 /' "$tmp/f33" > "$f33"
has "put the checks table again (checks.sh put): error: row 1: kind must be" "$(st migrate GT-000933)" "migrate: says to put a table it could not read"
rm -rf .tixforge/GT-000933
has "- commit 1: x" "$(awk '$0 == "## Plan" { on = 1; next } on && /^## / { exit } on' "$f31")" "the rest of ## Plan stays"
st init GT-000932 > /dev/null
sed 's/^| Format  | 5 /| Format  | 4 /' .tixforge/GT-000932/state.md > "$tmp/f32" && cat "$tmp/f32" > .tixforge/GT-000932/state.md
eq "format 4 -> 5: .tixforge/GT-000932/state.md" "$(st migrate GT-000932)" "migrate 4 -> 5 without a table"
[ ! -e .tixforge/GT-000932/checks.tsv ] && ok || ng "no table, no data"
rm -rf .tixforge/GT-000931 .tixforge/GT-000932
ck show GT-999999 > /dev/null 2>&1
eq 1 $? "no such run"

done_file
