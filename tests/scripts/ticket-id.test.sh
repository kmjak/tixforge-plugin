#!/usr/bin/env bash
# Tests of ticket-id.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

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

done_file
