#!/usr/bin/env bash
# Write what the Review agents read: the change of this run, as files, so
# the agents need no Bash (they stay read-only) and the diff does not pass
# through the implementing session's context.
#
#   review-input.sh <id> <base> [--since <commit>]
#
# The change is measured from the fork point of HEAD and the base. When
# origin/<base> exists and forks later than the local <base> (the local one
# is behind), origin/<base> is used, so commits other people pushed to the
# base are not counted as part of this run. A local <base> that is ahead of
# origin (unpushed merges) is used as is.
#
# Files go under <git dir>/tixforge/review/<id>/ (outside .tixforge/, which the
# reviewers must not read) and are replaced on every call:
#   diff.patch   git diff <fork point>..HEAD
#   log.txt      git log --stat <fork point>..HEAD
#   files.txt    git diff --name-status <fork point>..HEAD
#   delta.patch  git diff <commit>..HEAD (only with --since: the change since
#                the previous review round; removed otherwise)
#   ticket.md    the ticket as dev took it (.tixforge/<id>/snapshot.md)
#   approach.md  the body of ## Approach in .tixforge/<id>/state.md
#   plan.md      the body of ## Plan in .tixforge/<id>/state.md
#   index.md     this folder, whether delta.patch is there, and then the
#                common rules of the reviewers (references/review.md); the
#                agents read it first
# Prints the path of index.md. Exit 3, writing nothing, when there is no
# snapshot (dev takes it when the run starts); exit 4 when state.md has no
# Approach or Plan (the reviewers judge against them).
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: review-input.sh <id> <base> [--since <commit>]" >&2
  exit 2
}
[ $# -eq 2 ] || [ $# -eq 4 ] || usage
id=$1 base=$2 since=""
if [ $# -eq 4 ]; then
  [ "$3" = --since ] || usage
  since=$4
  git rev-parse --verify -q "$since^{commit}" > /dev/null || {
    echo "unknown commit: $since" >&2
    exit 2
  }
fi

git rev-parse --verify -q "$base" > /dev/null || {
  echo "unknown base: $base" >&2
  exit 2
}
fork=$(git merge-base "$base" HEAD)
remote="refs/remotes/origin/${base#origin/}"
if git rev-parse --verify -q "$remote" > /dev/null; then
  rfork=$(git merge-base "$remote" HEAD)
  # The later of the two fork points: the other one is its ancestor.
  if [ "$rfork" != "$fork" ] && git merge-base --is-ancestor "$fork" "$rfork"; then
    fork=$rfork
  fi
fi

top=$(git rev-parse --show-toplevel)
snap="$top/.tixforge/$id/snapshot.md"
[ -f "$snap" ] || {
  echo "no snapshot: ${snap}（dev がチケットを取ってくると作られる）" >&2
  exit 3
}
state="$top/.tixforge/$id/state.md"
# section_body <n>: section n of state.md (STATE_SECTIONS), without the
# heading and the blank lines around it.
section_body() {
  [ -f "$state" ] || return 0
  awk -v want="$1" "$_section_awk"'
    { h = heading_index($0) }
    h { on = (h == want); next }
    on { sub(/\r$/, ""); if ($0 ~ /^[ \t]*$/) { if (n) blank++ ; next } while (blank) { print ""; blank-- } print; n++ }
  ' "$state"
}
approach=$(section_body 2)
plan=$(section_body 3)
for s in "Approach:$approach" "Plan:$plan"; do
  [ -n "${s#*:}" ] || {
    echo "empty ## ${s%%:*} in ${state}（Review は合意済みの Approach と Plan と突き合わせる）" >&2
    exit 4
  }
done

dir="$(git rev-parse --absolute-git-dir)/tixforge/review/$id"
mkdir -p "$dir"
git diff "$fork"..HEAD > "$dir/diff.patch"
git log --stat "$fork"..HEAD > "$dir/log.txt"
git diff --name-status "$fork"..HEAD > "$dir/files.txt"
if [ -n "$since" ]; then
  git diff "$since"..HEAD > "$dir/delta.patch"
  delta="あり（2 ラウンド目以降）"
else
  rm -f "$dir/delta.patch"
  delta="無し（1 ラウンド目）"
fi
cp "$snap" "$dir/ticket.md"
printf '%s\n' "$approach" > "$dir/approach.md"
printf '%s\n' "$plan" > "$dir/plan.md"
{
  printf '# Review の入力：%s\n\n' "$id"
  printf -- '- このディレクトリ：`%s`\n' "$dir"
  printf -- '- `delta.patch`：%s\n\n' "$delta"
  cat "$(cd "$(dirname "$0")/.." && pwd)/references/review.md"
} > "$dir/index.md"
printf '%s\n' "$dir/index.md"
