#!/usr/bin/env bash
# Tests for the tixforge scripts other than guard.sh. gh is replaced by a stub
# that serves fixture JSON (through jq, as gh --jq would) and records edits.
#
# Usage: bash tests/scripts.test.sh   (also run it with /bin/bash on macOS for 3.2)
set -u

here=$(cd "$(dirname "$0")" && pwd)
scripts="$here/../scripts"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# The event log is sent only where a test turns it on.
unset TIXFORGE_EVENTS_TOKEN
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

pass=0
fail=0
section=""
ok() { pass=$((pass + 1)); }
ng() {
  fail=$((fail + 1))
  printf 'FAIL  [%s] %s\n' "$section" "$1"
}
# eq <want> <got> <what>
eq() { if [ "$1" = "$2" ]; then ok; else ng "$3: want [$1], got [$2]"; fi; }
# has <text> <haystack> <what>
has() { case "$2" in *"$1"*) ok ;; *) ng "$3: [$1] not in [$2]" ;; esac }

repo="$tmp/repo"
git init -q -b main "$repo"
cd "$repo" || exit 1
mkdir -p .tixforge
cat > .tixforge/config.yml << 'EOF'
# tixforge settings (shared, committed)
language: ja   # comment
commands:      # run in order
  test: echo testing && exit 0
  lint: "echo 'a # not a comment' ; exit 1"
ticket:
  tracker: github
repository:
  base_branch: main
review:
  required: false
gates: [approach, plan, pr]
EOF
git add -A && git commit -q -m init # .tixforge/.gitignore comes with the first run

# --- all scripts ------------------------------------------------------------
# "$var（" makes bash read the first byte of a multibyte character as part of
# the name (unbound variable under set -u, depending on the locale). Write
# ${var} before non-ASCII text.
section="all scripts"
bad=$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$scripts"/*.sh || true)
eq "" "$bad" "no \$var directly followed by a non-ASCII character"

# --- lib.sh ----------------------------------------------------------------
section="lib.sh runs"
# is_early_status / each_run, in a repo of their own.
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
. "$scripts/lib.sh"
r="$tmp/runs"
mkdir -p "$r/.tixforge/GT-000001" "$r/.tixforge/GT-000002" "$r/.tixforge/GT-000003"
printf '| Status | plan:in-progress |\n| Branch | — |\n| Base | main |\n' > "$r/.tixforge/GT-000001/state.md"
printf '| Status | implement:in-progress |\n| Branch | GT-000002-b |\n' > "$r/.tixforge/GT-000002/state.md"
printf '| Status | done |\n| Branch | GT-000003-c |\n| Base | develop |\n\n| Status | x |\n' > "$r/.tixforge/GT-000003/state.md"
is_early_status plan:awaiting-approval && ok || ng "plan is before Implement"
is_early_status implement:in-progress && ng "implement is not early" || ok
out=$(each_run "$r" | tr "$RUN_SEP" '|')
eq "GT-000001|plan:in-progress|—|main
GT-000002|implement:in-progress|GT-000002-b|
GT-000003|done|GT-000003-c|develop" "$out" "each_run: id, Status, Branch, Base; a missing field stays empty; the first row wins"
n=0
while IFS="$RUN_SEP" read -r id st br ba; do
  [ -n "$id" ] || continue
  [ "$id" = GT-000002 ] && [ -z "$ba" ] && n=1
done << EOF
$(each_run "$r")
EOF
eq 1 "$n" "each_run: an empty last field reads back empty"
mkdir -p "$r/.tixforge/GT-000004"
printf '| Status | plan:in-progress |\n| Base | main |\n' > "$r/.tixforge/GT-000004/state.md"
n=0
while IFS="$RUN_SEP" read -r id st br ba; do
  [ "$id" = GT-000004 ] && [ -z "$br" ] && [ "$ba" = main ] && n=1
done << EOF
$(each_run "$r")
EOF
eq 1 "$n" "each_run: an empty field in the middle does not shift the next one"
# The id is the folder name as is; an unreadable state.md still gives a line.
mkdir -p "$r/.tixforge/a\\nb"
printf '| Status | plan:in-progress |\n' > "$r/.tixforge/a\\nb/state.md"
has 'a\nb' "$(each_run "$r" | tr "$RUN_SEP" '|' | grep '^a')" "each_run: a backslash in the id is kept"
rm -rf "$r/.tixforge/a\\nb"
chmod 000 "$r/.tixforge/GT-000004/state.md"
[ -r "$r/.tixforge/GT-000004/state.md" ] || has "GT-000004|||" "$(each_run "$r" | tr "$RUN_SEP" '|')" "each_run: an unreadable state.md gives empty fields"
chmod 644 "$r/.tixforge/GT-000004/state.md"

section="lib.sh cfg"
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
. "$scripts/lib.sh"
eq ja "$(cfg language)" "top-level scalar with comment"
eq github "$(cfg ticket.tracker)" "nested scalar"
eq false "$(cfg review.required)" "review.required"
eq "" "$(cfg ticket.nothing)" "missing key"
eq "approach,plan,pr" "$(cfg_list gates | paste -sd, -)" "cfg_list"
printf 'gates:\n  - plan\n  - pr\n' > "$tmp/block.yml"
eq "plan,pr" "$(cfg_list gates "$tmp/block.yml" | paste -sd, -)" "block list"
eq "test,lint" "$(cfg_map commands | cut -f1 | paste -sd, -)" "command keys in order"
eq "echo testing && exit 0" "$(cfg_map commands | sed -n 1p | cut -f2)" "command value"
# A value quoted only in part keeps its quotes and the rest of the line.
printf 'commands:\n  test: "./run tests.sh" --fast   # note\n  lint: "a # b"   # note\n' > "$tmp/partial.yml"
eq '"./run tests.sh" --fast' "$(cfg_map commands "$tmp/partial.yml" | sed -n 1p | cut -f2)" "partly quoted value"
eq 'a # b' "$(cfg_map commands "$tmp/partial.yml" | sed -n 2p | cut -f2)" "fully quoted value"
# CRLF line ends do not leak into values.
printf 'language: ja\r\nticket:\r\n  tracker: github\r\ngates: [plan, pr]\r\n' > "$tmp/crlf.yml"
eq github "$(cfg ticket.tracker "$tmp/crlf.yml")" "CRLF nested value"
eq ja "$(cfg language "$tmp/crlf.yml")" "CRLF top-level value"
eq "plan,pr" "$(cfg_list gates "$tmp/crlf.yml" | paste -sd, -)" "CRLF list"
cfg_has commands && ok || ng "cfg_has commands"
cfg_has nothing && ng "cfg_has nothing" || ok
# ucfg / user_lang: config.local.yml's language and gates win; other keys
# are always the team's.
mkdir -p "$tmp/uc/.tixforge"
printf 'language: ja\ngates: [approach, plan, pr]\nreview:\n  required: true\n' > "$tmp/uc/.tixforge/config.yml"
eq ja "$(user_lang "$tmp/uc")" "user_lang: config.yml when there is no local file"
eq "$tmp/uc/.tixforge/config.yml" "$(ucfg_file gates "$tmp/uc")" "ucfg_file: config.yml without a local file"
printf 'language: en\nreview:\n  required: false\n' > "$tmp/uc/.tixforge/config.local.yml"
eq en "$(user_lang "$tmp/uc")" "user_lang: the local file wins"
eq "$tmp/uc/.tixforge/config.local.yml" "$(ucfg_file language "$tmp/uc")" "ucfg_file: language from the local file"
eq "$tmp/uc/.tixforge/config.yml" "$(ucfg_file gates "$tmp/uc")" "ucfg_file: gates from config.yml when the local file has none"
eq "$tmp/uc/.tixforge/config.yml" "$(ucfg_file review "$tmp/uc")" "ucfg_file: only language and gates are personal"
printf 'gates: [plan]\n' >> "$tmp/uc/.tixforge/config.local.yml"
eq "plan" "$(cfg_list gates "$(ucfg_file gates "$tmp/uc")")" "ucfg_file: gates from the local file"
printf 'language:\ngates:\n' > "$tmp/uc/.tixforge/config.local.yml"
printf 'language: en\ngates: [plan, pr]\n' > "$tmp/uc/.tixforge/config.yml"
eq en "$(user_lang "$tmp/uc")" "user_lang: an empty local language falls back to config.yml"
eq "$tmp/uc/.tixforge/config.yml" "$(ucfg_file gates "$tmp/uc")" "ucfg_file: empty local gates fall back to config.yml"
printf 'gates: []\n' > "$tmp/uc/.tixforge/config.local.yml"
eq "$tmp/uc/.tixforge/config.local.yml" "$(ucfg_file gates "$tmp/uc")" "ucfg_file: gates: [] in the local file counts"
printf 'language:\n  - fr\ngates:\n  - plan\n' > "$tmp/uc/.tixforge/config.local.yml"
eq en "$(user_lang "$tmp/uc")" "user_lang: a list as the local language falls back to config.yml"
eq "$tmp/uc/.tixforge/config.local.yml" "$(ucfg_file gates "$tmp/uc")" "ucfg_file: a block list of local gates counts"
printf 'language: en\n' > "$tmp/uc/.tixforge/config.local.yml"
rm -f "$tmp/uc/.tixforge/config.yml"
eq en "$(user_lang "$tmp/uc")" "user_lang: the local file alone"
rm -f "$tmp/uc/.tixforge/config.local.yml"
eq ja "$(user_lang "$tmp/uc")" "user_lang: ja with neither file"
# msg: a language given as the second argument wins over config.yml's.
has "This issue body is synced" "$(msg issue_notice en)" "msg <key> en"
has "This issue body is synced" "$(TIXFORGE_MSG_LANG=ja msg issue_notice en)" "msg: the language argument wins over TIXFORGE_MSG_LANG"
eq "Rewound (t1): x & {time} \\1" "$(msg_fill rewind_note en time t1 reason 'x & {time} \1')" "msg_fill replaces each name literally"
eq "巻き戻し（t）：r" "$(msg_fill rewind_note ja time t reason r)" "msg_fill ja"
eq "Rewound ({reason}): R" "$(msg_fill rewind_note en time '{reason}' reason R)" "msg_fill: a {name} inside a value stays"
eq "Rewound ({x}): {reason}" "$(msg_fill rewind_note en time '{x}')" "msg_fill: an unknown or missing name"
# The two messages.yml files share no key: msg takes the first it finds.
keys() { sed -n 's/^  \([a-z_]*\):.*/\1/p' "$1" | sort -u; }
eq "" "$(keys "$scripts/messages.yml" | comm -12 - <(keys "$here/../templates/github/tixforge/messages.yml"))" "the two messages.yml files share no key"
eq 3 "$(section_index Plan)" "section_index"
section_index Nope && ng "section_index: an unknown name fails" || ok
eq "Rewound (t): r" "$(msg_fill rewind_note fr time t reason r)" "msg_fill: a language with no messages is en"
has "> [!NOTE]" "$(msg issue_notice fr)" "msg: the templates file, falling back to en"
# Every state.md message is in every language of scripts/messages.yml.
for k in $(sed -n 's/^  \([a-z_]*\):.*/\1/p' "$scripts/messages.yml" | sort -u); do
  for lang in $(sed -n 's/^\([a-z][a-z_-]*\):$/\1/p' "$scripts/messages.yml"); do
    eq 1 "$(awk -v l="$lang:" -v k="  $k: " '/^[a-z]/ { on = ($0 == l) } on && index($0, k) == 1 { n++ } END { print n + 0 }' "$scripts/messages.yml")" "scripts/messages.yml has $k in $lang"
  done
done

# --- ticket-id.sh ----------------------------------------------------------
section="ticket-id.sh"
tid() { bash "$scripts/ticket-id.sh" "$@"; }
eq GT-000123 "$(tid normalize 123)" "a bare number is issue N"
eq GT-000123 "$(tid normalize '#123')" "#N is issue N"
eq GT-000123 "$(tid normalize gt-000123)" "prefix in any case"
eq GT-000007 "$(tid normalize GT-000007)" "canonical"
eq GT-1234567 "$(tid normalize 1234567)" "more than 6 digits"
eq GT-1234567 "$(tid normalize GT-1234567)" "7 digits with a prefix"
tid normalize GT-00123 2> /dev/null
eq 2 $? "too few digits are not padded"
tid normalize GT-0000123 2> /dev/null
eq 2 $? "too many digits"
tid normalize GT-000000 2> /dev/null
eq 2 $? "number zero"
tid normalize 'a b' 2> /dev/null
eq 2 $? "invalid id"
tid normalize T000123 2> /dev/null
eq 2 $? "the old T-prefix form"
has "GT-000123" "$(tid normalize GT-00123 2>&1)" "the error shows the right form"
# v2's local tickets: an error that points at the migration.
tid normalize LT-000001 2> /dev/null
eq 2 $? "a local ticket (v2) is refused"
mkdir -p .tixforge/LT-000001 && printf '# LT-000001: A\n' > .tixforge/LT-000001/ticket.md
has "/tixforge:project update" "$(tid normalize lt-000001 2>&1)" "an LT still to move points at update"
has "/tixforge:project update" "$(tid normalize LT-1 2>&1)" "found with the wrong digit count too"
rm -rf .tixforge/LT-000001
eq 123 "$(tid number GT-000123)" "number"
eq 8 "$(tid number GT-000008)" "number, not octal"
tid number LT-000001 2> /dev/null
eq 2 $? "a local ticket has no issue number"
tid next 2> /dev/null
eq 2 $? "next is gone"
tid exists LT-000001 2> /dev/null
eq 2 $? "exists: a local ticket (v2) is refused"
has "使えない: LT-12" "$(tid normalize LT-12 2>&1)" "a local id with the wrong digit count is refused too"
tid number LT-000001 2> /dev/null
eq 2 $? "number: a local ticket (v2) is refused"
# A v2 LT that moved, or that v2 finished: the error says so.
mkdir -p .tixforge/LT-000012 .tixforge/LT-000013
printf '# LT-000012: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000012/ticket.md
has "GT-000061 に移した" "$(tid normalize lt-12 2>&1)" "a moved LT names its GT id"
printf '| Field | Value |\n|---|---|\n| Status | plan:in-progress |\n' > .tixforge/LT-000012/state.md
has "先に /tixforge:project update で移行を終えて" "$(tid normalize lt-12 2>&1)" "a moved LT whose run is open: finish the move first"
rm .tixforge/LT-000012/state.md
printf '# LT-000013: B\nStatus: canceled\nReason: 不要になった\n' > .tixforge/LT-000013/ticket.md
has "v2 で終えた" "$(tid normalize LT-000013 2>&1)" "a dropped LT is finished, not to move"
# A bare number is an issue even when a v2 LT has it, with a note.
eq GT-000012 "$(tid normalize 12 2> /dev/null)" "a bare number is still the issue"
has "注意: 12 は issue #12" "$(tid normalize 12 2>&1)" "a note when a v2 LT has the number"
printf '# LT-000013: B\n' > .tixforge/LT-000013/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | done |\n' > .tixforge/LT-000013/state.md
has "v2 で終えた" "$(tid normalize LT-000013 2>&1)" "a done run is finished too"
has "手元に無い" "$(tid normalize LT-000099 2>&1)" "an LT that is not here"
eq 1 "$(tid normalize 0 2>&1 | wc -l | tr -d ' ')" "one error for number zero"
eq "note: 12 は issue #12。v2 の LT-000012 とは別のチケット" "$(tid detect 12 | sed -n 3p)" "detect notes it too"
eq "" "$(tid detect 14 | sed -n 3p)" "no note without a v2 LT"
rm -rf .tixforge/LT-000012 .tixforge/LT-000013

# detect: an id only in an explicit form, or when the whole text is a number.
dt() { tid detect "$@" | sed -n "${n:-1}p"; }
eq "id: none" "$(dt '404 ページを作る')" "a number inside a sentence is not an id"
eq "rest: 404 ページを作る" "$(n=2 dt '404 ページを作る')" "rest keeps the sentence"
eq "id: GT-000404" "$(dt 404)" "the whole text is a number"
eq "id: GT-000012" "$(dt 'GT-000012 の受け入れ条件を直したい')" "explicit id in a sentence"
eq "rest: の受け入れ条件を直したい" "$(n=2 dt 'GT-000012 の受け入れ条件を直したい')" "rest without the id"
eq "id: GT-000007" "$(dt 'ログイン #7 の続き')" "#N in a sentence"
eq "rest: ログイン の続き" "$(n=2 dt 'ログイン #7 の続き')" "rest is tidied"
eq "invalid: gt-12" "$(dt 'gt-12 を直して')" "an explicit id with the wrong digit count"
eq "invalid: LT-000003" "$(dt 'LT-000003 の続き')" "a local ticket (v2) is reported, not ignored"
eq "id: none" "$(dt 'ログイン画面を作りたい')" "no id"
eq "id: none" "$(dt 'v2 の API')" "letters and digits are not an id"

# --- templates/docs/ticket.md -----------------------------------------------
section="ticket template"
# The issue form asks for the same sections, in the same order, as the
# ticket template (Base is not in the form: it is set only when it differs).
tt=$(sed -n 's/^## //p' "$here/../templates/docs/ticket.md" | grep -v '^Base$' | paste -sd'|' -)
form=$(sed -n 's/^ *label: //p' "$here/../templates/github/ISSUE_TEMPLATE/tixforge-ticket.yml" | paste -sd'|' -)
eq "$tt" "$form" "the issue form's sections are the ticket template's"
eq "背景|要件|受け入れ条件|対象外|未決事項" "$tt" "the ticket template's sections"

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
eq 3 "$(st get GT-000901 Format)" "init writes the current Format"
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
st set GT-000905 Status review:in-progress > /dev/null
n=$(wc -l < "$evf")
st set GT-000905 Status implement:in-progress > /dev/null
eq $((n + 3)) "$(wc -l < "$evf" | tr -d " ")" "leaving review:in-progress logs each round, then the status"
eq '{"round":1,"findings":[{"id":"R1","label":"未実装","auto_fix":"fix","decision":"fix (auto)","fixed":"b2c3d4e"},{"id":"R2","label":"合意外の変更","auto_fix":"ask","decision":null,"fixed":null},{"id":"Q1","label":"バグ","auto_fix":"accept","decision":"accept (auto)","fixed":null},{"id":"","label":"","auto_fix":"ask","decision":"reapproach","fixed":null}],"unparsed":1}' \
  "$(grep '"review_round"' "$evf" | tail -2 | head -1 | jq -c '{round, findings, unparsed}')" "round 1: findings from the fixed keys, fences skipped, an item without Auto-fix is unparsed"
eq '{"round":2,"findings":[],"unparsed":0}' "$(grep '"review_round"' "$evf" | tail -1 | jq -c '{round, findings, unparsed}')" "a round without findings"
n=$(wc -l < "$evf")
st set GT-000905 Status review:in-progress > /dev/null
eq $((n + 1)) "$(wc -l < "$evf" | tr -d " ")" "entering Review logs no rounds"
# English labels, CRLF, and a rewind from Review (logged before ## Review moves).
sed -e 's/未実装/missing/' -e 's/$/\r/' "$tmp/review.md" > "$tmp/review-en.md"
awk '$0 == "## Review" { skip = 1; print; next } skip && /^## / { skip = 0 } !skip' "$f5" > "$tmp/s5"
awk -v r="$tmp/review-en.md" '$0 == "## Review" { while ((getline l < r) > 0) print l; next } { print }' "$tmp/s5" > "$f5"
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
  awk -v l="$tmp/rn-log" -v r="$tmp/rn-rev" '
    $0 == "## Implementation Log" { print; while ((getline x < l) > 0) print x; skip = 1; next }
    $0 == "## Review" { print; while ((getline x < r) > 0) print x; skip = 1; next }
    /^## / { skip = 0 }
    !skip' "$tmp/rn-orig" > "$f7"
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
has "legacy: Round 1" "$out" "review-next: and its round is listed as legacy (3.0 may have decided it)"
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

# --- wait-hook.sh ------------------------------------------------------------
# When the person is waited on: Stop / UserPromptSubmit and around
# AskUserQuestion, put on the one open run of the directory. Without jq.
section="wait-hook.sh"
nojq="$tmp/nojq-bin"
mkdir -p "$nojq"
for t in bash git awk grep sed tr head cat dirname wc date mkdir; do
  p=$(command -v "$t") && ln -s "$p" "$nojq/$t"
done
wh="$tmp/wh"
git init -q -b main "$wh"
(cd "$wh" && git commit -q --allow-empty -m init)
# hook <event> [tool] [cwd]: run the hook as Claude Code does, print its output.
hook() {
  printf '{"session_id":"s-1","cwd":"%s","hook_event_name":"%s","tool_name":"%s","prompt":"x"}' "${3:-$wh}" "$1" "${2:-}" \
    | PATH="$nojq" bash "$scripts/wait-hook.sh"
}
eq "" "$(hook Stop)" "no .tixforge: nothing printed"
[ -e "$wh/.tixforge" ] && ng "no .tixforge: nothing created" || ok
(cd "$wh" && bash "$scripts/run-state.sh" init GT-000801 > /dev/null)
whev="$wh/.tixforge/events.jsonl"
n=$(wc -l < "$whev" | tr -d ' ')
eq "" "$(hook Stop)" "Stop prints nothing"
eq "" "$(hook UserPromptSubmit)" "UserPromptSubmit prints nothing (it would go into the context)"
hook PreToolUse AskUserQuestion > /dev/null
hook PostToolUse AskUserQuestion > /dev/null
hook PreToolUse Bash > /dev/null
eq $((n + 4)) "$(wc -l < "$whev" | tr -d ' ')" "four waits logged, another tool ignored"
eq 'wait_start turn|wait_end turn|wait_start question|wait_end question' \
  "$(tail -4 "$whev" | jq -r '"\(.type) \(.cause)"' | paste -sd'|' -)" "type and cause"
eq '{"ticket":"GT-000801","session":"s-1"}' "$(tail -1 "$whev" | jq -c '{ticket, session}')" "the run and the session"
mkdir -p "$wh/sub"
hook Stop "" "$wh/sub" > /dev/null
eq $((n + 5)) "$(wc -l < "$whev" | tr -d ' ')" "from a subdirectory too"
# Two open runs before Implement: which one is waiting is unknown.
(cd "$wh" && bash "$scripts/run-state.sh" init GT-000802 > /dev/null)
n=$(wc -l < "$whev" | tr -d ' ')
hook Stop > /dev/null
eq "$n" "$(wc -l < "$whev" | tr -d ' ')" "two candidate runs: nothing logged"
# The run on the current branch wins over the early ones.
(cd "$wh" && git switch -q -c GT-000801-a && bash "$scripts/run-state.sh" set GT-000801 Branch GT-000801-a > /dev/null \
  && bash "$scripts/run-state.sh" set GT-000801 Status implement:in-progress > /dev/null)
n=$(wc -l < "$whev" | tr -d ' ')
hook Stop > /dev/null
eq GT-000801 "$(tail -1 "$whev" | jq -r .ticket)" "the run on the branch"
mv "$whev" "$tmp/whev" && chmod 500 "$wh/.tixforge"
out=$(hook Stop 2>&1)
eq "0:" "$?:$out" "an unwritable log: exit 0, nothing printed"
chmod 700 "$wh/.tixforge"
eq 0 "$(
  printf 'not json' | PATH="$nojq" bash "$scripts/wait-hook.sh" > /dev/null 2>&1
  echo $?
)" "bad input: exit 0"

# --- events-sync.sh ----------------------------------------------------------
# Sending the log to events.endpoint with TIXFORGE_EVENTS_TOKEN, against a
# small local endpoint (python3) that records each request and answers with
# the status in its "code" file (200 when there is none).
section="events-sync.sh"
if command -v python3 > /dev/null && command -v curl > /dev/null; then
  srv="$tmp/srv"
  mkdir -p "$srv"
  cat > "$tmp/server.py" << 'EOF'
import http.server, json, os, sys, threading, time
d = sys.argv[1]
n = [0]
lock = threading.Lock()
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            code = open(os.path.join(d, "code")).read().strip()
        except Exception:
            code = "200"
        if code == "sleep":
            time.sleep(15)
            return
        try:
            parsed = json.loads(body)
        except Exception:
            self.send_response(400)
            self.end_headers()
            open(os.path.join(d, "bad-json"), "a").write("x")
            return
        with lock:
            n[0] += 1
            k = n[0]
        rec = {"path": self.path, "auth": self.headers.get("Authorization"),
               "type": self.headers.get("Content-Type"), "body": parsed}
        code = int(code)
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"accepted":0,"duplicates":0}')
        with open(os.path.join(d, "req-%d.json.tmp" % k), "w") as f:
            json.dump(rec, f, ensure_ascii=False)
        os.rename(os.path.join(d, "req-%d.json.tmp" % k), os.path.join(d, "req-%d.json" % k))
    def log_message(self, *a):
        pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
s.daemon_threads = True
open(os.path.join(d, "port.tmp"), "w").write(str(s.server_address[1]))
os.rename(os.path.join(d, "port.tmp"), os.path.join(d, "port"))
s.serve_forever()
EOF
  python3 -I "$tmp/server.py" "$srv" &
  srv_pid=$!
  i=0
  while [ ! -f "$srv/port" ] && [ $i -lt 50 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  port=$(cat "$srv/port")
  es="$tmp/es"
  git init -q -b main "$es"
  cd "$es" || exit 1
  git commit -q --allow-empty -m init
  git remote add origin https://github.com/kmjak/demo.git
  esev="$es/.tixforge/events.jsonl"
  esh() { bash "$scripts/events-sync.sh" "$@"; }
  reqs() { find "$srv" -name 'req-*.json' | wc -l | tr -d ' '; }
  req() { cat "$srv/req-$1.json"; }
  # settle [n]: wait for the background sender: n requests in all, and no lock.
  settle() {
    local i=0
    while [ $i -lt 100 ]; do
      if [ "$(reqs)" -ge "${1:-0}" ] && [ ! -d "$esev.lock" ]; then
        sleep 0.2
        [ ! -d "$esev.lock" ] && return 0
      fi
      sleep 0.1
      i=$((i + 1))
    done
    ng "the background sender did not finish (requests: $(reqs))"
  }
  ps_sync() { bash "$scripts/project-status.sh" | sed -n 's/.* \(events_sync=.*\)$/\1/p'; }
  unset TIXFORGE_EVENTS_TOKEN

  # Off: no endpoint, no token, not https, no origin. Nothing is sent.
  st init GT-000001 > /dev/null
  printf 'language: ja\n' > .tixforge/config.yml
  eq "events_sync=off（events.endpoint なし）" "$(ps_sync)" "off without events.endpoint"
  mkdir -p .tixforge
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  eq "events_sync=off（TIXFORGE_EVENTS_TOKEN なし）" "$(ps_sync)" "off without the token"
  export TIXFORGE_EVENTS_TOKEN='tok-"secret\1'
  printf 'events:\n  endpoint: http://example.com/api/events\n' > .tixforge/config.yml
  eq "events_sync=off（events.endpoint が https:// でない）" "$(ps_sync)" "off for http:// other than localhost"
  for u in http://localhost:80@evil.example/x https://user@example.com/x; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=off（events.endpoint に使えない文字（空白・@・\\））" "$(ps_sync)" "off for user info in $u (the token would go to another host)"
  done
  for u in http://localhost.evil.example/x http://127.0.0.1.evil.example/ http://127.0.0.1:8a/x; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=off（events.endpoint が https:// でない）" "$(ps_sync)" "off for a look-alike of localhost: $u"
  done
  for u in https://example.com/api/events http://localhost:3000/api/events http://127.0.0.1/api http://localhost; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=on" "$(ps_sync)" "on for $u"
  done
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  git remote set-url origin /srv/git/nothing
  eq "events_sync=off（origin から owner/repo が分からない）" "$(ps_sync)" "off when origin is not owner/repo"
  for u in git@github.com:kmjak/demo.git ssh://git@github.com/kmjak/demo https://github.com/kmjak/demo.git/; do
    git remote set-url origin "$u"
    eq "events_sync=on" "$(ps_sync)" "owner/repo from $u"
  done
  printf 'events:\n  endpoint: http://example.com/x\n' > .tixforge/config.yml
  esh flush > /dev/null 2>&1
  eq 3 $? "flush when off"
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  eq 0 "$(reqs)" "nothing was sent while off"
  [ -e "$esev.sent" ] && ng "no .sent while off" || ok

  # On: the line written starts sending in the background; what was there
  # before (written while off, and a v3.3 line without an id) goes with it.
  printf '{"v":1,"at":"2026-11-21T10:00:00+09:00","ticket":"GT-000002","type":"run_started","status":"research:in-progress"}\n' >> "$esev"
  eq research:awaiting-approval "$(st set GT-000001 Status research:awaiting-approval)" "set prints what it did while sending"
  settle 1
  eq 1 "$(reqs)" "one request"
  eq /api/events "$(req 1 | jq -r .path)" "POST to the endpoint"
  eq 'Bearer tok-"secret\1' "$(req 1 | jq -r .auth)" "Authorization: Bearer <token>"
  eq application/json "$(req 1 | jq -r .type)" "Content-Type"
  eq kmjak/demo "$(req 1 | jq -r .body.repo)" "repo from origin"
  eq "$(jq -c 'del(.id)' "$esev")" "$(req 1 | jq -c '.body.events[] | del(.id)')" "events: the lines of the log, as they are"
  eq "$(jq -r 'select(.id) | .id' "$esev")" "$(req 1 | jq -r '.body.events[] | select(.ticket != "GT-000002") | .id')" "the ids of the log"
  oldid=$(req 1 | jq -r '.body.events[] | select(.ticket == "GT-000002") | .id')
  printf '%s\n' "$oldid" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-3[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' && ok || ng "a line without id gets one from its text: $oldid"
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" ".sent: all lines sent"
  eq "" "$(jq -c 'select(.id == null)' "$esev" | grep -v GT-000002)" "the log itself is not rewritten"
  # 2xx: the next request has only the new line.
  st set GT-000001 Status approach:in-progress > /dev/null
  settle 2
  eq 1 "$(req 2 | jq '.body.events | length')" "only the new line is sent"
  eq approach:in-progress "$(req 2 | jq -r '.body.events[0].to')" "and it is the new one"
  # 500: run-state works as before; the lines go again next time.
  echo 500 > "$srv/code"
  n=$(cat "$esev.sent")
  out=$(st set GT-000001 Status approach:awaiting-approval)
  eq "0:approach:awaiting-approval" "$?:$out" "set: same exit and output when the endpoint fails"
  settle 3
  eq "$n" "$(cat "$esev.sent")" "a 500 sends nothing"
  has "HTTP 500" "$(esh status)" "status shows the last failure"
  has "unsent: 1" "$(esh status)" "status counts the unsent line"
  esh flush > /dev/null 2>&1
  eq 1 $? "flush fails on 500"
  rm -f "$srv/code"
  eq "sent: $((n + 1)), unsent: 0" "$(esh flush)" "flush after the endpoint is back"
  eq approach:awaiting-approval "$(req "$(reqs)" | jq -r '.body.events[0].to')" "the same line goes again"
  case "$(esh status)" in *"last error"*) ng "a success clears the last failure" ;; *) ok ;; esac
  # Resending a line without id gives it the same id.
  echo 0 > "$esev.sent"
  esh flush > /dev/null
  eq "$oldid" "$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000002") | .id')" "the id from the text is the same every time"
  # At most a batch a time: the rest goes in the next request.
  echo 1 > "$esev.sent"
  r=$(reqs)
  total=$(wc -l < "$esev" | tr -d ' ')
  TIXFORGE_EVENTS_BATCH=2 esh flush > /dev/null
  eq "$(((total - 1 + 1) / 2))" "$(($(reqs) - r))" "batches of at most BATCH lines"
  eq "$total" "$(cat "$esev.sent")" "all sent in batches"
  # A record beyond the end of the log (the log was replaced) starts over.
  echo 999 > "$esev.sent"
  has "unsent: $total" "$(esh status)" "a .sent beyond the log counts as nothing sent"
  esh flush > /dev/null
  # A cut-short line is passed over (it would fail the whole request).
  printf '{"v":1,"id":"x","at":"t","ticket":"GT-000001","ty' >> "$esev"
  printf '\n' >> "$esev"
  esh flush > /dev/null
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "a broken line is passed over, not retried forever"
  # A write cut short has no newline: the next event joins it into one line
  # that starts with { and ends with }, but is not JSON. It is passed over
  # (the endpoint would answer 400 for every request with it).
  printf '{"v":1,"id":"cut","at":"t","ticket":"GT-000001","ty' >> "$esev"
  r=$(reqs)
  has "unsent: 0" "$(esh status)" "a line still being written is not counted"
  st set GT-000001 Status approach:in-progress > /dev/null
  settle $((r + 1))
  eq approach:in-progress "$(req "$(reqs)" | jq -r '.body.events[-1].to')" "the event after a cut-short write is sent"
  case "$(req "$(reqs)" | jq -c .body.events)" in *'"cut"'*) ng "the cut part is not sent" ;; *) ok ;; esac
  [ -e "$srv/bad-json" ] && ng "no request was rejected as bad JSON" || ok
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "and counted as sent"
  # Blank lines only: nothing to POST.
  printf '\n\n' >> "$esev"
  r=$(reqs)
  esh flush > /dev/null
  eq "$r" "$(reqs)" "blank lines make no request"
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "blank lines are passed over"
  # Two identical lines without id are two events, with ids that stay.
  dup='{"v":1,"at":"2026-11-21T10:00:01+09:00","ticket":"GT-000003","type":"wait_end","cause":"turn"}'
  printf '%s\n%s\n' "$dup" "$dup" >> "$esev"
  esh flush > /dev/null
  ids=$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' | paste -sd' ' -)
  eq 2 "$(printf '%s\n' $ids | sort -u | wc -l | tr -d ' ')" "identical lines without id get different ids"
  echo $(($(cat "$esev.sent") - 2)) > "$esev.sent"
  esh flush > /dev/null
  eq "$ids" "$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' | paste -sd' ' -)" "and the same ids when sent again"
  # Without md5sum and md5, cksum gives the id.
  nomd5="$tmp/nomd5-bin"
  mkdir -p "$nomd5"
  for t in bash git awk sed tr cat cut wc date mkdir mktemp mv rm rmdir find touch od curl cksum dirname sleep head grep; do
    p=$(command -v "$t") && ln -sf "$p" "$nomd5/$t"
  done
  echo $(($(cat "$esev.sent") - 2)) > "$esev.sent"
  PATH="$nomd5" bash "$scripts/events-sync.sh" flush > /dev/null
  eq 0 $? "flush works without md5"
  req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' \
    | grep -cE '^[0-9a-f]{8}-[0-9a-f]{4}-3[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' | grep -qx 2 && ok || ng "cksum gives well-formed ids"
  # Two senders at once: every line is sent, .sent ends at the end.
  unset TIXFORGE_EVENTS_TOKEN
  for t in plan approach plan approach plan; do st set GT-000001 Status "$t:in-progress" > /dev/null; done
  export TIXFORGE_EVENTS_TOKEN='tok-"secret\1'
  want=$(jq -Rr 'fromjson? | select(.id) | .id' "$esev" | tail -5)
  r=$(reqs)
  esh flush > /dev/null 2>&1 &
  f1=$!
  esh flush > /dev/null 2>&1 &
  f2=$!
  wait "$f1" "$f2" # not a bare wait: the endpoint runs in the background too
  got=$(for i in $(seq $((r + 1)) "$(reqs)"); do req "$i" | jq -r '.body.events[].id'; done | sort -u)
  for id in $want; do printf '%s\n' "$got" | grep -qx "$id" || ng "two senders: $id was not sent"; done
  ok
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "two senders: .sent reaches the end"
  [ -d "$esev.lock" ] && ng "two senders: the lock is released" || ok
  # The lock: another sender running, and one that died long ago.
  mkdir "$esev.lock"
  esh flush > /dev/null 2>&1
  eq 4 $? "flush waits for no one: another sender runs"
  touch -t 202601010000 "$esev.lock"
  esh flush > /dev/null 2>&1
  eq 0 $? "a lock older than 2 minutes is taken over"
  [ -d "$esev.lock" ] && ng "flush releases the lock" || ok
  # The endpoint takes the connection but never answers: run-state and the
  # hook return at once; the sender gives up after its timeout (5 s).
  echo sleep > "$srv/code"
  n=$(cat "$esev.sent")
  t0=$(date +%s)
  out=$(st set GT-000001 Status plan:awaiting-approval)
  eq "0:plan:awaiting-approval" "$?:$out" "set: same exit and output with an endpoint that never answers"
  printf '{"session_id":"s","cwd":"%s","hook_event_name":"Stop"}' "$es" | bash "$scripts/wait-hook.sh" | cat > /dev/null
  [ $(($(date +%s) - t0)) -le 1 ] && ok || ng "set and the hook do not wait for an endpoint that never answers"
  i=0
  while [ -d "$esev.lock" ] && [ $i -lt 300 ]; do # the background senders time out
    sleep 0.1
    i=$((i + 1))
  done
  t0=$(date +%s)
  esh flush > /dev/null 2>&1
  eq 1 $? "flush fails when the endpoint never answers"
  t=$(($(date +%s) - t0))
  [ "$t" -ge 4 ] && [ "$t" -le 8 ] && ok || ng "flush gives up after about 5 s (took $t s)"
  eq "$n" "$(cat "$esev.sent")" "nothing marked sent after a timeout"
  i=0
  while [ -d "$esev.lock" ] && [ $i -lt 100 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  rm -f "$srv/code"
  # The hook starts the sender too.
  r=$(reqs)
  printf '{"session_id":"s","cwd":"%s","hook_event_name":"Stop"}' "$es" | bash "$scripts/wait-hook.sh"
  settle $((r + 1))
  eq wait_start "$(req "$(reqs)" | jq -r '.body.events[-1].type')" "the hook's event is sent"
  # The endpoint is down: run-state does not wait, the line stays unsent.
  kill "$srv_pid" 2> /dev/null
  wait "$srv_pid" 2> /dev/null
  n=$(cat "$esev.sent")
  t0=$(date +%s)
  st set GT-000001 Status plan:in-progress > /dev/null
  eq 0 $? "set succeeds with the endpoint down"
  [ $(($(date +%s) - t0)) -le 1 ] && ok || ng "set does not wait for the sender"
  settle 0
  esh flush > /dev/null 2>&1
  eq 1 $? "flush fails with the endpoint down"
  eq "$n" "$(cat "$esev.sent")" "nothing marked sent"
  has "応答なし" "$(esh status)" "status says there was no answer"
  # The token is written nowhere.
  eq "" "$(grep -rlF 'secret' "$es/.tixforge" 2> /dev/null)" "the token is in no file"
  case "$(esh status)$(bash "$scripts/project-status.sh")" in *secret*) ng "the token is not printed" ;; *) ok ;; esac
  unset TIXFORGE_EVENTS_TOKEN
  cd "$repo" || exit 1
else
  echo "skip  [events-sync.sh] python3 or curl not found"
fi

# --- project-status.sh -------------------------------------------------------------
section="project-status.sh"
out=$(bash "$scripts/project-status.sh")
has "tracker=github" "$out" "config"
has "gates=approach,plan,pr" "$out" "gates"
has "GT-000901: Status implement:in-progress、Branch GT-000901-a" "$out" "open run, with its Branch"
out=$(cd "$tmp" && bash "$scripts/project-status.sh")
eq 0 $? "outside a repo exits 0"
has "config.yml が無い" "$out" "no config"
cp .tixforge/config.yml "$tmp/keep-gates.yml"
sed 's/^gates: .*/gates: []/' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "gates=[]（pr のみ）" "$(bash "$scripts/project-status.sh")" "explicit empty gates"
grep -v '^gates:' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "gates=（未設定）" "$(bash "$scripts/project-status.sh")" "missing gates"
# init writes config.yml one answer at a time: a config with a single key
# (stopped part way) still reads.
printf 'language: ja\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
eq 0 $? "a partial config.yml exits 0"
has "gates=（未設定）" "$out" "a partial config.yml shows the missing keys"
has "init が途中（無いキー：repository.base_branch、commands、ticket.tracker）" "$out" "a partial config.yml says init stopped part way"
printf 'repository:\n  base_branch: main\n  close_issues: release\ncommands: {}\nticket:\n  tracker: github\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
eq 0 $? "a v2 config with close_issues still reads"
case "$out" in *close_issues*) ng "close_issues is no longer shown" ;; *) ok ;; esac
printf 'repository:\n  base_branch: main\ncommands: {}\nticket:\n  tracker: github\n' > .tixforge/config.yml
case "$(bash "$scripts/project-status.sh")" in *init*途中*) ng "the keys init needs are there" ;; *) ok ;; esac
git rm -q --cached .tixforge/config.yml
has "init が途中（config.yml が commit されていない）" "$(bash "$scripts/project-status.sh")" "an uncommitted config.yml means init has not finished"
git add .tixforge/config.yml
case "$out" in *移行が要る*) ng "a partial config.yml needs no migration" ;; *) ok ;; esac
cp "$tmp/keep-gates.yml" .tixforge/config.yml
has "この人が使う値: language=ja（config.yml） gates=approach,plan,pr（config.yml）" "$(bash "$scripts/project-status.sh")" "personal values from config.yml"
printf 'language: en\ngates: []\n' > .tixforge/config.local.yml
has "この人が使う値: language=en（config.local.yml） gates=[]（pr のみ）（config.local.yml）" "$(bash "$scripts/project-status.sh")" "personal values from config.local.yml"
printf 'language: en\n' > .tixforge/config.local.yml
has "language=en（config.local.yml） gates=approach,plan,pr（config.yml）" "$(bash "$scripts/project-status.sh")" "a local language with the team's gates"
rm -f .tixforge/config.local.yml
grep -v '^language:' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "language=ja（既定）" "$(bash "$scripts/project-status.sh")" "a language nobody wrote is the default"
cp "$tmp/keep-gates.yml" .tixforge/config.yml
# What v2 left: local tickets, tracker: local, host: none.
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "nothing to migrate" ;; *) ok ;; esac
mkdir -p .tixforge/LT-000003
printf '# LT-000003: A\n\n## 背景\n' > .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a local ticket to move"
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a canceled local ticket needs nothing" ;; *) ok ;; esac
printf '# LT-000003: A\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | done |\n' > .tixforge/LT-000003/state.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a done local run needs nothing" ;; *) ok ;; esac
printf '| Field | Value |\n|---|---|\n| Status | plan:awaiting-approval |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a local run in progress"
bash "$scripts/run-state.sh" set LT-000003 Status canceled > /dev/null && ok || ng "run-state set on a local run"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "update closes a local run with run-state set" ;; *) ok ;; esac
printf '| Field | Value |\n|---|---|\n| Status | pr:awaiting-review |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
bash "$scripts/run-state.sh" set LT-000003 Status done > /dev/null && ok || ng "a local run with a PR is finished by hand"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "update closes a local run with run-state set" ;; *) ok ;; esac
# A move stopped halfway: the ticket is canceled, the run is still open.
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | implement:in-progress |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a canceled ticket with an open run"
# A run with no ticket.md.
rm .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "an open run with no ticket"
rm .tixforge/LT-000003/state.md
# Only the header says canceled: a "Status: canceled" line in the body does not.
printf '# LT-000003: A\n\n## 背景\n```\nStatus: canceled\n```\n' > .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "Status: canceled in the body is not the header"
printf '# LT-000003: A\r\nStatus: canceled\r\n\r\n## 背景\r\n' > .tixforge/LT-000003/ticket.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a canceled ticket with CRLF" ;; *) ok ;; esac
# Before init (no config.yml) nothing is reported: init comes first.
printf '# LT-000003: A\n' > .tixforge/LT-000003/ticket.md
mv .tixforge/config.yml "$tmp/no-conf.yml"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "no migration before init" ;; *) ok ;; esac
mv "$tmp/no-conf.yml" .tixforge/config.yml
rm -rf .tixforge/LT-000003
# project-status.sh lt: the folders to move, the same ones counted above.
mkdir -p .tixforge/LT-000003
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | pr:awaiting-review |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
mkdir -p .tixforge/LT-000005 .tixforge/LT-000006/history
printf '# LT-000005: B\n\n## 背景\n' > .tixforge/LT-000005/ticket.md
printf '| Field | Value |\n|---|---|\n| Branch | x |\n' > .tixforge/LT-000006/state.md
eq "$(printf 'LT-000003\tpr:awaiting-review\tcanceled\tGT-000061 に移した\nLT-000005\t-\topen\t\nLT-000006\t?\tnone\t')" \
  "$(bash "$scripts/project-status.sh" lt)" "lt lists each folder to move"
has "移行が要る: LT-000003 LT-000005 LT-000006（" "$(bash "$scripts/project-status.sh")" "the summary counts the same folders"
rm -rf .tixforge/LT-000003 .tixforge/LT-000005 .tixforge/LT-000006
mkdir -p ".tixforge/LT-000007 copy"
printf '# LT-000007: C\nStatus: canceled\nReason: a\tb\n' > ".tixforge/LT-000007 copy/ticket.md"
printf '| Field | Value |\n|---|---|\n| Status | plan:in-progress |\n' > ".tixforge/LT-000007 copy/state.md"
eq "$(printf 'LT-000007 copy\tplan:in-progress\tcanceled\ta b')" "$(bash "$scripts/project-status.sh" lt)" "a folder copy is listed, and a tab in Reason stays one column"
rm -rf ".tixforge/LT-000007 copy"
# Quoted values are read too.
printf 'ticket:\n  tracker: "local"\nrepository:\n  host: \x27none\x27   # v2\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
has "移行が要る: tracker: local（" "$out" "a quoted tracker: local"
has "移行が要る: repository.host: none（" "$out" "a quoted host: none"
cp "$tmp/keep-gates.yml" .tixforge/config.yml
mkdir -p .tixforge/LT-000004/history
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a folder with neither file needs nothing" ;; *) ok ;; esac
sed 's/tracker: github/tracker: local/' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "移行が要る: tracker: local（" "$(bash "$scripts/project-status.sh")" "tracker: local"
printf '# LT-000004: A\n' > .tixforge/LT-000004/ticket.md
has "移行が要る: tracker: local / LT-000004（" "$(bash "$scripts/project-status.sh")" "tracker: local and a local ticket"
rm -rf .tixforge/LT-000004
awk '{ print } /^repository:$/ { print "  host: none" }' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "移行が要る: repository.host: none（" "$(bash "$scripts/project-status.sh")" "host: none"
cp "$tmp/keep-gates.yml" .tixforge/config.yml

# --- session-start.sh ------------------------------------------------------
section="session-start.sh"
git switch -q GT-000901-a
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run GT-000901" "$out" "run on this branch"
has "skills/dev/run.md" "$out" "tells to re-read run.md"
case "$out" in *"skills/dev/pr.md"*) ng "pr.md only in the PR phase" ;; *) ok ;; esac
has "skills/dev/phase/implement.md" "$out" "and the file of the phase in Status"
[ -f "$scripts/../skills/dev/phase/implement.md" ] && ok || ng "the phase file it names exists"
bash "$scripts/run-state.sh" set GT-000901 Status pr:awaiting-review > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr.md" "$out" "the PR phase also re-reads pr.md"
has "skills/dev/pr/follow.md" "$out" "pr:awaiting-review: the file for after the PR"
case "$out" in *"skills/dev/pr/create.md"*) ng "pr:awaiting-review: not the file for creating it" ;; *) ok ;; esac
bash "$scripts/run-state.sh" set GT-000901 Status pr:awaiting-approval > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr/create.md" "$out" "pr:awaiting-approval: the file for creating the PR"
bash "$scripts/run-state.sh" set GT-000901 Status pr:in-progress > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "skills/dev/pr/create.md" "$out" "pr:in-progress: both files (the PR may or may not exist)"
has "skills/dev/pr/follow.md" "$out" "pr:in-progress: both files"
for f in pr.md pr/create.md pr/follow.md; do [ -f "$scripts/../skills/dev/$f" ] && ok || ng "skills/dev/$f exists"; done
case "$out" in *"skills/dev/phase/"*) ng "no phase file in the PR phase" ;; *) ok ;; esac
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
git switch -q main
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
eq "" "$out" "no run on main"
bash "$scripts/run-state.sh" set GT-000901 Status approach:in-progress > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run GT-000901" "$out" "the only run before Implement, with no branch yet"
bash "$scripts/run-state.sh" init GT-000902 > /dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "複数" "$out" "several runs before Implement: ask which"
has "GT-000901 GT-000902" "$out" "both are listed"
rm -rf .tixforge/GT-000902
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null

# A v2 local run waits for the migration: it is not a run to go on with.
mkdir -p .tixforge/LT-000020
printf '| Field | Value |\n|---|---|\n| Status | implement:in-progress |\n| Branch | LT-000020-x |\n' > .tixforge/LT-000020/state.md
git switch -q -c LT-000020-x
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
case "$out" in *LT-000020*) ng "session-start skips a v2 local run" ;; *) ok ;; esac
git switch -q main
git branch -q -D LT-000020-x
rm -rf .tixforge/LT-000020

# --- statusline.sh ---------------------------------------------------------
section="statusline.sh"
sl() { printf '%s' "$1" | bash "$scripts/statusline.sh"; }
git switch -q GT-000901-a
eq "GT-000901 · implement:in-progress" "$(sl "{\"cwd\":\"$repo\"}")" "the run on this branch"
eq "GT-000901 · implement:in-progress" "$(sl "{\"workspace\":{\"current_dir\":\"$repo\"}}")" "workspace.current_dir when there is no cwd"
mkdir -p sub
eq "GT-000901 · implement:in-progress" "$(sl "{\"cwd\":\"$repo/sub\"}")" "from a subdirectory"
rmdir sub
# A finished run on this branch is not shown (current_runs: open runs only).
bash "$scripts/run-state.sh" set GT-000901 Status done > /dev/null
eq "" "$(sl "{\"cwd\":\"$repo\"}")" "a done run on this branch is not the current run"
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
git switch -q main
eq "" "$(sl "{\"cwd\":\"$repo\"}")" "nothing on main with no run before Implement"
bash "$scripts/run-state.sh" set GT-000901 Status plan:awaiting-approval > /dev/null
eq "GT-000901 · plan:awaiting-approval" "$(sl "{\"cwd\":\"$repo\"}")" "the only run before Implement"
bash "$scripts/run-state.sh" init GT-000902 > /dev/null
eq "GT-000901 · plan:awaiting-approval (+1)" "$(sl "{\"cwd\":\"$repo\"}")" "several runs before Implement"
rm -rf .tixforge/GT-000902
bash "$scripts/run-state.sh" set GT-000901 Status implement:in-progress > /dev/null
eq "" "$(sl "{\"cwd\":\"$tmp\"}")" "nothing outside a repository"
eq "" "$(sl '{}')" "nothing without a directory"
eq "" "$(sl "{\"cwd\":\"$repo/missing\"}")" "nothing for a missing directory"

# --- verify.sh -------------------------------------------------------------
section="verify.sh"
echo wip > wip.txt
out=$(bash "$scripts/verify.sh")
code=$?
eq 1 $code "a failing command"
has "Verification @ $(git rev-parse --short HEAD)+dirty: test pass, lint fail" "$out" "result line"
has "log lint:" "$out" "log of the failure"
has "a # not a comment" "$(cat "$(git rev-parse --absolute-git-dir)/tixforge/verify/lint.log")" "quoted # kept"
git stash -q -u
sed 's/exit 1"/exit 0"/' .tixforge/config.yml > "$tmp/c" && cat "$tmp/c" > .tixforge/config.yml
git commit -q -am pass
out=$(bash "$scripts/verify.sh")
eq 0 $? "all pass"
eq "Verification @ $(git rev-parse --short HEAD): test pass, lint pass" "$out" "clean tree"
# --reuse: the kept line when it stands for this tree, else a new run.
vlog="$(git rev-parse --absolute-git-dir)/tixforge/verify"
rm -f "$vlog/lint.log"
eq "$out" "$(bash "$scripts/verify.sh" --reuse)" "--reuse: the line of the last run"
[ -e "$vlog/lint.log" ] && ng "--reuse runs nothing when the result is fresh" || ok
echo wip > wip.txt
has "+dirty" "$(bash "$scripts/verify.sh" --reuse)" "--reuse: a dirty tree runs again"
[ -e "$vlog/lint.log" ] && ok || ng "--reuse: and it ran"
rm wip.txt
bash "$scripts/verify.sh" > /dev/null
git commit -q --allow-empty -m next
rm -f "$vlog/lint.log"
eq "Verification @ $(git rev-parse --short HEAD): test pass, lint pass" "$(bash "$scripts/verify.sh" --reuse)" "--reuse: a new commit runs again"
[ -e "$vlog/lint.log" ] && ok || ng "--reuse: and it ran for the new commit"
printf '  extra: "true"\n' > "$tmp/extra"
cp .tixforge/config.yml "$tmp/before-extra"
awk -v x="$(cat "$tmp/extra")" '{ print } /^commands:/ { print x }' "$tmp/before-extra" > .tixforge/config.yml
git commit -q -am "more commands"
bash "$scripts/verify.sh" > /dev/null
git commit -q --allow-empty -m same-tree
cp "$tmp/before-extra" .tixforge/config.yml
git commit -q -am "fewer commands"
bash "$scripts/verify.sh" > /dev/null
awk -v x="$(cat "$tmp/extra")" '{ print } /^commands:/ { print x }' "$tmp/before-extra" > "$tmp/c2"
has "extra pass" "$(cp "$tmp/c2" .tixforge/config.yml && bash "$scripts/verify.sh" --reuse)" "--reuse: other commands run again"
git checkout -q .tixforge/config.yml
sed 's/exit 0"/exit 1"/' .tixforge/config.yml > "$tmp/c" && cat "$tmp/c" > .tixforge/config.yml
git commit -q -am failing
bash "$scripts/verify.sh" > /dev/null
rm -f "$vlog/lint.log"
bash "$scripts/verify.sh" --reuse > /dev/null
eq 1 $? "--reuse: a failure is not kept"
[ -e "$vlog/lint.log" ] && ok || ng "--reuse: a failure runs again"
git reset -q --hard HEAD~5
bash "$scripts/verify.sh" --bad > /dev/null 2>&1
eq 2 $? "unknown option"
# A command that rewrites a tracked file: the commit was not what the later
# commands checked.
printf 'language: ja\ncommands:\n  fmt: echo x >> wip-tracked.txt\n  test: "true"\n' > .tixforge/config.yml
echo a > wip-tracked.txt && git add wip-tracked.txt .tixforge/config.yml && git commit -q -m tracked
eq "" "$(git status --porcelain)" "the tree is clean before verifying"
out=$(bash "$scripts/verify.sh")
eq 0 $? "a rewriting command still passes"
has "Verification @ $(git rev-parse --short HEAD)+dirty: fmt pass, test pass" "$out" "+dirty when a command changed the tree"
has " M wip-tracked.txt" "$out" "the changed file is listed"
git reset -q --hard HEAD~1
git stash pop -q
printf 'language: ja\ncommands: {}\n' > "$tmp/empty.yml"
cp .tixforge/config.yml "$tmp/keep.yml"
cp "$tmp/empty.yml" .tixforge/config.yml
has "検証コマンドなし" "$(bash "$scripts/verify.sh")" "commands: {}"
printf 'language: en\n' > .tixforge/config.local.yml
has ": no verification commands" "$(bash "$scripts/verify.sh")" "commands: {} in the personal language"
rm -f .tixforge/config.local.yml
printf 'language: en\ncommands: {}\n' > .tixforge/config.yml
has ": no verification commands" "$(bash "$scripts/verify.sh")" "commands: {} in the team language without a personal one"
printf 'language: ja\n' > .tixforge/config.local.yml
has "検証コマンドなし" "$(bash "$scripts/verify.sh")" "commands: {}: a personal ja wins over a team en"
rm -f .tixforge/config.local.yml
printf 'language: ja\n' > .tixforge/config.yml
bash "$scripts/verify.sh" 2> /dev/null
eq 3 $? "no commands key"
cp "$tmp/keep.yml" .tixforge/config.yml

# --- review-input.sh -------------------------------------------------------
section="review-input.sh"
git switch -q GT-000901-a
echo change > file.txt && git add file.txt && git commit -q -m change
# No snapshot yet: dev takes it when the run starts.
out=$(bash "$scripts/review-input.sh" GT-000901 main 2> /dev/null)
eq 3 $? "no snapshot: exit 3"
eq "" "$out" "no snapshot: nothing written or printed"
[ ! -e .git/tixforge/review/GT-000901 ] && ok || ng "no snapshot: no review folder"
printf '# GT-000901: A\n\n## 背景\nスナップショット\n' > .tixforge/GT-000901/snapshot.md
# The Approach and the Plan are what the reviewers judge against.
f1=.tixforge/GT-000901/state.md
cp "$f1" "$tmp/keep-state.md"
out=$(bash "$scripts/review-input.sh" GT-000901 main 2> /dev/null)
eq 4 $? "an empty Approach: exit 4"
[ ! -e .git/tixforge/review/GT-000901 ] && ok || ng "exit 4 writes nothing"
mv "$f1" "$tmp/away.md"
err=$(bash "$scripts/review-input.sh" GT-000901 main 2>&1 > /dev/null)
eq 4 $? "no state.md: exit 4"
has "no run:" "$err" "no state.md: says there is no run"
mv "$tmp/away.md" "$f1"
awk '$0 == "## Approach" { print; print "approach only"; next } { print }' "$tmp/keep-state.md" > "$f1"
err=$(bash "$scripts/review-input.sh" GT-000901 main 2>&1 > /dev/null)
eq 4 $? "an empty Plan: exit 4"
has "empty ## Plan" "$err" "an empty Plan: names it"
# The "> " notes at a section's start and end (a rewind, an auto-passed gate)
# are the implementer's history, not part of the agreement.
awk '$0 == "## Approach" { print; print "> [!NOTE]"; print "> approach body"; print "> quoted inside"; print "```"; print "## Plan"; print "```"; print "> Gate passed automatically (not in gates, nothing to stop for)"; next }
  $0 == "## Plan" { print; print "plan body"; print ""; next } { print }' "$tmp/keep-state.md" | sed 's/$/\r/' > "$f1"
idx=$(bash "$scripts/review-input.sh" GT-000901 main)
d=$(dirname "$idx")
has "/.git/tixforge/review/GT-000901/index.md" "$idx" "prints index.md, outside .tixforge"
has "+change" "$(cat "$d/diff.patch")" "diff"
has "スナップショット" "$(cat "$d/ticket.md")" "the ticket is the snapshot"
eq "$(printf '> [!NOTE]\n> approach body\n> quoted inside\n```\n## Plan\n```')" "$(cat "$d/approach.md")" "approach.md: the Approach body (CRLF, a fenced ## line and quotes kept, the auto-pass note dropped)"
eq "plan body" "$(cat "$d/plan.md")" "plan.md: the Plan body, without the blank lines around it"
has "\`delta.patch\`：無し" "$(cat "$idx")" "index.md: no delta.patch in round 1"
has "- \`$d/plan.md\`" "$(cat "$idx")" "index.md lists the files by absolute path"
has "## 受け取るもの" "$(cat "$idx")" "index.md carries references/review.md"
has "\`frontend.md\`：無し" "$(cat "$idx")" "index.md: no frontend.md without docs/context/frontend.md"
[ ! -e "$d/frontend.md" ] && ok || ng "no frontend.md copied without the design"
mkdir -p docs/context && printf '# フロントエンドの設計\n\n## Path: .\n' > docs/context/frontend.md
idx=$(bash "$scripts/review-input.sh" GT-000901 main)
has "- \`$d/frontend.md\`" "$(cat "$idx")" "index.md lists frontend.md when the project has one"
has "## Path: ." "$(cat "$d/frontend.md")" "frontend.md is docs/context/frontend.md"
rm -rf docs/context
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
[ ! -e "$d/frontend.md" ] && ok || ng "frontend.md removed when the design is gone"
case "$(cat "$idx")" in *"# Review の共通の規則"*) ng "index.md leaves out review.md's maintainer lines" ;; *) ok ;; esac
# --since writes the change after a given commit as delta.patch.
since=$(git rev-parse HEAD)
echo more > more.txt && git add more.txt && git commit -q -m more
idx=$(bash "$scripts/review-input.sh" GT-000901 main --since "$since")
delta="$d/delta.patch"
has "- \`$d/delta.patch\`" "$(cat "$idx")" "index.md: delta.patch from round 2"
has "+more" "$(cat "$delta")" "delta has the new change"
case "$(cat "$delta")" in *"+change"*) ng "delta has only the new change" ;; *) ok ;; esac
has "+change" "$(cat "$d/diff.patch")" "full diff still has everything"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
[ -f "$delta" ] && ng "delta removed without --since" || ok
has "\`delta.patch\`：無し" "$(cat "$idx")" "index.md: back to no delta.patch without --since"
bash "$scripts/review-input.sh" GT-000901 main --since nope 2> /dev/null
eq 2 $? "unknown --since commit"
# A real rewind note (run-state.sh) is dropped; a section with only notes is empty.
cp "$f1" "$tmp/keep-state2.md"
awk '$0 == "## Approach" { print; print "approach body"; next } $0 == "## Plan" { print; print "plan body"; next } { print }' "$tmp/keep-state.md" > "$f1"
st set GT-000901 Status review:in-progress > /dev/null
st rewind GT-000901 plan --reason "Review R2" > /dev/null
awk '$0 == "## Plan" { print; getline; print; print ""; print "new plan"; next } { print }' "$f1" > "$tmp/s1" && cat "$tmp/s1" > "$f1"
has "> 巻き戻し（" "$(cat "$f1")" "the rewind left its note"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
eq "new plan" "$(cat "$d/plan.md")" "plan.md: the rewind note is dropped"
awk '$0 == "## Plan" { print; getline; print; skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$f1" > "$tmp/s1" && cat "$tmp/s1" > "$f1"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null 2>&1
eq 4 $? "a Plan with only the rewind note is empty: exit 4"
cp "$tmp/keep-state2.md" "$f1"
# A local base behind origin/<base>: others' commits there are not this run's.
git switch -q main
echo other > other.txt && git add other.txt && git commit -q -m other
git update-ref refs/remotes/origin/main HEAD
git reset -q --hard HEAD~1
git switch -q GT-000901-a
git merge -q --no-edit origin/main
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
case "$(cat "$d/diff.patch")" in *"+other"*) ng "stale local base: others' commit excluded" ;; *) ok ;; esac
has "+change" "$(cat "$d/diff.patch")" "stale local base: own change kept"
cp "$tmp/keep-state.md" "$f1"
git update-ref -d refs/remotes/origin/main
git switch -q main

# --- ticket-hash.sh --------------------------------------------------------
section="ticket-hash.sh"
th() { bash "$scripts/ticket-hash.sh" "$@"; }
h1=$(printf '## A\nx\n' | th hash "Title")
h2=$(printf '## A\r\nx\r\n\n  \n' | th hash " Title ")
eq "$h1" "$h2" "CRLF and trailing blanks do not change the hash"
h3=$(printf '## A\n x\n' | th hash "Title")
[ "$h1" != "$h3" ] && ok || ng "inner spacing changes the hash"
h4=$(printf '## A\nx\n' | th hash "Title2")
[ "$h1" != "$h4" ] && ok || ng "the title changes the hash"
body=$(printf '> note\n\n<!-- tixforge:hash:abc123abc123 -->\r\n<!-- tixforge:ticket:start -->\r\n## A\r\nx\r\n<!-- tixforge:ticket:end -->\r\n')
eq "$(printf '## A\nx')" "$(printf '%s' "$body" | th extract)" "extract"
eq abc123abc123 "$(printf '%s' "$body" | th stored)" "stored"
printf 'no markers\n' | th extract > /dev/null
eq 3 $? "extract without markers"

# --- gh stub ---------------------------------------------------------------
# Serves $GH_DIR/issue-<n>.json and $GH_DIR/pr.json; writes edits to
# $GH_DIR/calls. `issue edit --body-file f` also updates the fixture body.
bin="$tmp/bin"
mkdir -p "$bin"
GH_DIR="$tmp/gh"
mkdir -p "$GH_DIR"
export GH_DIR
cat > "$bin/gh" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_DIR/calls"
jqf=""; args=()
while [ $# -gt 0 ]; do
  case $1 in --jq) jqf=$2; shift 2 ;; --json) shift 2 ;; *) args+=("$1"); shift ;; esac
done
set -- "${args[@]}"
case "$1 $2" in
  "issue view") jq -r "$jqf" "$GH_DIR/issue-$3.json" ;;
  "pr list") jq -r "$jqf" "$GH_DIR/prs.json" 2>/dev/null || jq -rn "[] | $jqf" ;;
  "pr view") [ -z "${GH_FAIL_PRVIEW:-}" ] || exit 1
    jq -r "$jqf" "$GH_DIR/pr-view.json" 2>/dev/null || jq -rn "{comments: []} | $jqf" ;;
  "issue list") [ -z "${GH_FAIL_ISSUES:-}" ] || { echo "${GH_FAIL_ISSUES}" >&2; exit 1; }
    printf '%s\n' "$*" | grep -q -- 'label:"tixforge:todo","tixforge:in-progress","tixforge:in-review","tixforge:merged"' || { echo "stub gh: issue list without the label search" >&2; exit 1; }
    jq -r "$jqf" "$GH_DIR/issues.json" 2>/dev/null || jq -rn "[] | $jqf" ;;
  "api user") [ -z "${GH_FAIL_USER:-}" ] || { echo "${GH_FAIL_USER}" >&2; exit 1; }; echo "${GH_LOGIN:-me}" ;;
  "api repos/"*)   # .../issues/<n>: an issue, or a PR when the fixture has pull_request; .../issues/<n>/events
    case $2 in
      */events) n=${2%/events}; n=${n##*/}; jq -r "(.events // []) | $jqf" "$GH_DIR/issue-$n.json" ;;
      *) f="$GH_DIR/issue-${2##*/}.json"
         if [ -f "$f" ]; then jq -r "$jqf" "$f"; else echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi ;;
    esac ;;
  "auth status") [ -z "${GH_NO_AUTH:-}" ] ;;
  "repo view") echo o/r ;;
  "label list") cat "$GH_DIR/labels" 2>/dev/null || true ;;
  "label create") echo "$3" >> "$GH_DIR/labels" ;;
  "issue comment")
    n=$3; shift 3
    while [ $# -gt 0 ]; do
      case $1 in
        --body-file) jq --rawfile b "$2" '.comments += [{body: $b}]' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  "issue create")
    echo "https://github.com/o/r/issues/42" ;;
  "issue edit")
    n=$3; shift 3
    while [ $# -gt 0 ]; do
      case $1 in
        --body-file) jq --rawfile b "$2" '.body = $b' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --title) jq --arg t "$2" '.title = $t' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --remove-label) jq --arg l "$2" '.labels |= map(select(.name != $l))' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$bin/gh"
PATH="$bin:$PATH"

# issue <n> <title> <body-file> [state] [reason] [labels-json]
issue() {
  jq -n --arg t "$2" --rawfile b "$3" --arg s "${4:-OPEN}" --arg r "${5:-}" --argjson l "${6:-[]}" \
    '{title: $t, body: $b, state: $s, stateReason: $r, labels: $l, assignees: [], comments: [], closedByPullRequestsReferences: [], events: []}' \
    > "$GH_DIR/issue-$1.json"
}

# --- issue-sync.sh ---------------------------------------------------------
section="issue-sync.sh"
is() { bash "$scripts/issue-sync.sh" "$@"; }
cat > "$tmp/draft.md" << 'EOF'
# <ticket-id>: ログイン

## 背景
ログインしたい

## 受け入れ条件
- [ ] ログインできる
EOF
is body "$tmp/draft.md" > "$tmp/body42"
issue 42 "ログイン" "$tmp/body42" # what gh issue create makes
out=$(is create "$tmp/draft.md")
has "number: 42" "$out" "create prints the number"
has "id: GT-000042" "$out" "create prints the id"
has "--label tixforge:todo" "$(cat "$GH_DIR/calls")" "create labels tixforge:todo"
{
  printf '<!--\nheader\n-->\n'
  cat "$tmp/draft.md"
} > "$tmp/draft-header.md"
is create "$tmp/draft-header.md" > /dev/null 2>&1
eq 2 $? "create refuses a draft whose first line is not the title"
[ ! -e .tixforge/GT-000042 ] && ok || ng "create makes no local copy (dev takes the snapshot)"
mkdir -p .tixforge/GT-000042
is create "$tmp/draft.md" > /dev/null 2>&1
eq 6 $? "create reports an existing ticket folder"
rm -rf .tixforge/GT-000042
has "<!-- tixforge:ticket:start -->" "$(cat "$tmp/body42")" "body has markers"
has "この issue の本文は" "$(cat "$tmp/body42")" "notice in the document language"
issue 42 "ログイン" "$tmp/body42"
eq in-sync "$(is check 42 | sed -n 1p)" "fresh issue is in sync"
eq issue "$(tid exists GT-000042)" "exists: an issue"
jq -n '{title: "a PR", pull_request: {}}' > "$GH_DIR/issue-60.json"
eq pull-request "$(tid exists '#60')" "exists: the number is a pull request"
tid exists GT-000061 > /dev/null
eq 1 $? "exists: no such issue"
cp .tixforge/config.yml "$tmp/keep-lang.yml"
sed 's/^language: ja.*/language: en/' "$tmp/keep-lang.yml" > .tixforge/config.yml
has "This issue body is synced" "$(is body "$tmp/draft.md")" "notice in English"
sed 's/^language: ja.*/language: fr/' "$tmp/keep-lang.yml" > .tixforge/config.yml
has "This issue body is synced" "$(is body "$tmp/draft.md")" "a language without messages falls back to English"
cp "$tmp/keep-lang.yml" .tixforge/config.yml

out=$(is pull 42 .tixforge/GT-000042/ticket.md)
has "created" "$out" "pull creates the working copy"
eq "# GT-000042: ログイン" "$(sed -n 1p .tixforge/GT-000042/ticket.md)" "title line"
eq 0 "$(grep -c '^Issue:' .tixforge/GT-000042/ticket.md)" "no Issue line: the id carries the number"
eq "$(
  ticket_body() { awk '/^## / { on = 1 } on' "$1"; }
  ticket_body "$tmp/draft.md"
)" \
  "$(awk '/^## / { on = 1 } on' .tixforge/GT-000042/ticket.md)" "ticket copied verbatim"
has "unchanged" "$(is pull 42 .tixforge/GT-000042/ticket.md)" "pull again"

# Edited on GitHub: the hash no longer matches.
sed 's/ログインしたい/ログインしたい（直接編集）/' "$tmp/body42" > "$tmp/edited"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"tixforge:out-of-sync"}]'
eq edited "$(is check 42 | sed -n 1p)" "direct edit detected"
eq "remote: changed" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^remote:')" "remote: a direct edit counts as a change"
eq "base: same" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^base:')" "base: the copy itself is untouched"
issue 42 "ログイン（改）" "$tmp/body42"
eq edited "$(is check 42 | sed -n 1p)" "direct title edit detected"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"tixforge:out-of-sync"}]'
is pull 42 .tixforge/GT-000042/ticket.md > /dev/null 2>&1
eq 4 $? "pull refuses an edited issue"
before=$(cat .tixforge/GT-000042/ticket.md)
is pull 42 .tixforge/GT-000042/ticket.md --accept-edited --dry-run | grep -q '直接編集' && ok || ng "dry run shows the diff"
eq "$before" "$(cat .tixforge/GT-000042/ticket.md)" "dry run does not write"
is pull 42 .tixforge/GT-000042/ticket.md --accept-edited | grep -q '直接編集' && ok || ng "pull --accept-edited shows the diff"
is push 42 .tixforge/GT-000042/ticket.md > /dev/null 2>&1
eq 4 $? "push refuses an edited issue"
out=$(is push 42 .tixforge/GT-000042/ticket.md --force)
has "updated" "$out" "push --force rehashes"
has "removed label: tixforge:out-of-sync" "$out" "push removes out-of-sync"
eq "base: same remote: same" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^base:\|^remote:' | paste -sd' ' -)" "after --accept-edited and push --force: same, same"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after adopting"

# Local edit (/tixforge:ticket edit) then push.
sed 's/ログインできる/ログインできる\n- [ ] ログアウトできる/' .tixforge/GT-000042/ticket.md > "$tmp/t" && cat "$tmp/t" > .tixforge/GT-000042/ticket.md
has "updated" "$(is push 42 .tixforge/GT-000042/ticket.md)" "push a local edit"
has "ログアウトできる" "$(jq -r .body "$GH_DIR/issue-42.json")" "issue has the edit"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after push"
has "unchanged" "$(is push 42 .tixforge/GT-000042/ticket.md)" "push again"

# Markers removed on GitHub.
printf 'just text\n' > "$tmp/nomark"
issue 43 "x" "$tmp/nomark"
eq no-markers "$(is check 43 | sed -n 1p)" "no markers"
is pull 43 .tixforge/GT-000043/ticket.md > /dev/null 2>&1
eq 3 $? "pull without markers"

# An issue made before hashes.
grep -v 'tixforge:hash' "$tmp/body42" > "$tmp/nohash"
issue 44 "ログイン" "$tmp/nohash"
eq no-hash "$(is check 44 | sed -n 1p)" "no hash"
has "created" "$(is pull 44 .tixforge/GT-000044/ticket.md)" "pull an issue without a hash"
eq "base: same remote: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:\|^remote:' | paste -sd' ' -)" "no hash line in the body: base and remote still work"
tr -d '\r' < .tixforge/GT-000044/ticket.md | sed 's/$/\r/' > "$tmp/crlf44" && cp "$tmp/crlf44" .tixforge/GT-000044/ticket.md
eq "base: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:')" "base: CRLF is not a change"
# With no hash line in the body, a direct edit is caught by the lock.
is pull 44 .tixforge/GT-000044/ticket.md > /dev/null
sed 's/ログインできる/直接の変更/' "$tmp/nohash" > "$tmp/nohash2"
issue 44 "ログイン" "$tmp/nohash2"
sed 's/ログインしたい/私の変更/' .tixforge/GT-000044/ticket.md > "$tmp/mine44" && cp "$tmp/mine44" .tixforge/GT-000044/ticket.md
is push 44 .tixforge/GT-000044/ticket.md > /dev/null 2>&1
eq 5 $? "no hash line: push refuses after a direct edit"
# Text before the first ## in the body: not a change of the copy.
awk '{ print } /tixforge:ticket:start/ { print "前置き" }' "$tmp/nohash" > "$tmp/intro44"
issue 44 "ログイン" "$tmp/intro44"
rm -f .tixforge/GT-000044/ticket.md .tixforge/GT-000044/.ticket.md.hash
is pull 44 .tixforge/GT-000044/ticket.md > /dev/null
eq "base: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:')" "base: text before the first ## is not a change"

# Canceled issue: Status / Reason come back.
sed '1s/.*/# <ticket-id>: やめた/' "$tmp/draft.md" > "$tmp/draft45"
is body "$tmp/draft45" > "$tmp/body45"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
jq '.comments = [{"body":"Canceled by tixforge: 優先度が下がった"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by tixforge (comment)"
# v3 writes an invisible mark, then the document language.
jq '.comments = [{"body":"<!-- tixforge:canceled -->\nキャンセル：優先度が下がった"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by tixforge (the mark)"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.comments = [{"body":"<!-- tixforge:closed -->\nhttps://github.com/o/r/pull/3 のマージで完了"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by tixforge (the mark)"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
jq '.comments = [{"body":"<!-- tixforge:closed -->\n完了"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: unexpected" "$(is check 45 | sed -n 2p)" "the closed mark on an issue closed as not planned is not a cancel"
# markc <reason> <comments-json>: closed_as for #45 closed with them.
markc() {
  issue 45 "やめた" "$tmp/body45" CLOSED "$1"
  jq --argjson c "$2" '.comments = $c' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
  is check 45 | sed -n 2p
}
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"<!-- tixforge:canceled -->\r\nキャンセル"}]')" "the mark with CRLF"
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"\n  <!-- tixforge:canceled -->\nキャンセル"}]')" "the mark after blank space"
eq "closed_as: unexpected" "$(markc NOT_PLANNED '[{"body":"何か\n<!-- tixforge:canceled -->"}]')" "the mark on a second line does not count"
eq "closed_as: unexpected" "$(markc COMPLETED '[{"body":"<!-- tixforge:canceled -->\nx"}]')" "the canceled mark on an issue closed as completed is not a close"
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"thanks"},{"body":"<!-- tixforge:canceled -->\nx"}]')" "the mark in a later comment"
# v2 closed issues with English comments. GitHub comments are never
# migrated, so they keep being read (here with the labels taken off).
for c in "Closed by tixforge: https://github.com/o/r/pull/3 merged" "Closed by tixforge-issue-sync: https://github.com/o/r/pull/3 merged"; do
  issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
  jq --arg c "$c" '.comments = [{body: $c}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
  eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed with v2's comment: ${c%%:*}"
done
is pull 45 .tixforge/GT-000045/ticket.md > /dev/null
eq 0 "$(grep -c '^Status:' .tixforge/GT-000045/ticket.md)" "pull writes no Status line: the issue says it"
issue 45 "やめた" "$tmp/body45" OPEN ""
eq "closed_as: open" "$(is check 45 | sed -n 2p)" "reopened: open again"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED '[{"name":"tixforge:canceled"}]'
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by label"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:in-review"}]'
eq "closed_as: unexpected" "$(is check 45 | sed -n 2p)" "closed by hand"
jq '.events = [{"event":"closed","commit_id":"abc123"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by a commit (Closes in a commit reaching the default branch)"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:merged"}]'
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "merged label"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.closedByPullRequestsReferences = [{"number":9}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by a PR"
# status: the same, in the words the instruction files use.
st45() { is check 45 | sed -n 's/^status: //p'; }
eq completed "$(st45)" "status: completed"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED '[{"name":"tixforge:canceled"}]'
eq canceled "$(st45)" "status: canceled"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:in-review"}]'
eq closed-completed "$(st45)" "status: closed by hand as completed"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
eq closed-not-planned "$(st45)" "status: closed by hand as not planned"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-progress"}]'
eq open "$(st45)" "status: open"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-review"}]'
eq in-review "$(st45)" "status: in-review"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:merged"}]'
eq merged "$(st45)" "status: merged, waiting for the release"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-review"},{"name":"tixforge:merged"}]'
eq merged "$(st45)" "status: merged wins over in-review"
issue 45 "やめた" "$tmp/body45" CLOSED DUPLICATE
eq closed "$(st45)" "status: closed by hand with another reason"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.comments = [{"body":"Closed by tixforge: https://github.com/o/r/pull/3 merged"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq completed "$(st45)" "status: closed with v2's comment"

# Optimistic lock: someone else pushed after this copy was fetched.
issue 46 "ログイン" "$tmp/body42"
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
cp .tixforge/GT-000046/ticket.md "$tmp/mine46"
sed 's/ログインしたい/他の人の変更/' .tixforge/GT-000046/ticket.md > "$tmp/theirs46" && cp "$tmp/theirs46" .tixforge/GT-000046/ticket.md
is push 46 .tixforge/GT-000046/ticket.md > /dev/null # the other person's push (their copy is fresh)
cp "$tmp/mine46" .tixforge/GT-000046/ticket.md
bash "$scripts/ticket-hash.sh" stored < "$tmp/body42" > .tixforge/GT-000046/.ticket.md.hash # my copy came from the old version
sed 's/ログインできる/私の変更/' "$tmp/mine46" > .tixforge/GT-000046/ticket.md
is push 46 .tixforge/GT-000046/ticket.md > /dev/null 2>&1
eq 5 $? "push refuses: the issue changed since it was fetched"
has "他の人の変更" "$(jq -r .body "$GH_DIR/issue-46.json")" "the other person's change is kept"
eq "local: differs" "$(is check 46 .tixforge/GT-000046/ticket.md | sed -n 3p)" "check: the copy is not the last synced version"
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
eq "local: same" "$(is check 46 .tixforge/GT-000046/ticket.md | sed -n 3p)" "check: after pull the copy is the synced version"
eq "local: missing" "$(is check 46 "$tmp/none.md" | sed -n 3p)" "check: no copy"
# dev's snapshot and edit's editing.md keep their own hash: pulling the
# snapshot does not lift the lock of an edit fetched before it.
cp "$GH_DIR/issue-46.json" "$tmp/keep46"
is pull 46 .tixforge/GT-000046/editing.md > /dev/null
cp .tixforge/GT-000046/editing.md "$tmp/mine46b"
sed 's/他の人の変更/さらに別の人の変更/' .tixforge/GT-000046/editing.md > "$tmp/other46"
is push 46 "$tmp/other46" > /dev/null 2>&1 # another person's push from a fresh copy
is pull 46 .tixforge/GT-000046/snapshot.md > /dev/null
[ -f .tixforge/GT-000046/.snapshot.md.hash ] && [ -f .tixforge/GT-000046/.editing.md.hash ] && ok || ng "one hash file per copy"
sed 's/ログインできる/私の変更/' "$tmp/mine46b" > .tixforge/GT-000046/editing.md
is push 46 .tixforge/GT-000046/editing.md > /dev/null 2>&1
eq 5 $? "pulling the snapshot keeps the edit's lock"
has "さらに別の人の変更" "$(jq -r .body "$GH_DIR/issue-46.json")" "the other person's change is kept"
cp "$tmp/keep46" "$GH_DIR/issue-46.json"
rm -f .tixforge/GT-000046/editing.md .tixforge/GT-000046/.editing.md.hash .tixforge/GT-000046/snapshot.md .tixforge/GT-000046/.snapshot.md.hash
# v2's working copy becomes the snapshot, so a change made since shows.
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
sed 's/他の人の変更/v2 のときの内容/' .tixforge/GT-000046/ticket.md > "$tmp/v2t" && cp "$tmp/v2t" .tixforge/GT-000046/ticket.md
mv .tixforge/GT-000046/.ticket.md.hash .tixforge/GT-000046/.issue-hash
out=$(is pull 46 .tixforge/GT-000046/snapshot.md)
has "moved: " "$out" "v2's ticket.md moves to snapshot.md"
has "v2 のときの内容" "$out" "and the diff shows what changed since"
eq "base: same remote: same" "$(is check 46 .tixforge/GT-000046/snapshot.md | grep '^base:\|^remote:' | paste -sd' ' -)" "after the v2 move: same, same"
[ ! -e .tixforge/GT-000046/ticket.md ] && [ -f .tixforge/GT-000046/.snapshot.md.hash ] && [ ! -e .tixforge/GT-000046/.issue-hash ] && ok || ng "ticket.md and .issue-hash are moved"
rm -f .tixforge/GT-000046/snapshot.md .tixforge/GT-000046/.snapshot.md.hash
# The move only for a missing snapshot.md, never in a dry run or for
# editing.md.
printf '# GT-000046: v2\n\n## 背景\nv2\n' > .tixforge/GT-000046/ticket.md
out=$(is pull 46 .tixforge/GT-000046/snapshot.md --dry-run)
has "would move: " "$out" "dry run: the move is announced"
has "v2" "$out" "dry run: the diff is against v2's copy"
[ -f .tixforge/GT-000046/ticket.md ] && [ ! -e .tixforge/GT-000046/snapshot.md ] && ok || ng "dry run moves nothing"
is pull 46 .tixforge/GT-000046/editing.md > /dev/null
[ -f .tixforge/GT-000046/ticket.md ] && ok || ng "editing.md does not take v2's copy"
rm .tixforge/GT-000046/ticket.md
is pull 46 .tixforge/GT-000046/snapshot.md > /dev/null
printf '# GT-000046: v2\n' > .tixforge/GT-000046/ticket.md
has "unchanged: " "$(is pull 46 .tixforge/GT-000046/snapshot.md)" "an existing snapshot is kept"
[ -f .tixforge/GT-000046/ticket.md ] && ok || ng "an existing snapshot leaves v2's copy alone"
# base / remote: the copy and the issue against the version it was taken at.
f46=.tixforge/GT-000046/snapshot.md
eq "base: same" "$(is check 46 "$f46" | grep '^base:')" "base: same right after pull"
eq "remote: same" "$(is check 46 "$f46" | grep '^remote:')" "remote: same right after pull"
sed 's/ログインできる/書き戻していない変更/' "$f46" > "$tmp/b46" && cp "$tmp/b46" "$f46"
eq "base: changed" "$(is check 46 "$f46" | grep '^base:')" "base: changed after a local edit"
cp "$GH_DIR/issue-46.json" "$tmp/keep46"
{
  cat .tixforge/GT-000046/editing.md
  printf -- '- また誰かの変更\n'
} > "$tmp/someone46"
is push 46 "$tmp/someone46" > /dev/null 2>&1
eq "remote: changed" "$(is check 46 "$f46" | grep '^remote:')" "remote: changed after someone else's push"
eq "base: none" "$(is check 46 "$tmp/none.md" | grep '^base:')" "base: none without a copy"
cp "$tmp/keep46" "$GH_DIR/issue-46.json"
rm -f .tixforge/GT-000046/*.md .tixforge/GT-000046/.*.hash
eq "assignees: " "$(is check 46 | tail -1)" "check: no assignee"
jq '.assignees = [{"login":"me"},{"login":"someone"}]' "$GH_DIR/issue-46.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-46.json"
eq "assignees: me,someone" "$(is check 46 | tail -1)" "check: assignees on the last line"

# adopt: an issue written on GitHub (issue form), then written back keeping the original.
printf '### 背景\n\nフォームから\n\n### 要件\n\n- 何か\n\n### 未決事項\n\n_No response_\n' > "$tmp/form"
issue 47 "フォームの issue" "$tmp/form" OPEN "" '[{"name":"tixforge:todo"}]'
out=$(is adopt 47 .tixforge/GT-000047/ticket.md)
has "adopted" "$out" "adopt"
eq "# GT-000047: フォームの issue" "$(sed -n 1p .tixforge/GT-000047/ticket.md)" "adopt: title line"
has "## 背景" "$(cat .tixforge/GT-000047/ticket.md)" "adopt: ### becomes ##"
has "なし" "$(cat .tixforge/GT-000047/ticket.md)" "adopt: _No response_ becomes なし"
is adopt 42 "$tmp/x.md" 2> /dev/null
eq 2 $? "adopt refuses an issue tixforge wrote"
out=$(is push 47 .tixforge/GT-000047/ticket.md --force --keep-original)
has "commented: the original body" "$out" "keep-original comments first"
has "フォームから" "$(jq -r '.comments[0].body' "$GH_DIR/issue-47.json")" "the original body is in the comment"
eq in-sync "$(is check 47 | sed -n 1p)" "adopted issue is in sync"

# --- issue-label.sh --------------------------------------------------------
section="issue-label.sh"
il() { bash "$scripts/issue-label.sh" "$@"; }
jq '.labels = [{"name":"tixforge:todo"},{"name":"bug"}] | .assignees = []' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
: > "$GH_DIR/calls"
has "tixforge:in-progress" "$(il 42 start)" "start"
has "--remove-label tixforge:todo --add-label tixforge:in-progress --add-assignee @me" "$(tail -1 "$GH_DIR/calls")" "start edits"
jq '.assignees = [{"login":"someone"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 start 2> /dev/null
eq 4 $? "someone else is assigned"
il 42 start --force > /dev/null
eq 0 $? "start --force"
jq '.assignees = [{"login":"me"}] | .labels = [{"name":"tixforge:in-review"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 reset > /dev/null
has "--remove-label tixforge:in-review --add-label tixforge:todo --remove-assignee @me" "$(tail -1 "$GH_DIR/calls")" "reset edits"
jq '.state = "CLOSED"' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 review 2> /dev/null
eq 3 $? "closed issue"
jq '.labels = [{"name":"tixforge:in-review"},{"name":"tixforge:out-of-sync"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 done > /dev/null
eq 0 $? "done applies to a closed issue"
has "--remove-label tixforge:in-review --add-label tixforge:done" "$(tail -1 "$GH_DIR/calls")" "done: one status label, out-of-sync kept"
il 42 canceled > /dev/null
eq 0 $? "canceled applies to a closed issue"
il 42 merged > /dev/null
has "--add-label tixforge:merged" "$(tail -1 "$GH_DIR/calls")" "merged"
il 42 done --force 2> /dev/null
eq 2 $? "--force is only for start"
printf 'tixforge:todo\nbug\n' > "$GH_DIR/labels"
out=$(il setup --dry-run)
has "$(printf 'tixforge:in-progress\tdev を進めている（assignee が担当）')" "$out" "setup --dry-run lists a missing label with its description"
case "$out" in *tixforge:todo*) ng "setup --dry-run skips an existing label" ;; *) ok ;; esac
eq "tixforge:todo
bug" "$(cat "$GH_DIR/labels")" "setup --dry-run creates nothing"
has "$(printf 'tixforge:in-progress\tBeing developed')" "$(il setup --dry-run --lang en)" "setup --lang en describes in English (init runs it before config.yml has a language)"
cp .tixforge/config.yml "$tmp/keep-lang.yml"
printf 'language: ja\n' > .tixforge/config.yml
has "$(printf 'tixforge:in-progress\tBeing developed')" "$(il setup --dry-run --lang en)" "--lang wins over config.yml's language"
has "$(printf 'tixforge:in-progress\tdev を進めている')" "$(MSG_LANG=en il setup --dry-run)" "an unrelated MSG_LANG in the environment changes nothing"
cp "$tmp/keep-lang.yml" .tixforge/config.yml
il setup --lang 2> /dev/null
eq 2 $? "setup --lang needs a value"
out=$(il setup)
has "tixforge:in-progress" "$out" "setup creates the missing labels"
case "$out" in *"tixforge:todo "* | *"tixforge:todo") ng "setup skips an existing label" ;; *) ok ;; esac
eq "labels: all present" "$(il setup)" "setup again"
has "--description dev を進めている（assignee が担当）" "$(cat "$GH_DIR/calls")" "setup takes the description from messages.yml, in the document language"
# Every label is one of label_defs, with a description in each language,
# and every tixforge: label the Actions templates use is one of them.
defs=$(sed -n '/^label_defs() {/,/^}/p' "$scripts/issue-label.sh" | grep -o 'tixforge:[a-z-]*' | sort -u)
[ -n "$defs" ] && ok || ng "no labels found in label_defs"
for l in $defs; do
  k="label_$(printf '%s' "${l#tixforge:}" | tr '-' '_')"
  for lang in $(sed -n 's/^\([a-z][a-z_-]*\):$/\1/p' "$here/../templates/github/tixforge/messages.yml"); do
    eq 1 "$(awk -v l="$lang:" -v k="  $k: " '/^[a-z]/ { on = ($0 == l) } on && index($0, k) == 1 { n++ } END { print n + 0 }' "$here/../templates/github/tixforge/messages.yml")" "messages.yml has $k in $lang"
  done
done
for l in $(grep -oh 'tixforge:[a-z][a-z-]*' "$here"/../templates/github/*.yml "$here"/../templates/github/ISSUE_TEMPLATE/*.yml | sort -u); do
  case $l in tixforge:hash | tixforge:ticket | tixforge:project | tixforge:dev) continue ;; esac
  printf '%s\n' "$defs" | grep -qx "$l" && ok || ng "a template uses $l, which label_defs does not define"
done
for l in $(sed -n 's/^STATUS_LABELS="\(.*\)"/\1/p' "$scripts/issue-label.sh"); do
  printf '%s\n' "$defs" | grep -qx "$l" && ok || ng "STATUS_LABELS has $l, which label_defs does not define"
done

# --- github-preflight.sh ---------------------------------------------------
section="github-preflight.sh"
eq "ok: o/r" "$(bash "$scripts/github-preflight.sh")" "ok"
GH_NO_AUTH=1 bash "$scripts/github-preflight.sh" > /dev/null
eq 4 $? "not logged in"
# A PATH with bash only: gh may live in /usr/bin (GitHub's Ubuntu runners).
nogh="$tmp/nogh-bin"
mkdir -p "$nogh"
ln -s "$(command -v bash)" "$nogh/bash"
PATH="$nogh" "$nogh/bash" "$scripts/github-preflight.sh" > /dev/null
eq 3 $? "no gh"

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

# --- branch.sh ---------------------------------------------------------------
# The Base (the user's, the ticket's ## Base, the config, origin's default)
# and a branch name that is free locally and on origin (a bare repository).
section="branch.sh"
br() { bash "$scripts/branch.sh" "$@"; }
back=$(git symbolic-ref --short HEAD)
git init -q --bare "$tmp/borigin.git"
git remote add origin "$tmp/borigin.git"
git push -q origin "$back:main" "$back:develop" 2> /dev/null
git remote set-head origin main 2> /dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
st init GT-000910 > /dev/null
out=$(br base GT-000910)
eq "$(printf 'base: main\nfrom: config')" "$out" "base: repository.base_branch"
printf '# GT-000910: x\n\n## 背景\nx\n\n## Base\n<!-- a comment\n  on two lines -->\n\n  develop  \n\n## 要件\nx\n' > .tixforge/GT-000910/snapshot.md
eq "$(printf 'base: develop\nfrom: ticket')" "$(br base GT-000910)" "base: the ticket's ## Base, past comments and blanks"
eq "$(printf 'base: main\nfrom: user')" "$(br base GT-000910 main)" "base: the user's comes first"
br base GT-000910 nowhere > /dev/null 2>&1
eq 3 $? "base: not on origin"
has "base: nowhere" "$(br base GT-000910 nowhere 2> /dev/null)" "base: still printed when not on origin"
rm .tixforge/GT-000910/snapshot.md
cp .tixforge/config.yml "$tmp/bconf"
grep -v 'base_branch' "$tmp/bconf" > .tixforge/config.yml
eq "$(printf 'base: main\nfrom: origin')" "$(br base GT-000910)" "base: origin's default without the config"
cp "$tmp/bconf" .tixforge/config.yml
eq "name: GT-000910-add-x" "$(br name GT-000910 add-x)" "name: free"
git branch GT-000910-add-x
eq "name: GT-000910-add-x-2" "$(br name GT-000910 add-x)" "name: a local branch of the name: -2"
git push -q origin "$back:GT-000910-add-x-2" 2> /dev/null
eq "name: GT-000910-add-x-3" "$(br name GT-000910 add-x)" "name: -2 on origin too: -3"
st set GT-000910 Branch GT-000910-add-x-2 > /dev/null
eq "name: GT-000910-add-x-2" "$(br name GT-000910 add-x)" "name: the run's own Branch is kept"
st set GT-000910 Branch GT-000910-add-x-2fa > /dev/null
eq "name: GT-000910-add-x-3" "$(br name GT-000910 add-x)" "name: a Branch that only starts with the name is not the run's"
for s in Add_X 'a b' ''; do
  br name GT-000910 "$s" > /dev/null 2>&1
  eq 2 $? "name: slug [$s] refused"
done
br name GT-999999 x > /dev/null 2>&1
eq 1 $? "name: no such run"
git branch -q -D GT-000910-add-x
git remote remove origin
rm -rf .tixforge/GT-000910 "$tmp/borigin.git"

# --- pr-resume.sh ----------------------------------------------------------
# Where a run in the PR phase goes on from: Status, the PRs of the branch
# ($GH_DIR/prs.json), the PR's comments ($GH_DIR/pr-view.json), an origin
# (a bare repository here) and the hashes in state.md.
section="pr-resume.sh"
prr() { bash "$scripts/pr-resume.sh" "$@"; }
nxt() { prr GT-000909 | sed -n 's/^next: //p'; }
back=$(git symbolic-ref --short HEAD)
git init -q --bare "$tmp/origin.git"
git remote add origin "$tmp/origin.git"
git switch -q -c GT-000909-x
git commit -q --allow-empty -m pr1
h1=$(git rev-parse HEAD)
git push -q -u origin GT-000909-x 2> /dev/null
st init GT-000909 > /dev/null
st set GT-000909 Branch GT-000909-x > /dev/null
f9=.tixforge/GT-000909/state.md
# prs <state> <head> [<state> <head> ...]: the PRs gh pr list returns.
prs_of() {
  local a="[]" i=1
  while [ $# -ge 2 ]; do
    a=$(printf '%s' "$a" | jq --arg s "$1" --arg h "$2" --argjson n "$i" '. + [{number: $n, state: $s, url: "https://github.com/o/r/pull/\($n)", headRefOid: $h}]')
    i=$((i + 1))
    shift 2
  done
  printf '%s\n' "$a" > "$GH_DIR/prs.json"
}
comments() { jq -n --args '{comments: [$ARGS.positional[] | {body: .}]}' "$@" > "$GH_DIR/pr-view.json"; }
st set GT-000909 Status pr:in-progress > /dev/null
prs_of
eq create "$(nxt)" "no PR: create"
prs_of CLOSED "$h1"
out=$(prr GT-000909)
has "next: create" "$out" "only a closed PR: create"
has "closed: https://github.com/o/r/pull/1" "$out" "and the closed one is named"
has "pr: none" "$out" "but not used"
prs_of MERGED "$h1"
eq merged "$(nxt)" "a merged PR: merged"
st set GT-000909 Status pr:awaiting-approval > /dev/null
prs_of
eq gate "$(nxt)" "awaiting approval, no PR: the gate again"
prs_of OPEN "$h1"
comments "LGTM"
out=$(prr GT-000909)
has "next: finish-create" "$out" "awaiting approval with an open PR: finish the creation"
has "comment: missing" "$out" "and the verification comment is missing"
has "head: $(git rev-parse --short HEAD)" "$out" "the PR's head"
comments "x" "$(printf 'Verification @ %s: test pass\n\n### test' "${h1:0:7}")"
has "comment: present" "$(prr GT-000909)" "a comment for the PR's head"
comments "$(printf 'Verification @ %s+dirty: test pass' "${h1:0:7}")" "$(printf 'Verification @ %s: test pass' "${h1:0:3}")"
has "comment: missing" "$(prr GT-000909)" "a +dirty or too short hash is no comment for the head"
GH_FAIL_PRVIEW=1 prr GT-000909 > /dev/null 2>&1
eq 4 $? "gh pr view fails: exit 4"
st set GT-000909 Status pr:awaiting-review > /dev/null
eq status "$(nxt)" "awaiting review: status"
prs_of CLOSED "$h1"
has "pr: https://github.com/o/r/pull/1" "$(prr GT-000909)" "awaiting review and the PR was closed: status with it"
prs_of
printf '\n## PR\n- URL: https://github.com/o/r/pull/7\n' >> "$f9"
has "pr: https://github.com/o/r/pull/7" "$(prr GT-000909)" "awaiting review, no PR found: the URL in ## PR"
awk '$0 == "## PR" { exit } { print }' "$f9" > "$tmp/f9" && cat "$tmp/f9" > "$f9"
st set GT-000909 Status pr:in-progress > /dev/null
prs_of OPEN "$h1"
comments
printf '\n## PR\nPR head @ %s\n' "${h1:0:7}" >> "$f9"
eq status "$(nxt)" "in progress, HEAD is the PR head: status"
git commit -q --allow-empty -m pr2
h2=$(git rev-parse HEAD)
eq push-fix "$(nxt)" "a commit not pushed: push-fix"
git push -q origin GT-000909-x 2> /dev/null
eq comment-fix "$(nxt)" "pushed, no comment for HEAD: comment-fix"
comments "$(printf 'Verification @ %s: test pass' "${h2:0:9}")"
eq status "$(nxt)" "a comment for HEAD: status"
comments
awk '{ print } $0 == "## Implementation Log" { print "PR comment @ '"${h2:0:7}"'" }' "$f9" > "$tmp/f9" && cat "$tmp/f9" > "$f9"
eq status "$(nxt)" "PR comment @ HEAD in the Log: status"
st set GT-000909 Status review:in-progress > /dev/null
prr GT-000909 > /dev/null 2>&1
eq 3 $? "not in the PR phase"
prr GT-999999 > /dev/null 2>&1
eq 1 $? "no such run"
git switch -q "$back"
git branch -q -D GT-000909-x
git remote remove origin
rm -rf .tixforge/GT-000909 "$tmp/origin.git" "$GH_DIR/prs.json" "$GH_DIR/pr-view.json"

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

# --- panel-data.sh ---------------------------------------------------------
section="panel-data.sh"
pd() { bash "$scripts/panel-data.sh" "$@"; }
out=$(cd "$tmp" && bash "$scripts/panel-data.sh" list)
eq 3 $? "outside a tixforge repository: exit 3"
eq "$(printf 'lang\tja\nerror\tnot-tixforge')" "$out" "outside a tixforge repository: says so, after the language"
# The labels the panel lists are label_defs' states, without the ends.
eq "$(sed -n '/^label_defs() {/,/^}/p' "$scripts/issue-label.sh" | grep -o 'tixforge:[a-z-]*' | grep -v -e done -e canceled -e out-of-sync | paste -sd' ' -)" \
  "$(sed -n 's/^PANEL_STATES="\(.*\)"$/\1/p' "$scripts/panel-data.sh")" "PANEL_STATES are label_defs' open states"
# Two PRs (one in conflict, one draft with checks running) and tickets in
# every order the panel sorts: mine, unassigned, others; a closed-state
# label and a plain issue are left out.
jq -n --argjson c "$run_check" '[
  {number: 7, title: "Fix\tit", url: "https://github.com/o/r/pull/7", state: "OPEN", isDraft: false, mergeable: "CONFLICTING", reviewDecision: "", latestReviews: [], statusCheckRollup: []},
  {number: 8, title: "Wip", url: "https://github.com/o/r/pull/8", state: "OPEN", isDraft: true, mergeable: "MERGEABLE", reviewDecision: "", latestReviews: [], statusCheckRollup: $c}
]' > "$GH_DIR/prs.json"
jq -n '[
  {number: 5, title: "Others", labels: [{name: "tixforge:in-progress"}], assignees: [{login: "ann"}, {login: "bob"}]},
  {number: 3, title: "Free", labels: [{name: "bug"}, {name: "tixforge:todo"}], assignees: []},
  {number: 9, title: "Mine", labels: [{name: "tixforge:in-review"}], assignees: [{login: "me"}]},
  {number: 1, title: "Done", labels: [{name: "tixforge:done"}], assignees: []},
  {number: 2, title: "Plain", labels: [], assignees: []}
]' > "$GH_DIR/issues.json"
out=$(pd list)
eq 0 $? "list: exit 0"
eq "$(printf 'lang\tja
me\tme
pr\t7\tconflict\t-\thttps://github.com/o/r/pull/7\tFix it
pr\t8\tpending\tdraft\thttps://github.com/o/r/pull/8\tWip
ticket\tGT-000009\tin-review\tme\tmine\tMine
ticket\tGT-000003\ttodo\t-\t-\tFree
ticket\tGT-000005\tin-progress\tann +1\t-\tOthers')" "$out" "list: PRs with pr-status's verdict, tickets mine / unassigned / others"
jq -n '[range(1; 33) | {number: ., title: "t", labels: [{name: "tixforge:todo"}], assignees: []}]' > "$GH_DIR/issues.json"
out=$(pd list)
eq 30 "$(printf '%s\n' "$out" | grep -c '^ticket')" "list: at most 30 tickets"
has "$(printf 'more\t2')" "$out" "list: says how many more"
eq "$(printf 'ticket\tGT-1234567\ttodo\t-\t-\tbig')" "$(
  jq -n '[{number: 1234567, title: "big", labels: [{name: "tixforge:todo"}], assignees: []}]' > "$GH_DIR/issues.json"
  pd list | grep '^ticket'
)" "list: a number past six digits is not cut"
rm -f "$GH_DIR/prs.json" "$GH_DIR/issues.json"
eq "$(printf 'lang\tja\nme\tme')" "$(pd list)" "list: nothing open"
# issue: the header, whether it can be started, and the ticket's body.
printf '## 背景\n本文\n' > "$tmp/pd-ticket.md"
issue 21 "Detail" "$tmp/pd-ticket.md" OPEN "" '[{"name":"tixforge:todo"}]'
body=$(bash "$scripts/issue-sync.sh" body "$tmp/pd-ticket.md" 2> /dev/null) || body=""
[ -n "$body" ] && jq --arg b "$body" '.body = $b | .number = 21' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
out=$(pd issue 21)
eq "$(printf 'issue\tGT-000021\ttodo\t-\tyes\tDetail')" "$(printf '%s\n' "$out" | sed -n 2p)" "issue: an unassigned todo can be started"
mkdir -p .tixforge/GT-000021 && printf '| Field | Value |\n|---|---|\n| Status | plan:in-progress |\n| Branch | — |\n' > .tixforge/GT-000021/state.md
has "$(printf '\tstarted\t')" "$(pd issue 21 | sed -n 2p)" "issue: a run of it open here is started"
rm -rf .tixforge/GT-000021
has "本文" "$out" "issue: the ticket's body"
case "$out" in *"tixforge:"*"-->"*) ng "issue: the markers are left out" ;; *) ok ;; esac
jq '.assignees = [{login: "ann"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tann\tassigned\t')" "$(pd issue GT-000021 | sed -n 2p)" "issue: someone else's todo"
jq '.assignees = [{login: "me"}, {login: "ann"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tme,ann\tyes\t')" "$(pd issue 21 | sed -n 2p)" "issue: a todo of mine"
jq '.labels = [{name: "tixforge:in-progress"}]' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '\tin-progress\tme,ann\tstarted\t')" "$(pd issue 21 | sed -n 2p)" "issue: started already"
printf 'no markers\n' > "$tmp/pd-plain.md"
issue 22 "Plain" "$tmp/pd-plain.md"
jq '.number = 22' "$GH_DIR/issue-22.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-22.json"
out=$(pd issue 22)
has "$(printf 'issue\tGT-000022\t-\t-\tstarted\tPlain')" "$out" "issue: no state label"
has "no markers" "$out" "issue: the whole body when tixforge did not write it"
# A blank line in the body stays; broken markers give the whole body once.
printf '## 背景\n\n段落\n' > "$tmp/pd-blank.md"
body=$(bash "$scripts/issue-sync.sh" body "$tmp/pd-blank.md" 2> /dev/null)
jq --arg b "$body" '.body = $b' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
has "$(printf '## 背景\n\n段落')" "$(pd issue 21)" "issue: blank lines in the body stay"
jq --arg b "$(printf '<!-- tixforge:ticket -->\n## 背景\nhalf\n')" '.body = $b' "$GH_DIR/issue-21.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-21.json"
eq 1 "$(pd issue 21 | grep -c half)" "issue: broken markers: the body once"
nogh="$tmp/panel-nogh"
mkdir -p "$nogh"
for t in bash git awk sed grep tr head cat dirname paste mktemp rm; do
  p=$(command -v "$t") && ln -sf "$p" "$nogh/$t"
done
out=$(PATH="$nogh" bash "$scripts/panel-data.sh" list)
eq 4 $? "no gh: exit 4"
has "$(printf 'error\tgh-missing')" "$out" "no gh: says so"
out=$(GH_FAIL_USER="HTTP 401: Bad credentials" bash "$scripts/panel-data.sh" list)
eq 4 $? "not signed in: exit 4"
has "$(printf 'error\tgh-auth\t')" "$out" "not signed in: says so"
out=$(GH_NO_AUTH=1 GH_FAIL_USER=offline bash "$scripts/panel-data.sh" list)
has "$(printf 'error\tgh\toffline')" "$out" "offline: not taken for signed out"
out=$(GH_FAIL_ISSUES=boom bash "$scripts/panel-data.sh" list)
eq "$(printf 'lang\tja\nerror\tgh\tboom')" "$out" "a list that fails half way: the error right after the language"
has "$(printf 'me\tm_e1')" "$(GH_LOGIN=m_e1 bash "$scripts/panel-data.sh" list)" "an EMU login (with _) is fine"
out=$(GH_LOGIN='a"b' bash "$scripts/panel-data.sh" list)
has "$(printf 'error\tgh\tunexpected login')" "$out" "a login that would break the jq is refused"

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
eq "$(printf 'format 2 -> 3\n- remove the placeholder comments (3)\n- add the Format row')" \
  "$(st migrate --check GT-000102)" "migrate --check lists the changes"
cmp -s "$tmp/v2-state.md" "$f2" && ok || ng "--check does not write"
eq implement:in-progress "$(st get GT-000102)" "a v2 file is read as it is"
eq "format 2 -> 3: $f2" "$(st migrate GT-000102)" "migrate"
eq 3 "$(st get GT-000102 Format)" "migrate writes the Format"
has "| Format  | 3" "$(grep -A1 '^| Updated' "$f2" | sed -n 2p)" "the Format row ends the header table"
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
eq "format 2 -> 3" "$(st migrate --check GT-000102 | sed -n 1p)" "a Format row in a section is not the format"
# All sections written: no placeholders to remove, so no line for them.
grep -v '^<!-- Phase' "$tmp/v2-state.md" > "$f2"
eq "$(printf 'format 2 -> 3\n- add the Format row')" "$(st migrate --check GT-000102)" \
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
sed 's/^| Format  | 3 /| Format  | 9 /' "$f2" > "$tmp/f9" && cat "$tmp/f9" > "$f2"
st migrate --check GT-000102 2> /dev/null
eq 5 $? "a newer format: update the plugin"
sed 's/^| Format  | 9 /| Format  | x /' "$f2" > "$tmp/f9" && cat "$tmp/f9" > "$f2"
st migrate GT-000102 2> /dev/null
eq 2 $? "a Format that is not a number"
rm -rf .tixforge/GT-000102

echo "scripts: $pass passed, $fail failed"
[ $fail -eq 0 ]
