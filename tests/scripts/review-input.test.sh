#!/usr/bin/env bash
# Tests of review-input.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
run_901

# --- review-input.sh -------------------------------------------------------
section="review-input.sh"
git switch -q GT-000901-a
echo change > file.txt && git add file.txt && git commit -q -m change
# No snapshot yet: dev takes it when the run starts.
out=$(bash "$scripts/review-input.sh" GT-000901 main 2> /dev/null)
eq 3 $? "no snapshot: exit 3"
eq "" "$out" "no snapshot: nothing written or printed"
[ ! -e .git/tixforge/review/GT-000901 ] && ok || ng "no snapshot: no review folder"
printf '# GT-000901: A\n\n## 背景\nスナップショット\n' > .tixforge/GT-000901/snapshot.md
# The Approach and the Plan are what the reviewers judge against.
f1=.tixforge/GT-000901/state.md
cp "$f1" "$tmp/keep-state.md"
out=$(bash "$scripts/review-input.sh" GT-000901 main 2> /dev/null)
eq 4 $? "an empty Approach: exit 4"
[ ! -e .git/tixforge/review/GT-000901 ] && ok || ng "exit 4 writes nothing"
mv "$f1" "$tmp/away.md"
err=$(bash "$scripts/review-input.sh" GT-000901 main 2>&1 > /dev/null)
eq 4 $? "no state.md: exit 4"
has "no run:" "$err" "no state.md: says there is no run"
mv "$tmp/away.md" "$f1"
awk '$0 == "## Approach" { print; print "approach only"; next } { print }' "$tmp/keep-state.md" > "$f1"
err=$(bash "$scripts/review-input.sh" GT-000901 main 2>&1 > /dev/null)
eq 4 $? "an empty Plan: exit 4"
has "empty ## Plan" "$err" "an empty Plan: names it"
# The "> " notes at a section's start and end (a rewind, an auto-passed gate)
# are the implementer's history, not part of the agreement.
awk '$0 == "## Approach" { print; print "> [!NOTE]"; print "> approach body"; print "> quoted inside"; print "```"; print "## Plan"; print "```"; print "> Gate passed automatically (not in gates, nothing to stop for)"; next }
  $0 == "## Plan" { print; print "plan body"; print ""; next } { print }' "$tmp/keep-state.md" | sed 's/$/\r/' > "$f1"
idx=$(bash "$scripts/review-input.sh" GT-000901 main)
d=$(dirname "$idx")
has "/.git/tixforge/review/GT-000901/index.md" "$idx" "prints index.md, outside .tixforge"
has "+change" "$(cat "$d/diff.patch")" "diff"
has "スナップショット" "$(cat "$d/ticket.md")" "the ticket is the snapshot"
eq "$(printf '> [!NOTE]\n> approach body\n> quoted inside\n```\n## Plan\n```')" "$(cat "$d/approach.md")" "approach.md: the Approach body (CRLF, a fenced ## line and quotes kept, the auto-pass note dropped)"
eq "plan body" "$(cat "$d/plan.md")" "plan.md: the Plan body, without the blank lines around it"
has "\`delta.patch\`：無し" "$(cat "$idx")" "index.md: no delta.patch in round 1"
has "- \`$d/plan.md\`" "$(cat "$idx")" "index.md lists the files by absolute path"
has "## 受け取るもの" "$(cat "$idx")" "index.md carries references/review.md"
has "\`frontend.md\`：無し" "$(cat "$idx")" "index.md: no frontend.md without docs/context/frontend.md"
[ ! -e "$d/frontend.md" ] && ok || ng "no frontend.md copied without the design"
mkdir -p docs/context && printf '# フロントエンドの設計\n\n## Path: .\n' > docs/context/frontend.md
idx=$(bash "$scripts/review-input.sh" GT-000901 main)
has "- \`$d/frontend.md\`" "$(cat "$idx")" "index.md lists frontend.md when the project has one"
has "## Path: ." "$(cat "$d/frontend.md")" "frontend.md is docs/context/frontend.md"
rm -rf docs/context
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
[ ! -e "$d/frontend.md" ] && ok || ng "frontend.md removed when the design is gone"
case "$(cat "$idx")" in *"# Review の共通の規則"*) ng "index.md leaves out review.md's maintainer lines" ;; *) ok ;; esac
# --since writes the change after a given commit as delta.patch.
since=$(git rev-parse HEAD)
echo more > more.txt && git add more.txt && git commit -q -m more
idx=$(bash "$scripts/review-input.sh" GT-000901 main --since "$since")
delta="$d/delta.patch"
has "- \`$d/delta.patch\`" "$(cat "$idx")" "index.md: delta.patch from round 2"
has "+more" "$(cat "$delta")" "delta has the new change"
case "$(cat "$delta")" in *"+change"*) ng "delta has only the new change" ;; *) ok ;; esac
has "+change" "$(cat "$d/diff.patch")" "full diff still has everything"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
[ -f "$delta" ] && ng "delta removed without --since" || ok
has "\`delta.patch\`：無し" "$(cat "$idx")" "index.md: back to no delta.patch without --since"
bash "$scripts/review-input.sh" GT-000901 main --since nope 2> /dev/null
eq 2 $? "unknown --since commit"
# A real rewind note (run-state.sh) is dropped; a section with only notes is empty.
cp "$f1" "$tmp/keep-state2.md"
awk '$0 == "## Approach" { print; print "approach body"; next } $0 == "## Plan" { print; print "plan body"; next } { print }' "$tmp/keep-state.md" > "$f1"
st set GT-000901 Status review:in-progress > /dev/null
st rewind GT-000901 plan --reason "Review R2" > /dev/null
awk '$0 == "## Plan" { print; getline; print; print ""; print "new plan"; next } { print }' "$f1" > "$tmp/s1" && cat "$tmp/s1" > "$f1"
has "> 巻き戻し（" "$(cat "$f1")" "the rewind left its note"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
eq "new plan" "$(cat "$d/plan.md")" "plan.md: the rewind note is dropped"
awk '$0 == "## Plan" { print; getline; print; skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$f1" > "$tmp/s1" && cat "$tmp/s1" > "$f1"
bash "$scripts/review-input.sh" GT-000901 main > /dev/null 2>&1
eq 4 $? "a Plan with only the rewind note is empty: exit 4"
cp "$tmp/keep-state2.md" "$f1"
# A local base behind origin/<base>: others' commits there are not this run's.
git switch -q main
echo other > other.txt && git add other.txt && git commit -q -m other
git update-ref refs/remotes/origin/main HEAD
git reset -q --hard HEAD~1
git switch -q GT-000901-a
git merge -q --no-edit origin/main
bash "$scripts/review-input.sh" GT-000901 main > /dev/null
case "$(cat "$d/diff.patch")" in *"+other"*) ng "stale local base: others' commit excluded" ;; *) ok ;; esac
has "+change" "$(cat "$d/diff.patch")" "stale local base: own change kept"
cp "$tmp/keep-state.md" "$f1"
git update-ref -d refs/remotes/origin/main
git switch -q main

done_file
