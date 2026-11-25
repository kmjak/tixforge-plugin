#!/usr/bin/env bash
# Tests of all scripts (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- all scripts ------------------------------------------------------------
# "$var（" makes bash read the first byte of a multibyte character as part of
# the name (unbound variable under set -u, depending on the locale). Write
# ${var} before non-ASCII text.
section="all scripts"
bad=$(LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$scripts"/*.sh || true)
eq "" "$bad" "no \$var directly followed by a non-ASCII character"

done_file
