#!/usr/bin/env bash
# Tests of branch.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

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

done_file
