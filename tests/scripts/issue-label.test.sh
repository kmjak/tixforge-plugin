#!/usr/bin/env bash
# Tests of issue-label.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
use_gh_stub
printf '## 背景\nx\n' > "$tmp/body42"
issue 42 "ログイン" "$tmp/body42"

# --- issue-label.sh --------------------------------------------------------
section="issue-label.sh"
il() { bash "$scripts/issue-label.sh" "$@"; }
jq '.labels = [{"name":"tixforge:todo"},{"name":"bug"}] | .assignees = []' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
: > "$GH_DIR/calls"
has "tixforge:in-progress" "$(il 42 start)" "start"
has "--remove-label tixforge:todo --add-label tixforge:in-progress --add-assignee @me" "$(tail -1 "$GH_DIR/calls")" "start edits"
jq '.assignees = [{"login":"someone"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 start 2> /dev/null
eq 4 $? "someone else is assigned"
il 42 start --force > /dev/null
eq 0 $? "start --force"
jq '.assignees = [{"login":"me"}] | .labels = [{"name":"tixforge:in-review"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 reset > /dev/null
has "--remove-label tixforge:in-review --add-label tixforge:todo --remove-assignee @me" "$(tail -1 "$GH_DIR/calls")" "reset edits"
jq '.state = "CLOSED"' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 review 2> /dev/null
eq 3 $? "closed issue"
jq '.labels = [{"name":"tixforge:in-review"},{"name":"tixforge:out-of-sync"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 done > /dev/null
eq 0 $? "done applies to a closed issue"
has "--remove-label tixforge:in-review --add-label tixforge:done" "$(tail -1 "$GH_DIR/calls")" "done: one status label, out-of-sync kept"
il 42 canceled > /dev/null
eq 0 $? "canceled applies to a closed issue"
il 42 merged > /dev/null
has "--add-label tixforge:merged" "$(tail -1 "$GH_DIR/calls")" "merged"
il 42 done --force 2> /dev/null
eq 2 $? "--force is only for start"
printf 'tixforge:todo\nbug\n' > "$GH_DIR/labels"
out=$(il setup --dry-run)
has "$(printf 'tixforge:in-progress\tdev を進めている（assignee が担当）')" "$out" "setup --dry-run lists a missing label with its description"
case "$out" in *tixforge:todo*) ng "setup --dry-run skips an existing label" ;; *) ok ;; esac
eq "tixforge:todo
bug" "$(cat "$GH_DIR/labels")" "setup --dry-run creates nothing"
has "$(printf 'tixforge:in-progress\tBeing developed')" "$(il setup --dry-run --lang en)" "setup --lang en describes in English (init runs it before config.yml has a language)"
cp .tixforge/config.yml "$tmp/keep-lang.yml"
printf 'language: ja\n' > .tixforge/config.yml
has "$(printf 'tixforge:in-progress\tBeing developed')" "$(il setup --dry-run --lang en)" "--lang wins over config.yml's language"
has "$(printf 'tixforge:in-progress\tdev を進めている')" "$(MSG_LANG=en il setup --dry-run)" "an unrelated MSG_LANG in the environment changes nothing"
cp "$tmp/keep-lang.yml" .tixforge/config.yml
il setup --lang 2> /dev/null
eq 2 $? "setup --lang needs a value"
out=$(il setup)
has "tixforge:in-progress" "$out" "setup creates the missing labels"
case "$out" in *"tixforge:todo "* | *"tixforge:todo") ng "setup skips an existing label" ;; *) ok ;; esac
eq "labels: all present" "$(il setup)" "setup again"
has "--description dev を進めている（assignee が担当）" "$(cat "$GH_DIR/calls")" "setup takes the description from messages.yml, in the document language"
# Every label is one of label_defs, with a description in each language,
# and every tixforge: label the Actions templates use is one of them.
defs=$(sed -n '/^label_defs() {/,/^}/p' "$scripts/issue-label.sh" | grep -o 'tixforge:[a-z-]*' | sort -u)
[ -n "$defs" ] && ok || ng "no labels found in label_defs"
for l in $defs; do
  k="label_$(printf '%s' "${l#tixforge:}" | tr '-' '_')"
  for lang in $(sed -n 's/^\([a-z][a-z_-]*\):$/\1/p' "$here/../templates/github/tixforge/messages.yml"); do
    eq 1 "$(awk -v l="$lang:" -v k="  $k: " '/^[a-z]/ { on = ($0 == l) } on && index($0, k) == 1 { n++ } END { print n + 0 }' "$here/../templates/github/tixforge/messages.yml")" "messages.yml has $k in $lang"
  done
done
for l in $(grep -oh 'tixforge:[a-z][a-z-]*' "$here"/../templates/github/*.yml "$here"/../templates/github/ISSUE_TEMPLATE/*.yml | sort -u); do
  case $l in tixforge:hash | tixforge:ticket | tixforge:project | tixforge:dev) continue ;; esac
  printf '%s\n' "$defs" | grep -qx "$l" && ok || ng "a template uses $l, which label_defs does not define"
done
for l in $(sed -n 's/^STATUS_LABELS="\(.*\)"/\1/p' "$scripts/issue-label.sh"); do
  printf '%s\n' "$defs" | grep -qx "$l" && ok || ng "STATUS_LABELS has $l, which label_defs does not define"
done

done_file
