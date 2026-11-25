#!/usr/bin/env bash
# Tests of tmpdir.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

section="tmpdir.sh"
td() { bash "$scripts/tmpdir.sh" "$@"; }
gd=$(git rev-parse --absolute-git-dir)
d1=$(td new)
case $d1 in "$gd"/tixforge/tmp/t.??????) ok ;; *) ng "new: a folder under the git dir ($d1)" ;; esac
[ -d "$d1" ] && ok || ng "new: the folder exists"
d2=$(td new)
[ "$d1" != "$d2" ] && ok || ng "new: a fresh folder each time"
eq "" "$(git status --porcelain)" "new: git does not see it"
echo x > "$d1/body.md"
td rm "$d1"
[ ! -e "$d1" ] && ok || ng "rm: the folder is gone"
td rm "$tmp" > /dev/null 2>&1
eq 2 $? "rm: refuses a path new did not make"
[ -d "$tmp" ] && ok || ng "rm: and leaves it"
td rm "$gd/tixforge/tmp" > /dev/null 2>&1
eq 2 $? "rm: refuses the parent"
td rm "$d2/" > /dev/null
[ ! -e "$d2" ] && ok || ng "rm: a trailing slash is fine"
(cd "$tmp" && bash "$scripts/tmpdir.sh" new > /dev/null 2>&1)
td bad > /dev/null 2>&1
eq 2 $? "usage"

done_file
