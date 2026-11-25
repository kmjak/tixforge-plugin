#!/usr/bin/env bash
# Tests of templates/docs/ticket.md (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- templates/docs/ticket.md -----------------------------------------------
section="ticket template"
# The issue form asks for the same sections, in the same order, as the
# ticket template (Base is not in the form: it is set only when it differs).
tt=$(sed -n 's/^## //p' "$here/../templates/docs/ticket.md" | grep -v '^Base$' | paste -sd'|' -)
form=$(sed -n 's/^ *label: //p' "$here/../templates/github/ISSUE_TEMPLATE/tixforge-ticket.yml" | paste -sd'|' -)
eq "$tt" "$form" "the issue form's sections are the ticket template's"
eq "背景|要件|受け入れ条件|対象外|未決事項" "$tt" "the ticket template's sections"

done_file
