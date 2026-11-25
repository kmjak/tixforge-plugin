#!/usr/bin/env bash
# Tests of issue-sync.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub

# --- issue-sync.sh ---------------------------------------------------------
section="issue-sync.sh"
is() { bash "$scripts/issue-sync.sh" "$@"; }
cat > "$tmp/draft.md" << 'EOF'
# <ticket-id>: ログイン

## 背景
ログインしたい

## 受け入れ条件
- [ ] ログインできる
EOF
is body "$tmp/draft.md" > "$tmp/body42"
issue 42 "ログイン" "$tmp/body42" # what gh issue create makes
out=$(is create "$tmp/draft.md")
has "number: 42" "$out" "create prints the number"
has "id: GT-000042" "$out" "create prints the id"
has "--label tixforge:todo" "$(cat "$GH_DIR/calls")" "create labels tixforge:todo"
{
  printf '<!--\nheader\n-->\n'
  cat "$tmp/draft.md"
} > "$tmp/draft-header.md"
is create "$tmp/draft-header.md" > /dev/null 2>&1
eq 2 $? "create refuses a draft whose first line is not the title"
[ ! -e .tixforge/GT-000042 ] && ok || ng "create makes no local copy (dev takes the snapshot)"
mkdir -p .tixforge/GT-000042
is create "$tmp/draft.md" > /dev/null 2>&1
eq 6 $? "create reports an existing ticket folder"
rm -rf .tixforge/GT-000042
has "<!-- tixforge:ticket:start -->" "$(cat "$tmp/body42")" "body has markers"
has "この issue の本文は" "$(cat "$tmp/body42")" "notice in the document language"
issue 42 "ログイン" "$tmp/body42"
eq in-sync "$(is check 42 | sed -n 1p)" "fresh issue is in sync"
eq issue "$(tid exists GT-000042)" "exists: an issue"
jq -n '{title: "a PR", pull_request: {}}' > "$GH_DIR/issue-60.json"
eq pull-request "$(tid exists '#60')" "exists: the number is a pull request"
tid exists GT-000061 > /dev/null
eq 1 $? "exists: no such issue"
cp .tixforge/config.yml "$tmp/keep-lang.yml"
sed 's/^language: ja.*/language: en/' "$tmp/keep-lang.yml" > .tixforge/config.yml
has "This issue body is synced" "$(is body "$tmp/draft.md")" "notice in English"
sed 's/^language: ja.*/language: fr/' "$tmp/keep-lang.yml" > .tixforge/config.yml
has "This issue body is synced" "$(is body "$tmp/draft.md")" "a language without messages falls back to English"
cp "$tmp/keep-lang.yml" .tixforge/config.yml

out=$(is pull 42 .tixforge/GT-000042/ticket.md)
has "created" "$out" "pull creates the working copy"
eq "# GT-000042: ログイン" "$(sed -n 1p .tixforge/GT-000042/ticket.md)" "title line"
eq 0 "$(grep -c '^Issue:' .tixforge/GT-000042/ticket.md)" "no Issue line: the id carries the number"
eq "$(
  ticket_body() { awk '/^## / { on = 1 } on' "$1"; }
  ticket_body "$tmp/draft.md"
)" \
  "$(awk '/^## / { on = 1 } on' .tixforge/GT-000042/ticket.md)" "ticket copied verbatim"
has "unchanged" "$(is pull 42 .tixforge/GT-000042/ticket.md)" "pull again"

# Edited on GitHub: the hash no longer matches.
sed 's/ログインしたい/ログインしたい（直接編集）/' "$tmp/body42" > "$tmp/edited"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"tixforge:out-of-sync"}]'
eq edited "$(is check 42 | sed -n 1p)" "direct edit detected"
eq "remote: changed" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^remote:')" "remote: a direct edit counts as a change"
eq "base: same" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^base:')" "base: the copy itself is untouched"
issue 42 "ログイン（改）" "$tmp/body42"
eq edited "$(is check 42 | sed -n 1p)" "direct title edit detected"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"tixforge:out-of-sync"}]'
is pull 42 .tixforge/GT-000042/ticket.md > /dev/null 2>&1
eq 4 $? "pull refuses an edited issue"
before=$(cat .tixforge/GT-000042/ticket.md)
is pull 42 .tixforge/GT-000042/ticket.md --accept-edited --dry-run | grep -q '直接編集' && ok || ng "dry run shows the diff"
eq "$before" "$(cat .tixforge/GT-000042/ticket.md)" "dry run does not write"
is pull 42 .tixforge/GT-000042/ticket.md --accept-edited | grep -q '直接編集' && ok || ng "pull --accept-edited shows the diff"
is push 42 .tixforge/GT-000042/ticket.md > /dev/null 2>&1
eq 4 $? "push refuses an edited issue"
out=$(is push 42 .tixforge/GT-000042/ticket.md --force)
has "updated" "$out" "push --force rehashes"
has "removed label: tixforge:out-of-sync" "$out" "push removes out-of-sync"
eq "base: same remote: same" "$(is check 42 .tixforge/GT-000042/ticket.md | grep '^base:\|^remote:' | paste -sd' ' -)" "after --accept-edited and push --force: same, same"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after adopting"

# Local edit (/tixforge:ticket edit) then push.
sed 's/ログインできる/ログインできる\n- [ ] ログアウトできる/' .tixforge/GT-000042/ticket.md > "$tmp/t" && cat "$tmp/t" > .tixforge/GT-000042/ticket.md
has "updated" "$(is push 42 .tixforge/GT-000042/ticket.md)" "push a local edit"
has "ログアウトできる" "$(jq -r .body "$GH_DIR/issue-42.json")" "issue has the edit"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after push"
has "unchanged" "$(is push 42 .tixforge/GT-000042/ticket.md)" "push again"

# Markers removed on GitHub.
printf 'just text\n' > "$tmp/nomark"
issue 43 "x" "$tmp/nomark"
eq no-markers "$(is check 43 | sed -n 1p)" "no markers"
is pull 43 .tixforge/GT-000043/ticket.md > /dev/null 2>&1
eq 3 $? "pull without markers"

# An issue made before hashes.
grep -v 'tixforge:hash' "$tmp/body42" > "$tmp/nohash"
issue 44 "ログイン" "$tmp/nohash"
eq no-hash "$(is check 44 | sed -n 1p)" "no hash"
has "created" "$(is pull 44 .tixforge/GT-000044/ticket.md)" "pull an issue without a hash"
eq "base: same remote: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:\|^remote:' | paste -sd' ' -)" "no hash line in the body: base and remote still work"
tr -d '\r' < .tixforge/GT-000044/ticket.md | sed 's/$/\r/' > "$tmp/crlf44" && cp "$tmp/crlf44" .tixforge/GT-000044/ticket.md
eq "base: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:')" "base: CRLF is not a change"
# With no hash line in the body, a direct edit is caught by the lock.
is pull 44 .tixforge/GT-000044/ticket.md > /dev/null
sed 's/ログインできる/直接の変更/' "$tmp/nohash" > "$tmp/nohash2"
issue 44 "ログイン" "$tmp/nohash2"
sed 's/ログインしたい/私の変更/' .tixforge/GT-000044/ticket.md > "$tmp/mine44" && cp "$tmp/mine44" .tixforge/GT-000044/ticket.md
is push 44 .tixforge/GT-000044/ticket.md > /dev/null 2>&1
eq 5 $? "no hash line: push refuses after a direct edit"
# Text before the first ## in the body: not a change of the copy.
awk '{ print } /tixforge:ticket:start/ { print "前置き" }' "$tmp/nohash" > "$tmp/intro44"
issue 44 "ログイン" "$tmp/intro44"
rm -f .tixforge/GT-000044/ticket.md .tixforge/GT-000044/.ticket.md.hash
is pull 44 .tixforge/GT-000044/ticket.md > /dev/null
eq "base: same" "$(is check 44 .tixforge/GT-000044/ticket.md | grep '^base:')" "base: text before the first ## is not a change"

# Canceled issue: Status / Reason come back.
sed '1s/.*/# <ticket-id>: やめた/' "$tmp/draft.md" > "$tmp/draft45"
is body "$tmp/draft45" > "$tmp/body45"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
jq '.comments = [{"body":"Canceled by tixforge: 優先度が下がった"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by tixforge (comment)"
# v3 writes an invisible mark, then the document language.
jq '.comments = [{"body":"<!-- tixforge:canceled -->\nキャンセル：優先度が下がった"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by tixforge (the mark)"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.comments = [{"body":"<!-- tixforge:closed -->\nhttps://github.com/o/r/pull/3 のマージで完了"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by tixforge (the mark)"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
jq '.comments = [{"body":"<!-- tixforge:closed -->\n完了"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: unexpected" "$(is check 45 | sed -n 2p)" "the closed mark on an issue closed as not planned is not a cancel"
# markc <reason> <comments-json>: closed_as for #45 closed with them.
markc() {
  issue 45 "やめた" "$tmp/body45" CLOSED "$1"
  jq --argjson c "$2" '.comments = $c' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
  is check 45 | sed -n 2p
}
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"<!-- tixforge:canceled -->\r\nキャンセル"}]')" "the mark with CRLF"
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"\n  <!-- tixforge:canceled -->\nキャンセル"}]')" "the mark after blank space"
eq "closed_as: unexpected" "$(markc NOT_PLANNED '[{"body":"何か\n<!-- tixforge:canceled -->"}]')" "the mark on a second line does not count"
eq "closed_as: unexpected" "$(markc COMPLETED '[{"body":"<!-- tixforge:canceled -->\nx"}]')" "the canceled mark on an issue closed as completed is not a close"
eq "closed_as: canceled" "$(markc NOT_PLANNED '[{"body":"thanks"},{"body":"<!-- tixforge:canceled -->\nx"}]')" "the mark in a later comment"
# v2 closed issues with English comments. GitHub comments are never
# migrated, so they keep being read (here with the labels taken off).
for c in "Closed by tixforge: https://github.com/o/r/pull/3 merged" "Closed by tixforge-issue-sync: https://github.com/o/r/pull/3 merged"; do
  issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
  jq --arg c "$c" '.comments = [{body: $c}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
  eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed with v2's comment: ${c%%:*}"
done
is pull 45 .tixforge/GT-000045/ticket.md > /dev/null
eq 0 "$(grep -c '^Status:' .tixforge/GT-000045/ticket.md)" "pull writes no Status line: the issue says it"
issue 45 "やめた" "$tmp/body45" OPEN ""
eq "closed_as: open" "$(is check 45 | sed -n 2p)" "reopened: open again"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED '[{"name":"tixforge:canceled"}]'
eq "closed_as: canceled" "$(is check 45 | sed -n 2p)" "canceled by label"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:in-review"}]'
eq "closed_as: unexpected" "$(is check 45 | sed -n 2p)" "closed by hand"
jq '.events = [{"event":"closed","commit_id":"abc123"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by a commit (Closes in a commit reaching the default branch)"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:merged"}]'
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "merged label"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.closedByPullRequestsReferences = [{"number":9}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq "closed_as: completed" "$(is check 45 | sed -n 2p)" "closed by a PR"
# status: the same, in the words the instruction files use.
st45() { is check 45 | sed -n 's/^status: //p'; }
eq completed "$(st45)" "status: completed"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED '[{"name":"tixforge:canceled"}]'
eq canceled "$(st45)" "status: canceled"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED '[{"name":"tixforge:in-review"}]'
eq closed-completed "$(st45)" "status: closed by hand as completed"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
eq closed-not-planned "$(st45)" "status: closed by hand as not planned"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-progress"}]'
eq open "$(st45)" "status: open"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-review"}]'
eq in-review "$(st45)" "status: in-review"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:merged"}]'
eq merged "$(st45)" "status: merged, waiting for the release"
issue 45 "やめた" "$tmp/body45" OPEN "" '[{"name":"tixforge:in-review"},{"name":"tixforge:merged"}]'
eq merged "$(st45)" "status: merged wins over in-review"
issue 45 "やめた" "$tmp/body45" CLOSED DUPLICATE
eq closed "$(st45)" "status: closed by hand with another reason"
issue 45 "やめた" "$tmp/body45" CLOSED COMPLETED
jq '.comments = [{"body":"Closed by tixforge: https://github.com/o/r/pull/3 merged"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
eq completed "$(st45)" "status: closed with v2's comment"

# Optimistic lock: someone else pushed after this copy was fetched.
issue 46 "ログイン" "$tmp/body42"
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
cp .tixforge/GT-000046/ticket.md "$tmp/mine46"
sed 's/ログインしたい/他の人の変更/' .tixforge/GT-000046/ticket.md > "$tmp/theirs46" && cp "$tmp/theirs46" .tixforge/GT-000046/ticket.md
is push 46 .tixforge/GT-000046/ticket.md > /dev/null # the other person's push (their copy is fresh)
cp "$tmp/mine46" .tixforge/GT-000046/ticket.md
bash "$scripts/ticket-hash.sh" stored < "$tmp/body42" > .tixforge/GT-000046/.ticket.md.hash # my copy came from the old version
sed 's/ログインできる/私の変更/' "$tmp/mine46" > .tixforge/GT-000046/ticket.md
is push 46 .tixforge/GT-000046/ticket.md > /dev/null 2>&1
eq 5 $? "push refuses: the issue changed since it was fetched"
has "他の人の変更" "$(jq -r .body "$GH_DIR/issue-46.json")" "the other person's change is kept"
eq "local: differs" "$(is check 46 .tixforge/GT-000046/ticket.md | sed -n 3p)" "check: the copy is not the last synced version"
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
eq "local: same" "$(is check 46 .tixforge/GT-000046/ticket.md | sed -n 3p)" "check: after pull the copy is the synced version"
eq "local: missing" "$(is check 46 "$tmp/none.md" | sed -n 3p)" "check: no copy"
# dev's snapshot and edit's editing.md keep their own hash: pulling the
# snapshot does not lift the lock of an edit fetched before it.
cp "$GH_DIR/issue-46.json" "$tmp/keep46"
is pull 46 .tixforge/GT-000046/editing.md > /dev/null
cp .tixforge/GT-000046/editing.md "$tmp/mine46b"
sed 's/他の人の変更/さらに別の人の変更/' .tixforge/GT-000046/editing.md > "$tmp/other46"
is push 46 "$tmp/other46" > /dev/null 2>&1 # another person's push from a fresh copy
is pull 46 .tixforge/GT-000046/snapshot.md > /dev/null
[ -f .tixforge/GT-000046/.snapshot.md.hash ] && [ -f .tixforge/GT-000046/.editing.md.hash ] && ok || ng "one hash file per copy"
sed 's/ログインできる/私の変更/' "$tmp/mine46b" > .tixforge/GT-000046/editing.md
is push 46 .tixforge/GT-000046/editing.md > /dev/null 2>&1
eq 5 $? "pulling the snapshot keeps the edit's lock"
has "さらに別の人の変更" "$(jq -r .body "$GH_DIR/issue-46.json")" "the other person's change is kept"
cp "$tmp/keep46" "$GH_DIR/issue-46.json"
rm -f .tixforge/GT-000046/editing.md .tixforge/GT-000046/.editing.md.hash .tixforge/GT-000046/snapshot.md .tixforge/GT-000046/.snapshot.md.hash
# v2's working copy becomes the snapshot, so a change made since shows.
is pull 46 .tixforge/GT-000046/ticket.md > /dev/null
sed 's/他の人の変更/v2 のときの内容/' .tixforge/GT-000046/ticket.md > "$tmp/v2t" && cp "$tmp/v2t" .tixforge/GT-000046/ticket.md
mv .tixforge/GT-000046/.ticket.md.hash .tixforge/GT-000046/.issue-hash
out=$(is pull 46 .tixforge/GT-000046/snapshot.md)
has "moved: " "$out" "v2's ticket.md moves to snapshot.md"
has "v2 のときの内容" "$out" "and the diff shows what changed since"
eq "base: same remote: same" "$(is check 46 .tixforge/GT-000046/snapshot.md | grep '^base:\|^remote:' | paste -sd' ' -)" "after the v2 move: same, same"
[ ! -e .tixforge/GT-000046/ticket.md ] && [ -f .tixforge/GT-000046/.snapshot.md.hash ] && [ ! -e .tixforge/GT-000046/.issue-hash ] && ok || ng "ticket.md and .issue-hash are moved"
rm -f .tixforge/GT-000046/snapshot.md .tixforge/GT-000046/.snapshot.md.hash
# The move only for a missing snapshot.md, never in a dry run or for
# editing.md.
printf '# GT-000046: v2\n\n## 背景\nv2\n' > .tixforge/GT-000046/ticket.md
out=$(is pull 46 .tixforge/GT-000046/snapshot.md --dry-run)
has "would move: " "$out" "dry run: the move is announced"
has "v2" "$out" "dry run: the diff is against v2's copy"
[ -f .tixforge/GT-000046/ticket.md ] && [ ! -e .tixforge/GT-000046/snapshot.md ] && ok || ng "dry run moves nothing"
is pull 46 .tixforge/GT-000046/editing.md > /dev/null
[ -f .tixforge/GT-000046/ticket.md ] && ok || ng "editing.md does not take v2's copy"
rm .tixforge/GT-000046/ticket.md
is pull 46 .tixforge/GT-000046/snapshot.md > /dev/null
printf '# GT-000046: v2\n' > .tixforge/GT-000046/ticket.md
has "unchanged: " "$(is pull 46 .tixforge/GT-000046/snapshot.md)" "an existing snapshot is kept"
[ -f .tixforge/GT-000046/ticket.md ] && ok || ng "an existing snapshot leaves v2's copy alone"
# base / remote: the copy and the issue against the version it was taken at.
f46=.tixforge/GT-000046/snapshot.md
eq "base: same" "$(is check 46 "$f46" | grep '^base:')" "base: same right after pull"
eq "remote: same" "$(is check 46 "$f46" | grep '^remote:')" "remote: same right after pull"
sed 's/ログインできる/書き戻していない変更/' "$f46" > "$tmp/b46" && cp "$tmp/b46" "$f46"
eq "base: changed" "$(is check 46 "$f46" | grep '^base:')" "base: changed after a local edit"
cp "$GH_DIR/issue-46.json" "$tmp/keep46"
{
  cat .tixforge/GT-000046/editing.md
  printf -- '- また誰かの変更\n'
} > "$tmp/someone46"
is push 46 "$tmp/someone46" > /dev/null 2>&1
eq "remote: changed" "$(is check 46 "$f46" | grep '^remote:')" "remote: changed after someone else's push"
eq "base: none" "$(is check 46 "$tmp/none.md" | grep '^base:')" "base: none without a copy"
cp "$tmp/keep46" "$GH_DIR/issue-46.json"
rm -f .tixforge/GT-000046/*.md .tixforge/GT-000046/.*.hash
eq "assignees: " "$(is check 46 | tail -1)" "check: no assignee"
jq '.assignees = [{"login":"me"},{"login":"someone"}]' "$GH_DIR/issue-46.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-46.json"
eq "assignees: me,someone" "$(is check 46 | tail -1)" "check: assignees on the last line"

# adopt: an issue written on GitHub (issue form), then written back keeping the original.
printf '### 背景\n\nフォームから\n\n### 要件\n\n- 何か\n\n### 未決事項\n\n_No response_\n' > "$tmp/form"
issue 47 "フォームの issue" "$tmp/form" OPEN "" '[{"name":"tixforge:todo"}]'
out=$(is adopt 47 .tixforge/GT-000047/ticket.md)
has "adopted" "$out" "adopt"
eq "# GT-000047: フォームの issue" "$(sed -n 1p .tixforge/GT-000047/ticket.md)" "adopt: title line"
has "## 背景" "$(cat .tixforge/GT-000047/ticket.md)" "adopt: ### becomes ##"
has "なし" "$(cat .tixforge/GT-000047/ticket.md)" "adopt: _No response_ becomes なし"
is adopt 42 "$tmp/x.md" 2> /dev/null
eq 2 $? "adopt refuses an issue tixforge wrote"
out=$(is push 47 .tixforge/GT-000047/ticket.md --force --keep-original)
has "commented: the original body" "$out" "keep-original comments first"
has "フォームから" "$(jq -r '.comments[0].body' "$GH_DIR/issue-47.json")" "the original body is in the comment"
eq in-sync "$(is check 47 | sed -n 1p)" "adopted issue is in sync"

done_file
