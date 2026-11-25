#!/usr/bin/env bash
# Tests of lib.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

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

done_file
