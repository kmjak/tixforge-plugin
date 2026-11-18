#!/usr/bin/env bash
# Write what the Review agents read, as files: the change of this run, the
# ticket, the agreed Approach and Plan, and the agents' common rules. The
# agents need no Bash (they stay read-only), and none of it passes through
# the implementing session's context.
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
#                (both without the "> " notes at their start and end: a
#                rewind note or an auto-passed gate is the implementer's
#                history, which the reviewers must not see)
#   index.md     the paths of these files, and then the common rules of the
#                reviewers (references/review.md); the agents read it first
# Prints the path of index.md. Writes nothing and exits 3 when there is no
# snapshot (dev takes it when the run starts), 4 when there is no state.md
# or its Approach or Plan is empty (the reviewers judge against them).
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
snap="$(tf_dir "$top")/$id/snapshot.md"
[ -f "$snap" ] || {
  echo "no snapshot: ${snap}（dev がチケットを取ってくると作られる）" >&2
  exit 3
}
state=$(state_file "$id" "$top")
[ -f "$state" ] || {
  echo "no run: ${state}（dev の run が無い）" >&2
  exit 4
}
# section_body <name>: a section of state.md without its heading, and
# without the blank lines and "> " notes at its start and end.
section_body() {
  awk -v want="$(section_index "$1")" "$_section_awk"'
    { h = heading_index($0) }
    h { on = (h == want); next }
    on { sub(/\r$/, ""); line[++n] = $0 }
    END {
      a = 1; while (a <= n && line[a] ~ /^([ \t]*$|>)/) a++
      b = n; while (b >= a && line[b] ~ /^([ \t]*$|>)/) b--
      for (i = a; i <= b; i++) print line[i]
    }
  ' "$state"
}
approach=$(section_body Approach)
plan=$(section_body Plan)
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
else
  rm -f "$dir/delta.patch"
fi
cp "$snap" "$dir/ticket.md"
printf '%s\n' "$approach" > "$dir/approach.md"
printf '%s\n' "$plan" > "$dir/plan.md"
{
  printf '# Review の入力：%s\n\n' "$id"
  for f in diff.patch log.txt files.txt delta.patch ticket.md approach.md plan.md; do
    if [ -f "$dir/$f" ]; then
      printf -- '- `%s`\n' "$dir/$f"
    else
      printf -- '- `%s`：無し（1 ラウンド目）\n' "$f"
    fi
  done
  echo
  # The rules from their first "## " on: the lines above are for maintainers.
  sed -n '/^## /,$p' "$(cd "$(dirname "$0")/.." && pwd)/references/review.md"
} > "$dir/index.md"
printf '%s\n' "$dir/index.md"
