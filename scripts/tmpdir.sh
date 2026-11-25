#!/usr/bin/env bash
# Folders for the temporary files of a skill (PR bodies, comments, drafts,
# reports for review.sh / checks.sh): .tixforge/tmp/t.XXXXXX in the
# working tree. .tixforge/.gitignore keeps them out of git, the guard lets
# writes into .tixforge/ through in every state of a run, and a linked
# worktree has its own.
#
#   tmpdir.sh new        make a fresh folder; prints its absolute path
#   tmpdir.sh rm <dir>   remove a folder that new made (refuses any other path)
#
# Exit: 0 ok, 1 not in a git repository, 2 usage or a path new did not make.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   tmpdir.sh' "$0" | sed 's/^#   //' >&2
  exit 2
}
top=$(git rev-parse --show-toplevel 2> /dev/null) || {
  echo "not in a git repository" >&2
  exit 1
}
base="$(tf_dir "$top")/tmp"

case ${1:-} in
  new)
    [ $# -eq 1 ] || usage
    ensure_workspace "$top"
    mkdir -p "$base" || exit 1
    mktemp -d "$base/t.XXXXXX"
    ;;
  rm)
    [ $# -eq 2 ] || usage
    d=${2%/}
    name=${d#"$base"/}
    # Exactly one folder below base, named as new names them.
    case $d in "$base"/*) ;; *) name="" ;; esac
    case $name in t.??????) ;; *) name="" ;; esac
    case $name in */* | "")
      echo "not a folder of tmpdir.sh: $2" >&2
      exit 2
      ;;
    esac
    rm -rf "$d"
    ;;
  *) usage ;;
esac
