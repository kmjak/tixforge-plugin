#!/usr/bin/env bash
# Tests of tmpdir.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

section="tmpdir.sh"
td() { bash "$scripts/tmpdir.sh" "$@"; }
gd=$(git rev-parse --show-toplevel)/.tixforge
d1=$(td new)
case $d1 in "$gd"/tmp/t.??????) ok ;; *) ng "new: a folder under .tixforge/tmp ($d1)" ;; esac
[ -d "$d1" ] && ok || ng "new: the folder exists"
d2=$(td new)
[ "$d1" != "$d2" ] && ok || ng "new: a fresh folder each time"
eq "" "$(git status --porcelain --untracked-files=all | grep tmp/)" "new: git does not see it"
echo x > "$d1/body.md"
td rm "$d1"
[ ! -e "$d1" ] && ok || ng "rm: the folder is gone"
td rm "$tmp" > /dev/null 2>&1
eq 2 $? "rm: refuses a path new did not make"
[ -d "$tmp" ] && ok || ng "rm: and leaves it"
td rm "$gd/tmp" > /dev/null 2>&1
eq 2 $? "rm: refuses the parent"
td rm "$d2/" > /dev/null
[ ! -e "$d2" ] && ok || ng "rm: a trailing slash is fine"
mkdir -p "$d2" "$gd/tmp/t.abcdef/x"
td rm "$gd/tmp/t.abcdef/x" > /dev/null 2>&1
eq 2 $? "rm: refuses a path below a folder"
[ -d "$gd/tmp/t.abcdef/x" ] && ok || ng "rm: and leaves it"
mkdir -p "$tmp/notgit"
(cd "$tmp/notgit" && bash "$scripts/tmpdir.sh" new > /dev/null 2>&1)
eq 1 $? "new: refuses outside a git repository"
[ ! -e "$tmp/notgit/.tixforge" ] && ok || ng "new: and makes nothing there"
# The guard lets the folder through while a run waits before Plan approval.
st init GT-000950 > /dev/null
d3=$(td new)
out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/body.md"},"cwd":"%s"}' "$d3" "$(git rev-parse --show-toplevel)" | bash "$scripts/guard.sh")
case $out in *'"ask"'* | *'"deny"'*) ng "guard: a temporary file before Plan approval is not asked about" ;; *) ok ;; esac
rm -rf .tixforge/GT-000950
td bad > /dev/null 2>&1
eq 2 $? "usage"

done_file
