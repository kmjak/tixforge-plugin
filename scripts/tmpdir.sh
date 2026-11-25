#!/usr/bin/env bash
# Folders for the temporary files of a skill (PR bodies, comments, drafts,
# reports for review.sh / checks.sh), inside the repository's git dir:
# <git dir>/tixforge/tmp/<name>. Inside the working tree's git dir, so
# Claude Code can write and remove them without asking each time, and git
# never tracks them.
#
#   tmpdir.sh new        make a fresh folder; prints its absolute path
#   tmpdir.sh rm <dir>   remove a folder that new made (refuses any other path)
#
# Exit: 0 ok, 2 usage or a path new did not make.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   tmpdir.sh' "$0" | sed 's/^#   //' >&2
  exit 2
}
top=$(tf_top)
base="$(git -C "$top" rev-parse --absolute-git-dir 2> /dev/null || echo "$top/.git")/tixforge/tmp"

case ${1:-} in
  new)
    [ $# -eq 1 ] || usage
    mkdir -p "$base" || exit 1
    mktemp -d "$base/t.XXXXXX"
    ;;
  rm)
    [ $# -eq 2 ] || usage
    case $2 in
      "$base"/t.?????? | "$base"/t.??????/) ;;
      *)
        echo "not a folder of tmpdir.sh: $2" >&2
        exit 2
        ;;
    esac
    rm -rf "${2%/}"
    ;;
  *) usage ;;
esac
