#!/usr/bin/env bash
# Tests of ticket-hash.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

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

done_file
