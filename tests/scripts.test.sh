#!/usr/bin/env bash
# Tests for the tixforge scripts other than guard.sh: runs every
# tests/scripts/*.test.sh (one per script, each on its own temporary
# repository; tests/scripts/lib.sh sets up) in parallel with this bash, and
# prints the failures and the total. gh is replaced by a stub that serves
# fixture JSON (through jq, as gh --jq would) and records edits.
#
# Usage: bash tests/scripts.test.sh [<name> ...]   (names: tests/scripts/<name>.test.sh)
#        (also run it with /bin/bash on macOS for 3.2)
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

if [ $# -gt 0 ]; then
  files=""
  for n in "$@"; do files="$files $here/scripts/$n.test.sh"; done
else
  files=$(ls "$here"/scripts/*.test.sh)
fi
for f in $files; do
  n=$(basename "$f" .test.sh)
  (
    cd "$here/.." && "$BASH" "$f" > "$out/$n.log" 2>&1
    echo $? > "$out/$n.status"
  ) &
done
wait

pass=0 fail=0 bad=""
for f in $files; do
  n=$(basename "$f" .test.sh)
  grep -v '^scripts/' "$out/$n.log"
  line=$(grep "^scripts/$n: " "$out/$n.log" | tail -1)
  p=$(printf '%s' "$line" | sed -n 's/.*: \([0-9]*\) passed.*/\1/p')
  q=$(printf '%s' "$line" | sed -n 's/.*passed, \([0-9]*\) failed.*/\1/p')
  if [ -z "$line" ] || [ "$(cat "$out/$n.status")" != 0 ]; then
    bad="$bad $n"
    [ -n "$line" ] || echo "FAIL  [$n] stopped before its summary (exit $(cat "$out/$n.status"))"
  fi
  pass=$((pass + ${p:-0}))
  fail=$((fail + ${q:-0}))
done
[ -z "$bad" ] || echo "failed files:$bad"
echo "scripts: $pass passed, $fail failed"
[ -z "$bad" ] && [ "$fail" -eq 0 ]
