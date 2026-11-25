#!/usr/bin/env bash
# Tests of github-preflight.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

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

done_file
