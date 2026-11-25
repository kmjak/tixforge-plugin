#!/usr/bin/env bash
# Tests of run-state.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- run-state.sh --------------------------------------------------------------
section="run-state.sh"
st() { bash "$scripts/run-state.sh" "$@"; }
mkdir -p .tixforge/GT-000901 && printf '# GT-000901: A\n\n## 背景\n' > .tixforge/GT-000901/ticket.md
eq .tixforge/GT-000901/state.md "$(st init GT-000901)" "init"
[ -f .tixforge/.gitignore ] && ok || ng "init creates .tixforge/.gitignore"
eq ".tixforge/.gitignore" "$(git status --porcelain --untracked-files=all .tixforge | cut -c4-)" "only .gitignore is visible to git"
git add .tixforge/.gitignore && git commit -q -m gitignore
git check-ignore -q .tixforge/config.local.yml && ok || ng "config.local.yml stays out of git"
st init GT-000901 2> /dev/null
eq 3 $? "init twice"
st init T000001 2> /dev/null
eq 2 $? "not a ticket id"
st init LT-000001 2> /dev/null
eq 2 $? "no new run for a local ticket (v2)"
eq research:in-progress "$(st get GT-000901)" "initial Status"
eq 5 "$(st get GT-000901 Format)" "init writes the current Format"
eq "Research|Approach|Plan|Implementation Log|Review|PR" \
  "$(sed -n 's/^## //p' .tixforge/GT-000901/state.md | paste -sd'|' -)" "init writes the six sections in order"
eq 0 "$(grep -c '<!--' .tixforge/GT-000901/state.md)" "the sections start empty"
eq "" "$(st migrate --check GT-000901)" "migrate --check: nothing for a current file"
st set GT-000901 Issue '#1' 2> /dev/null
eq 2 $? "Issue is not a header field"
git branch GT-000901-a
eq GT-000901-a "$(st set GT-000901 Branch GT-000901-a)" "set Branch"
st set GT-000901 Status implement:typo 2> /dev/null
eq 2 $? "invalid Status"
st set GT-000901 Updated x 2> /dev/null
eq 2 $? "Updated is not settable"
eq plan:awaiting-approval "$(st set GT-000901 Status plan:awaiting-approval)" "set Status"
st set GT-000901 Status implement:in-progress > /dev/null
grep -q '^## Implementation Log' .tixforge/GT-000901/state.md && ok || ng "sections kept"
eq "$(printf 'GT-000901\timplement:in-progress\tGT-000901-a')" "$(st list)" "list: id, Status, Branch"
# statuses: every value run-state accepts, each explained in run.md's
# "Status のフォーマット" list: a line "- `<value>`", or "- `<phase>:<state>`"
# with the phase in the line that lists the phases.
fmt=$(awk '/^\*\*Status のフォーマット：\*\*/ { on = 1; next } on && /^$/ { exit } on' "$here/../skills/dev/run.md")
phases=$(printf '%s\n' "$fmt" | grep '`<phase>` は')
for v in $(st statuses); do
  st set GT-000901 Status "$v" > /dev/null 2>&1 && ok || ng "statuses lists $v, which set refuses"
  if printf '%s\n' "$fmt" | grep -q "^- \`$v\`"; then
    ok
  elif case $v in *:*) true ;; *) false ;; esac \
    && printf '%s\n' "$fmt" | grep -q "^- \`<phase>:${v#*:}\`" \
    && printf '%s\n' "$phases" | grep -q "\`${v%%:*}\`"; then
    ok
  else
    ng "run.md does not explain $v"
  fi
done
st set GT-000901 Status implement:in-progress > /dev/null
eq 16 "$(st statuses | wc -l | tr -d ' ')" "statuses: 16 values"
# The event log: init, every change of Status and rewind append one line.
section="run-state.sh events"
evf=.tixforge/events.jsonl
lastev() { tail -1 "$evf" | jq -c "$@"; }
eq '"run_started"' "$(grep -m1 '"GT-000901"' "$evf" | jq -c .type)" "init logs run_started"
eq '{"v":1,"ticket":"GT-000901","type":"status","from":"canceled","to":"implement:in-progress","via":"other"}' \
  "$(lastev 'del(.at, .id)')" "set Status logs from, to and via"
n=$(wc -l < "$evf")
st set GT-000901 Status implement:in-progress > /dev/null
st set GT-000901 Branch GT-000901-a > /dev/null
eq "$n" "$(wc -l < "$evf")" "no event for an unchanged Status or for Branch"
lastev -r .at | grep -Eq '[+-][0-9][0-9]:[0-9][0-9]$' && ok || ng "at ends with the UTC offset"
TZ=UTC0 bash -c ". '$scripts/lib.sh'; tf_stamp" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+00:00$' && ok || ng "tf_stamp: ISO 8601 with +00:00 in UTC"
TZ=JST-9 bash -c ". '$scripts/lib.sh'; tf_stamp" | grep -q '+09:00$' && ok || ng "tf_stamp: +09:00 in Japan"
# transition: what each change of Status was.
for t in "research:in-progress research:awaiting-approval gate" \
  "research:awaiting-approval approach:in-progress approve" \
  "approach:in-progress plan:in-progress forward" \
  "review:awaiting-approval pr:in-progress approve" \
  "review:in-progress implement:in-progress back" \
  "plan:in-progress approach:in-progress back" \
  "pr:awaiting-approval pr:awaiting-review pr" \
  "pr:ready-to-merge pr:in-progress pr" \
  "pr:ready-to-merge done done" \
  "plan:in-progress canceled cancel" \
  "plan:awaiting-approval plan:in-progress other" \
  "research:in-progress plan:in-progress other"; do
  set -- $t
  st set GT-000901 Status "$1" > /dev/null
  st set GT-000901 Status "$2" > /dev/null
  eq "$3" "$(lastev -r .via)" "transition $1 -> $2"
done
set --
st set GT-000901 Status implement:in-progress > /dev/null
# json_str: what jq reads back is the text given.
for s in 'a"b\c' "$(printf 'x\ty\r\nz')" 'C:\temp\new' 'あい"う' '' '%s -n' '-e'; do
  eq "$s" "$(json_str "$s" | jq -j .)" "json_str round trip [$s]"
done
eq '"ab"' "$(json_str "$(printf 'a\001\033b')")" "json_str drops other control characters"
# A log that cannot be written does not stop the change it records.
mv "$evf" "$tmp/events.keep" && mkdir "$evf"
eq plan:awaiting-approval "$(st set GT-000901 Status plan:awaiting-approval 2>&1)" "set works when the log cannot be written"
eq plan:awaiting-approval "$(st get GT-000901)" "and the Status changed"
rmdir "$evf" && mv "$tmp/events.keep" "$evf"
st set GT-000901 Status implement:in-progress > /dev/null
section="run-state.sh"

st get GT-000404 2> /dev/null
eq 1 $? "no such run"
eq pr:ready-to-merge "$(st set GT-000901 Status pr:ready-to-merge)" "ready-to-merge is a Status"
st set GT-000901 Status implement:in-progress > /dev/null

# rewind: later sections move to history/, the target gets a note.
mkdir -p .tixforge/GT-000909
bash "$scripts/run-state.sh" init GT-000909 > /dev/null
f9=.tixforge/GT-000909/state.md
for sec in Research Approach Plan 'Implementation Log' Review PR; do
  awk -v s="## $sec" -v b="body of $sec" '$0 == s { print; print b; skip = 1; next } skip && /^<!--/ { skip = 0; next } { skip = 0; print }' "$f9" > "$tmp/s9" && cat "$tmp/s9" > "$f9"
done
st set GT-000909 Status review:in-progress > /dev/null
h=$(st rewind GT-000909 plan --reason "分割を変える")
has ".tixforge/GT-000909/history/" "$h" "rewind prints the history file"
eq plan:in-progress "$(st get GT-000909)" "rewind sets the Status"
has "body of Approach" "$(cat "$f9")" "earlier sections stay"
case "$(cat "$f9")" in *"body of Plan"* | *"body of Review"*) ng "the target and later sections leave state.md" ;; *) ok ;; esac
has "body of Plan" "$(cat "$h")" "they are in the history file"
has "Status before: review:in-progress" "$(cat "$h")" "history records the Status before"
has "> 巻き戻し（" "$(cat "$f9")" "the target section notes the rewind"
has "分割を変える" "$(cat "$f9")" "with the reason"
# The note is in this person's language: config.local.yml's wins.
printf 'language: en\n' > .tixforge/config.local.yml
st set GT-000909 Status review:in-progress > /dev/null
st rewind GT-000909 plan --reason "a & b" > /dev/null
has "> Rewound (" "$(cat "$f9")" "the rewind note follows the personal language"
has "): a & b" "$(cat "$f9")" "the reason is kept as is"
printf 'language: ja\n' > .tixforge/config.local.yml
cp .tixforge/config.yml "$tmp/keep-lang.yml"
sed 's/^language: .*/language: en/' "$tmp/keep-lang.yml" > .tixforge/config.yml
st set GT-000909 Status review:in-progress > /dev/null
st rewind GT-000909 plan --reason "$(printf 'one\r\n## Review')" > /dev/null
has "> 巻き戻し（" "$(cat "$f9")" "a personal ja wins over a team en"
has "：one ## Review" "$(cat "$f9")" "a newline in the reason becomes a space"
rm -f .tixforge/config.local.yml
st set GT-000909 Status review:in-progress > /dev/null
st rewind GT-000909 plan --reason r > /dev/null
has "> Rewound (" "$(cat "$f9")" "the team language without a personal one"
cp "$tmp/keep-lang.yml" .tixforge/config.yml
sleep 1
awk '$0 == "## Implementation Log" { print; print "kept log"; next } { print }' "$f9" > "$tmp/s9" && cat "$tmp/s9" > "$f9"
st rewind GT-000909 approach --keep-log > /dev/null
has "kept log" "$(cat "$f9")" "--keep-log keeps the Implementation Log"
awk '$0 == "## Review" { print; print "a review"; next } { print }' "$f9" > "$tmp/s9" && cat "$tmp/s9" > "$f9"
st rewind GT-000909 implement 2> /dev/null
eq 2 $? "cannot rewind forward (approach -> implement)"
eq approach:in-progress "$(st get GT-000909)" "a refused rewind leaves the Status"
st set GT-000909 Status review:in-progress > /dev/null
st rewind GT-000909 implement > /dev/null
has "kept log" "$(cat "$f9")" "rewinding to implement keeps the log"
case "$(cat "$f9")" in *"a review"*) ng "rewinding to implement moves Review" ;; *) ok ;; esac
st rewind GT-000909 review 2> /dev/null
eq 2 $? "cannot rewind to review"
# Rewinding to the current phase is a normal use (redo the Plan).
st set GT-000909 Status plan:awaiting-approval > /dev/null
st rewind GT-000909 plan > /dev/null && ok || ng "rewind to the current phase"
# "## " inside a fence is not a section: the whole Approach moves.
st set GT-000909 Status plan:in-progress > /dev/null
awk '$0 == "## Approach" { print; print "fenced start"; print "```markdown"; print "## 背景"; print "fenced tail"; print "```"; print "after fence"; next } { print }' "$f9" > "$tmp/s9" && cat "$tmp/s9" > "$f9"
h=$(st rewind GT-000909 approach --reason 'C:\temp\new')
case "$(cat "$f9")" in *"fenced"* | *"after fence"* | *"## 背景"*) ng "a fenced ## line ends the section" ;; *) ok ;; esac
has "after fence" "$(cat "$h")" "the whole fenced Approach is in the history"
has 'C:\temp\new' "$(cat "$h")" "backslashes of the reason are kept (history)"
has 'C:\temp\new' "$(cat "$f9")" "backslashes of the reason are kept (note)"
# Two rewinds in the same second get two history files.
h1=$(st rewind GT-000909 approach --reason one)
h2=$(st rewind GT-000909 approach --reason two)
[ "$h1" != "$h2" ] && [ -f "$h1" ] && [ -f "$h2" ] && ok || ng "same-second rewinds keep both history files ($h1, $h2)"
has "Reason: one" "$(cat "$h1")" "the first history file is not overwritten"
st set GT-000909 Status done > /dev/null
st rewind GT-000909 plan 2> /dev/null
eq 4 $? "a done run is not rewound"
# rewind events: from, to, reason, history, keep_log.
grep '"GT-000909"' "$evf" | grep '"rewind"' | head -1 | jq -c 'del(.at, .id, .history)' > "$tmp/rw1"
eq '{"v":1,"ticket":"GT-000909","type":"rewind","from":"review:in-progress","to":"plan:in-progress","category":null,"trigger":null,"reason":"分割を変える","keep_log":false}' \
  "$(cat "$tmp/rw1")" "rewind logs from, to, reason and keep_log"
has '.tixforge/GT-000909/history/' "$(grep '"GT-000909"' "$evf" | grep -m1 '"rewind"' | jq -r .history)" "rewind logs the history file"
eq 'C:\temp\new' "$(grep '"GT-000909"' "$evf" | grep '"rewind"' | jq -r .reason | grep -F 'C:\')" "a reason with backslashes is logged as is"
eq true "$(grep '"GT-000909"' "$evf" | grep '"rewind"' | grep -F '"to":"implement:in-progress"' | head -1 | jq .keep_log)" "rewinding to implement keeps the log"
eq null "$(grep '"GT-000909"' "$evf" | grep '"rewind"' | grep -F '"to":"approach:in-progress"' | head -1 | jq .reason)" "no reason is null"
# --category / --trigger: fixed words, logged with the rewind.
st init GT-000908 > /dev/null
st set GT-000908 Status review:in-progress > /dev/null
st rewind GT-000908 plan --category typo 2> /dev/null
eq 2 $? "rewind refuses an unknown category"
st rewind GT-000908 plan --trigger typo 2> /dev/null
eq 2 $? "rewind refuses an unknown trigger"
eq review:in-progress "$(st get GT-000908)" "a refused rewind changes nothing"
st rewind GT-000908 plan --category misread --trigger review --reason "R1" > /dev/null
eq '{"category":"misread","trigger":"review","reason":"R1"}' "$(tail -1 "$evf" | jq -c '{category, trigger, reason}')" "rewind logs category and trigger"
st rewind GT-000908 plan > /dev/null
eq '{"category":null,"trigger":null}' "$(tail -1 "$evf" | jq -c '{category, trigger}')" "without them they are null"
# cancel: Status canceled, with why.
st cancel GT-000908 --category misread 2> /dev/null
eq 2 $? "cancel has its own categories"
eq canceled "$(st cancel GT-000908 --category duplicate --reason "GT-000045 に統合")" "cancel sets canceled"
eq '{"ticket":"GT-000908","type":"canceled","from":"plan:in-progress","category":"duplicate","reason":"GT-000045 に統合"}' \
  "$(tail -1 "$evf" | jq -c 'del(.v, .at, .id)')" "cancel logs from, category and reason"
n=$(wc -l < "$evf")
st cancel GT-000908 2> /dev/null
eq 4 $? "a canceled run is not canceled again"
eq "$n" "$(wc -l < "$evf")" "and nothing is logged"
st cancel GT-000404 2> /dev/null
eq 1 $? "cancel: no such run"
# release: the run and the ticket copy go, the log stays.
st init GT-000907 > /dev/null
d7=.tixforge/GT-000907
mkdir -p "$d7/history" && echo x > "$d7/history/a.md" && echo t > "$d7/snapshot.md" && echo h > "$d7/.snapshot.md.hash"
st set GT-000907 Status plan:in-progress > /dev/null
eq "released: GT-000907" "$(st release GT-000907 --reason "Aさんに渡す")" "release"
[ -e "$d7" ] && ng "release removes the run's folder" || ok
eq '{"type":"released","from":"plan:in-progress","reason":"Aさんに渡す"}' "$(tail -1 "$evf" | jq -c '{type, from, reason}')" "release logs from and reason"
eq 3 "$(grep -c '"GT-000907"' "$evf" | tr -d ' ')" "the run's earlier events stay (run_started, status, released)"
st init GT-000906 > /dev/null
echo keep > .tixforge/GT-000906/editing.md
st release GT-000906 > /dev/null
eq keep "$(cat .tixforge/GT-000906/editing.md)" "release leaves other files (editing.md) alone"
rm -rf .tixforge/GT-000906
st init GT-000906 > /dev/null
st set GT-000906 Status done > /dev/null
st release GT-000906 2> /dev/null
eq 4 $? "a done run is not released"
[ -f .tixforge/GT-000906/state.md ] && ok || ng "a refused release removes nothing"
rm -rf .tixforge/GT-000906 .tixforge/GT-000908
# review_round: the rounds of ## Review, logged when the run leaves
# review:in-progress, from the fixed keys only.
st init GT-000905 > /dev/null
f5=.tixforge/GT-000905/state.md
cat > "$tmp/review.md" << 'EOF'
## Review
### Round 1
Verification @ a1b2c3d: test pass

#### 合意とのズレ（tixforge:reviewer）
- **R1 [未実装]** "引用" と \ がある
  - 推奨：修正
  - Auto-fix: ○
  - Decision: fix (auto) 理由
  - Fixed @ b2c3d4e
- **R2 [合意外の変更]** x
  - Auto-fix: △
```markdown
- **R9 [相違]** in a fence
  - Auto-fix: ×
```

#### 品質（tixforge:quality-reviewer）
- **Q1 [バグ]** y
  - Auto-fix: ×
  - Decision: accept (auto)
- **Q2 [性能]** no Auto-fix line
- 実装者による追加：z
  - Auto-fix: △
  - Decision: reapproach

### Round 2
Verification @ c3d4e5f: test pass

#### 合意とのズレ（tixforge:reviewer）
指摘なし
EOF
awk -v r="$tmp/review.md" '$0 == "## Review" { while ((getline l < r) > 0) print l; next } { print }' "$f5" > "$tmp/s5" && cat "$tmp/s5" > "$f5"
bash "$scripts/review.sh" _import GT-000905 > /dev/null # as migrate does (format 3 -> 4)
st set GT-000905 Status review:in-progress > /dev/null
n=$(wc -l < "$evf")
st set GT-000905 Status implement:in-progress > /dev/null
eq $((n + 3)) "$(wc -l < "$evf" | tr -d " ")" "leaving review:in-progress logs each round, then the status"
eq '{"round":1,"findings":[{"id":"R1","label":"未実装","auto_fix":"fix","decision":"fix (auto)","fixed":"b2c3d4e"},{"id":"R2","label":"合意外の変更","auto_fix":"ask","decision":null,"fixed":null},{"id":"Q1","label":"バグ","auto_fix":"accept","decision":"accept (auto)","fixed":null},{"id":"","label":"","auto_fix":"ask","decision":"reapproach","fixed":null}],"unparsed":1}' \
  "$(grep '"review_round"' "$evf" | tail -2 | head -1 | jq -c '{round, findings, unparsed}')" "round 1: findings from the data (imported), fences skipped, a finding not judged is unparsed"
eq '{"round":2,"findings":[],"unparsed":0}' "$(grep '"review_round"' "$evf" | tail -1 | jq -c '{round, findings, unparsed}')" "a round without findings"
n=$(wc -l < "$evf")
st set GT-000905 Status review:in-progress > /dev/null
eq $((n + 1)) "$(wc -l < "$evf" | tr -d " ")" "entering Review logs no rounds"
# English labels, CRLF, and a rewind from Review (logged before ## Review moves).
sed -e 's/未実装/missing/' -e 's/$/\r/' "$tmp/review.md" > "$tmp/review-en.md"
awk '$0 == "## Review" { skip = 1; print; next } skip && /^## / { skip = 0 } !skip' "$f5" > "$tmp/s5"
awk -v r="$tmp/review-en.md" '$0 == "## Review" { while ((getline l < r) > 0) print l; next } { print }' "$tmp/s5" > "$f5"
rm -rf .tixforge/GT-000905/review.tsv .tixforge/GT-000905/review
bash "$scripts/review.sh" _import GT-000905 > /dev/null # as migrate does (format 3 -> 4)
st rewind GT-000905 plan --category misread --trigger review > /dev/null
eq '"missing"' "$(grep '"review_round"' "$evf" | tail -2 | head -1 | jq -c '.findings[0].label')" "a rewind from Review logs the rounds first (CRLF read)"
eq rewind "$(tail -1 "$evf" | jq -r .type)" "then the rewind"
n=$(wc -l < "$evf")
st set GT-000905 Status review:in-progress > /dev/null
st set GT-000905 Status pr:in-progress > /dev/null
eq $((n + 2)) "$(wc -l < "$evf" | tr -d " ")" "an empty ## Review logs no rounds"
rm -rf .tixforge/GT-000905
# review-next: where Review goes on from (phase/review.md step 2), a case per
# branch in the order they are tried. A commit of its own makes "HEAD is
# ahead of the round's Verification" both false and true.
st init GT-000907 > /dev/null
f7=.tixforge/GT-000907/state.md
cp "$f7" "$tmp/rn-orig"
back=$(git symbolic-ref --short HEAD)
git switch -q -c rn-test
git commit -q --allow-empty -m rn1
v1=$(git rev-parse --short HEAD)
# rn <log> <review>: the Implementation Log and ## Review, then review-next.
rn() {
  printf '%s\n' "$1" > "$tmp/rn-log"
  printf '%s\n' "$2" > "$tmp/rn-rev"
  # A Plan table of 12 rows checked by the user, for the re-check lines.
  { for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf '| %s | c%s | h | ユーザー |\n' "$i" "$i"; done; } > "$tmp/rn-plan"
  awk -v l="$tmp/rn-log" -v r="$tmp/rn-rev" -v p="$tmp/rn-plan" '
    $0 == "## Plan" { print; while ((getline x < p) > 0) print x; close(p); skip = 1; next }
    $0 == "## Implementation Log" { print; while ((getline x < l) > 0) print x; skip = 1; next }
    $0 == "## Review" { print; while ((getline x < r) > 0) print x; skip = 1; next }
    /^## / { skip = 0 }
    !skip' "$tmp/rn-orig" > "$f7"
  rm -rf .tixforge/GT-000907/review.tsv .tixforge/GT-000907/review .tixforge/GT-000907/checks.tsv .tixforge/GT-000907/checks
  bash "$scripts/review.sh" _import GT-000907 > /dev/null
  bash "$scripts/checks.sh" _import GT-000907 > /dev/null # migrate 4 -> 5
  st review-next GT-000907
}
# round <n> <hash> <reviewer's findings> [<quality findings>]
round() { printf '### Round %s\nVerification @ %s: test pass\n\n#### 合意とのズレ（tixforge:reviewer）\n%s\n\n#### 品質（tixforge:quality-reviewer）\n%s\n' "$1" "$2" "$3" "${4:-指摘なし}"; }
# fnd <id> [auto-fix] [decision] [fixed]
fnd() {
  printf -- '- **%s [バグ]** x\n  - 推奨：修正\n' "$1"
  [ -z "${2:-}" ] || printf '  - Auto-fix: %s\n' "$2"
  [ -z "${3:-}" ] || printf '  - Decision: %s\n' "$3"
  [ -z "${4:-}" ] || printf '  - Fixed @ %s\n' "$4"
}
step() { printf '%s\n' "$1" | sed -n 's/^step: //p'; }
out=$(rn "" "")
eq 3 "$(step "$out")" "review-next: no round -> 3"
has "round: none" "$out" "review-next: round none"
out=$(rn "" "$(printf '### Round 1\nVerification @ %s: test pass\n\n#### 合意とのズレ（tixforge:reviewer）\n指摘なし\n\n#### 品質（tixforge:quality-reviewer）\n' "$v1")")
eq 3 "$(step "$out")" "review-next: a reviewer section left empty -> 3"
has "drop: Round 1" "$out" "review-next: the cut-short round is dropped"
out=$(rn "" "$(printf '### Round 1\nVerification @ %s: test pass\n\n#### 合意とのズレ（tixforge:reviewer）\n指摘なし\n' "$v1")")
has "drop: Round 1" "$out" "review-next: one reviewer section is cut short"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1)")")
eq 6 "$(step "$out")" "review-next: a finding with neither Auto-fix nor Decision -> 6"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 ○)")")
eq 7 "$(step "$out")" "review-next: ○ without a Decision -> 7"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 ×)")")
eq 7 "$(step "$out")" "review-next: × without a Decision -> 7"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 △ replan)")
$(round 2 "$v1" "$(fnd R2 × 'accept (auto)')")")
eq rewind "$(step "$out")" "review-next: replan in an earlier round -> rewind"
eq 2 "$(printf '%s\n' "$out" | sed -n 's/^round: //p')" "review-next: round is the latest"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 ○ 'fix (auto)')")")
eq implement "$(step "$out")" "review-next: ○ decided fix, not fixed -> implement"
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 ○ 'fix (auto)' "$v1")")")
eq 10 "$(step "$out")" "review-next: fixed and HEAD at the Verification -> 10"
out=$(rn "" "$(round 1 deadbee "$(fnd R1 × 'accept (auto)')")")
eq 3 "$(step "$out")" "review-next: a Verification hash that is no commit -> 3"
git commit -q --allow-empty -m rn2
out=$(rn "" "$(round 1 "$v1" "$(fnd R1 ○ 'fix (auto)' "$(git rev-parse --short HEAD)")")")
eq 3 "$(step "$out")" "review-next: HEAD ahead of the round's Verification -> 3"
case "$out" in *drop:*) ng "review-next: a complete round is not dropped" ;; *) ok ;; esac
v2=$(git rev-parse --short HEAD)
out=$(rn "" "$(round 1 "$v2" "$(fnd R1 △)")")
eq 9 "$(step "$out")" "review-next: △ without a Decision -> 9"
out=$(rn "- Manual re-check: #2" "$(round 1 "$v2" "$(fnd R1 × 'accept (auto)')")")
eq 9 "$(step "$out")" "review-next: an open Manual re-check -> 9"
has "recheck: #2" "$out" "review-next: lists it"
out=$(rn "$(printf -- '- Manual re-check: #2 #12\n- Verification @ %s: test pass #2\n- 手動確認 @ %s: #2 ok（ユーザー）' "$v2" "$v2")" "$(round 1 "$v2" "$(fnd R1 × 'accept (auto)')")")
has "recheck: #12" "$out" "review-next: #12 is still open"
case "$out" in *"#2 "* | *"#2"$'\n'*) ng "review-next: #2 was checked after (a Verification line does not count)" ;; *) ok ;; esac
out=$(rn "$(printf -- '- Manual re-check: #3\n- 手動確認 @ %s：#3 ok（ユーザー）' "$v2")" "$(round 1 "$v2" "$(fnd R1 × 'accept (auto)')")")
case "$out" in *recheck:*) ng "review-next: a check line with a full-width colon closes the re-check" ;; *) ok ;; esac
out=$(rn "$(printf -- '- Manual re-check: #2\n- 手動確認 @ %s: #2 ok（ユーザー）' "$v2")" "$(round 1 "$v2" "$(fnd R1 △ 'fix')")
$(round 2 "$v2" "$(fnd R2 × 'accept (auto)')")")
eq implement "$(step "$out")" "review-next: a fix decided in step 9 in an earlier round -> implement"
fence=$(printf '\140\140\140')
out=$(rn "" "$(round 1 "$v2" "$(fnd R1 △ 'accept ok')" "$(fnd Q1 ○ 'fix (auto)' "$v2")")
$(printf '%s\n### Round 9\n- **R9 [x]** in a fence\n%s' "${fence}markdown" "$fence")")
eq 10 "$(step "$out")" "review-next: all decided and fixed, a fenced round ignored -> 10"
eq 1 "$(printf '%s\n' "$out" | sed -n 's/^round: //p')" "review-next: a fenced Round heading is not a round"
st review-next GT-999999 > /dev/null 2>&1
eq 1 $? "review-next: no such run"
git switch -q "$back"
git branch -q -D rn-test
rm -rf .tixforge/GT-000907
# pass: the note at the end of the phase's section, then the next phase.
st init GT-000911 > /dev/null
f11=.tixforge/GT-000911/state.md
awk '{ print } $0 == "## Research" { print "調べた結果"; print ""; print "```"; print "## Approach"; print "```"; print ""; print "" }' "$f11" > "$tmp/f11" && cat "$tmp/f11" > "$f11"
n=$(wc -l < "$evf")
eq approach:in-progress "$(st pass GT-000911 research)" "pass: prints the next phase's in-progress"
eq approach:in-progress "$(st get GT-000911)" "pass: Status"
eq "$(printf '調べた結果\n\n```\n## Approach\n```\n\n> ゲート自動通過（gates に無く、止まる条件なし）\n')" \
  "$(awk '/^```/ { f = !f } $0 == "## Research" { on = 1; next } on && !f && $0 == "## Approach" { exit } on' "$f11")" "pass: the note after the section's last line, a fenced heading kept inside"
eq $((n + 1)) "$(wc -l < "$evf" | tr -d ' ')" "pass: one status event"
printf 'language: en\n' > .tixforge/config.local.yml
st pass GT-000911 approach > /dev/null
has "> Gate passed automatically" "$(awk '$0 == "## Approach" { on = 1; next } on && /^## / { exit } on' "$f11")" "pass: the note in the person's language, in an empty section"
rm -f .tixforge/config.local.yml
st pass GT-000911 plan > /dev/null 2>&1
eq 2 $? "pass: plan always stops"
st set GT-000911 Status review:in-progress > /dev/null
st pass GT-000911 implement > /dev/null 2>&1
eq 2 $? "pass: only from the phase's in-progress"
eq pr:in-progress "$(st pass GT-000911 review)" "pass: review goes to the PR"
has "> ゲート自動通過" "$(awk '$0 == "## Review" { on = 1; next } on && /^## / { exit } on' "$f11")" "pass: review's note"
st pass GT-999999 research > /dev/null 2>&1
eq 1 $? "pass: no such run"
st init GT-000912 > /dev/null
grep -v '^## Research' .tixforge/GT-000912/state.md > "$tmp/f12" && cat "$tmp/f12" > .tixforge/GT-000912/state.md
st pass GT-000912 research > /dev/null 2>&1
eq 2 $? "pass: no section heading, no pass"
eq research:in-progress "$(st get GT-000912)" "pass: and Status stays"
rm -rf .tixforge/GT-000912
rm -rf .tixforge/GT-000911
# The words the skills ask for are the ones run-state accepts: rewind.md and
# cancel.md list each as "- `<word>`：<meaning>" under the step that asks.
for kind in rewind cancel; do
  case $kind in rewind) md="$here/../skills/dev/rewind.md" ;; cancel) md="$here/../skills/ticket/cancel.md" ;; esac
  want=$(st categories $kind | paste -sd' ' -)
  got=$(awk '/categories '"$kind"'/ { on = 1; next } on && /^ *- `/ { sub(/^ *- `/, ""); sub(/`.*/, ""); printf "%s%s", sep, $0; sep = " "; next } on { exit }' "$md")
  eq "$want" "$got" "$kind categories in the skill match run-state"
done
for t in $(st triggers); do
  grep -rqF "\`$t\`" "$here/../skills/dev/rewind.md" && ok || ng "rewind.md names the trigger $t"
done
# events_log in config.local.yml moves the log (only there: config.yml's is
# ignored). ~/ is $HOME, a relative path is from the top; folders are made.
[ -e .tixforge/config.local.yml ] && ng "events_log tests expect no config.local.yml"
st init GT-000904 > /dev/null
printf 'events_log: ~/logs/a b/ev.jsonl   # mine\n' > .tixforge/config.local.yml
HOME="$tmp/home" st set GT-000904 Status plan:in-progress > /dev/null
eq '"plan:in-progress"' "$(jq -c .to "$tmp/home/logs/a b/ev.jsonl" 2> /dev/null)" "a path from home (~/) is under HOME, the folders are made"
eq "$tmp/home/logs/a b/ev.jsonl" "$(HOME="$tmp/home" bash -c ". '$scripts/lib.sh'; tf_events .")" "tf_events resolves a path from home"
has "events_log=$tmp/home/logs/a b/ev.jsonl（config.local.yml）" "$(HOME="$tmp/home" bash "$scripts/project-status.sh")" "project-status shows the log and where it comes from"
printf 'events_log: "logs/ev.jsonl"\n' > .tixforge/config.local.yml
st set GT-000904 Status plan:awaiting-approval > /dev/null
eq '"plan:awaiting-approval"' "$(jq -c .to logs/ev.jsonl 2> /dev/null)" "a relative path is from the top"
printf 'events_log: %s\n' "$tmp/abs/ev.jsonl" > .tixforge/config.local.yml
(cd .tixforge && st set GT-000904 Status approach:in-progress > /dev/null)
eq '"approach:in-progress"' "$(jq -c .to "$tmp/abs/ev.jsonl" 2> /dev/null)" "an absolute path, from a subdirectory too"
rm -rf logs .tixforge/config.local.yml
printf 'events_log: %s\n' "$tmp/team/ev.jsonl" >> .tixforge/config.yml
n=$(wc -l < "$evf" | tr -d ' ')
st set GT-000904 Status plan:in-progress > /dev/null
eq $((n + 1)) "$(wc -l < "$evf" | tr -d ' ')" "config.yml's events_log is not read"
[ -e "$tmp/team" ] && ng "config.yml's events_log makes nothing" || ok
has "events_log=$(git rev-parse --show-toplevel)/.tixforge/events.jsonl（既定）" "$(bash "$scripts/project-status.sh")" "project-status shows the default"
sed '/^events_log:/d' .tixforge/config.yml > "$tmp/cfg" && cat "$tmp/cfg" > .tixforge/config.yml
rm -rf .tixforge/GT-000904
# Every line of the log is one JSON object with v, at, ticket and type.
eq 0 "$(jq -c 'select((.v|type) != "number" or (.at|type) != "string" or (.ticket|type) != "string" or (.type|type) != "string")' "$evf" | wc -l | tr -d ' ')" "every event has v, at, ticket and type"
eq "$(wc -l < "$evf" | tr -d ' ')" "$(jq -c . "$evf" | wc -l | tr -d ' ')" "one JSON object per line"
eq 0 "$(jq -r '.id' "$evf" | grep -cvE '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' | tr -d ' ')" "every event has a UUID v4 id"
eq "" "$(jq -r '.id' "$evf" | sort | uniq -d)" "no two events share an id"
rm -rf .tixforge/GT-000909

# Mode: normal without the row; set adds it before Updated; an event per
# change; a rewind sets a small run back to normal.
section="run-state.sh Mode"
st init GT-000940 > /dev/null
f40=.tixforge/GT-000940/state.md
eq normal "$(st get GT-000940 Mode)" "Mode: normal without the row"
n=$(wc -l < "$evf")
eq small "$(st set GT-000940 Mode small)" "set Mode small"
has "$(printf '| Mode    | small                              |\n| Updated |')" "$(cat "$f40")" "the row goes before Updated"
eq $((n + 1)) "$(wc -l < "$evf" | tr -d ' ')" "one event"
eq '{"type":"mode","from":"normal","to":"small"}' "$(tail -1 "$evf" | jq -c '{type, from, to}')" "a mode event"
st set GT-000940 Mode small > /dev/null
eq $((n + 1)) "$(wc -l < "$evf" | tr -d ' ')" "no event when it does not change"
eq 1 "$(grep -c '^| Mode ' "$f40")" "one row"
st set GT-000940 Mode tiny > /dev/null 2>&1
eq 2 $? "Mode is normal or small"
st set GT-000940 Status plan:awaiting-approval > /dev/null
st rewind GT-000940 approach > /dev/null
eq normal "$(st get GT-000940 Mode)" "a rewind sets a small run back to normal"
eq '{"type":"mode","to":"normal"}' "$(grep '"mode"' "$evf" | tail -1 | jq -c '{type, to}')" "and logs it"
rm -rf .tixforge/GT-000940

done_file
