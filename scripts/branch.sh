#!/usr/bin/env bash
# The Base and the branch name of a /tixforge:dev run (phase/plan.md steps
# 1 and 2).
#
#   branch.sh base <ticket-id> [<branch the user named>]
#       base: <branch>
#       from: user | ticket | config | origin
#     The first that is set: the branch the user named in this Plan, the
#     ticket's "## Base" section (snapshot.md; its first line that is not
#     blank or an HTML comment), repository.base_branch, origin's default
#     branch (refs/remotes/origin/HEAD). Exit 3 (with base: and from:) when
#     origin has no such branch: ask which one.
#   branch.sh name <ticket-id> <slug>
#       name: <ticket-id>-<slug>[-N]
#     The run's branch. Keeps the run's Branch header when it is that name or
#     one of its -N; else the first of <id>-<slug>, -2, -3, ... that is
#     neither a local branch nor on origin (an old branch kept by a rewind).
#     Exit 2 when the slug is not lower-case letters, digits and hyphens.
#
# Exit: 0 ok, 1 no such run (name) / no Base found, 2 usage, 3 Base not on origin.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   branch.sh' "$0" | sed 's/^#   //' >&2
  exit 2
}
top=$(tf_top)

on_origin() { [ -n "$(git -C "$top" ls-remote --heads origin "refs/heads/$1" 2> /dev/null)" ]; }

case ${1:-} in
  base)
    [ $# -ge 2 ] && [ $# -le 3 ] || usage
    b=${3:-} from=user
    if [ -z "$b" ]; then
      from=ticket
      snap="$(tf_dir "$top")/$2/snapshot.md"
      [ -f "$snap" ] && b=$(awk '
        /^## / { on = ($0 ~ /^## Base[ \t]*$/); next }
        !on { next }
        /<!--/ { c = 1 }
        c { if (/-->/) c = 0; next }
        /[^ \t]/ { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }' "$snap")
    fi
    if [ -z "$b" ]; then
      from=config
      b=$(cfg repository.base_branch "$(tf_config "$top")")
    fi
    if [ -z "$b" ]; then
      from=origin
      b=$(git -C "$top" symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)
      b=${b#origin/}
    fi
    [ -n "$b" ] || {
      echo "no Base: name one" >&2
      exit 1
    }
    printf 'base: %s\nfrom: %s\n' "$b" "$from"
    on_origin "$b" || {
      echo "origin has no branch $b" >&2
      exit 3
    }
    ;;
  name)
    [ $# -eq 3 ] || usage
    id=$2 slug=$3
    case $slug in '' | *[!a-z0-9-]*)
      echo "slug: only a-z, 0-9 and -: $slug" >&2
      exit 2
      ;;
    esac
    f=$(state_file "$id" "$top")
    [ -f "$f" ] || {
      echo "no run: $id" >&2
      exit 1
    }
    want="$id-$slug"
    cur=$(field "$f" Branch)
    # The run's own Branch: the name, or the name with -<digits>.
    rest=${cur#"$want"}
    case $rest in "" | -[0-9]*)
      case ${rest#-} in *[!0-9]*) ;; *)
        printf 'name: %s\n' "$cur"
        exit 0
        ;;
      esac
      ;;
    esac
    n=1 name=$want
    while git -C "$top" show-ref --verify --quiet "refs/heads/$name" || on_origin "$name"; do
      n=$((n + 1))
      name="$want-$n"
    done
    printf 'name: %s\n' "$name"
    ;;
  *) usage ;;
esac
