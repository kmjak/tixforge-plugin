#!/usr/bin/env bash
# Tests of verify.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

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

done_file
