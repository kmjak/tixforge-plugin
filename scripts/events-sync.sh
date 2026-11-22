#!/usr/bin/env bash
# Sends the event log (lib.sh event) to the team's endpoint, config.yml's
# events.endpoint, with this person's TIXFORGE_EVENTS_TOKEN (lib.sh
# events_sync_check). The local log stays the record: this only sends the
# lines not sent yet, and a failure loses nothing (the same lines go again
# next time; the endpoint drops an id it already has).
#
#   events-sync.sh status       whether it sends, sent / not sent lines, the last failure
#   events-sync.sh flush        send what is not sent yet, now
#   events-sync.sh bg <top>     what event starts in the background (quiet)
#
# POST <events.endpoint>, Content-Type: application/json, Authorization:
# Bearer <token>, body {"repo":"<owner/repo>","events":[<lines as they are>]},
# at most BATCH lines a time; 2xx marks them sent, anything else (or no
# answer within the timeouts) leaves them for next time. Lines written
# before events had an id get one from their text (md5, the same every
# time), so sending them again is still one event; a line that is not a
# JSON object (a write cut short) is passed over.
#
# Next to the log: <log>.sent (how many lines are sent), <log>.sync-error
# (the last failure: time and HTTP status or curl's exit code; removed after
# a success) and <log>.lock (a mkdir lock, so two senders never run at once;
# one older than 2 minutes is a sender that died). The token goes to curl on
# its stdin (not in ps) and is never written anywhere.
#
# Exit: 0 ok (flush: nothing left), 1 sending failed (flush), 2 usage,
#       3 sending is off (flush; status prints why), 4 another sender runs (flush).
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
. "$here/lib.sh"

BATCH=${TIXFORGE_EVENTS_BATCH:-500}

usage() {
  grep '^#   events-sync' "$0" | sed 's/^#   //' >&2
  exit 2
}

cmd=${1:-}
case $cmd in
  status | flush) top=$(tf_top) ;;
  bg)
    [ $# -eq 2 ] || usage
    top=$2
    ;;
  *) usage ;;
esac
log=$(tf_events "$top")
sent_f="$log.sent"
err_f="$log.sync-error"
lock="$log.lock"

lines() { if [ -f "$log" ]; then wc -l < "$log" | tr -d ' '; else echo 0; fi; }
# sent: the lines already sent; 0 when the record is missing, not a number,
# or more than the log has (the log was replaced: send it again).
sent() {
  local n total
  n=$(cat "$sent_f" 2> /dev/null)
  case $n in '' | *[!0-9]*) n=0 ;; esac
  total=$(lines)
  [ "$n" -gt "$total" ] && n=0
  echo "$n"
}

md5_hex() {
  if command -v md5sum > /dev/null 2>&1; then
    printf '%s' "$1" | md5sum | cut -c1-32
  elif command -v md5 > /dev/null 2>&1; then
    printf '%s' "$1" | md5 -q
  else
    return 1
  fi
}

# batch <from> <body-file>: write the body for lines from+1..from+BATCH and
# print how many lines it covered (passed-over lines included).
batch() {
  local from=$1 out=$2 n=0 first=1 l h
  printf '{"repo":%s,"events":[' "$(json_str "$ES_REPO")" > "$out"
  while IFS= read -r l; do
    n=$((n + 1))
    l=${l%$'\r'}
    case $l in '{'*'}') ;; *) continue ;; esac
    case $l in
      *'"id":"'*) ;;
      *)
        h=$(md5_hex "$l") || continue
        l="{\"id\":\"${h:0:8}-${h:8:4}-3${h:13:3}-$(printf '%x' $(((0x${h:16:1} & 3) | 8)))${h:17:3}-${h:20:12}\",${l#\{}"
        ;;
    esac
    [ -n "$first" ] || printf ',' >> "$out"
    first=""
    printf '%s' "$l" >> "$out"
  done << EOF
$(awk -v s="$from" -v b="$BATCH" 'NR > s && NR <= s + b' "$log")
EOF
  printf ']}\n' >> "$out"
  echo "$n"
}

# post <body-file>: the HTTP status, 000 when there was no answer.
post() {
  local tok=${TIXFORGE_EVENTS_TOKEN//\\/\\\\}
  tok=${tok//\"/\\\"}
  printf 'header = "Authorization: Bearer %s"\n' "$tok" \
    | curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 \
      -X POST -H 'Content-Type: application/json' -K - --data-binary "@$1" "$ES_ENDPOINT" 2> /dev/null
}

lock() {
  mkdir "$lock" 2> /dev/null && return 0
  [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2> /dev/null)" ] || return 1
  rmdir "$lock" 2> /dev/null
  mkdir "$lock" 2> /dev/null
}

# send_all: send batches until nothing is left (0) or one fails (1).
send_all() {
  local from n code body tmp
  body=$(mktemp) || return 1
  while :; do
    from=$(sent)
    [ "$from" -lt "$(lines)" ] || break
    n=$(batch "$from" "$body")
    code=$(post "$body")
    case $code in
      2??)
        tmp=$(mktemp "$sent_f.XXXXXX") && echo $((from + n)) > "$tmp" && mv "$tmp" "$sent_f"
        rm -f "$err_f"
        ;;
      *)
        if [ "$code" = 000 ] || [ -z "$code" ]; then
          printf '%s 応答なし（接続できない・タイムアウト）\n' "$(tf_stamp)" > "$err_f"
        else
          printf '%s HTTP %s\n' "$(tf_stamp)" "$code" > "$err_f"
        fi
        rm -f "$body"
        return 1
        ;;
    esac
  done
  rm -f "$body"
  return 0
}

case $cmd in
  status)
    if events_sync_check "$top"; then echo "events_sync=on（$ES_REPO → ${ES_ENDPOINT}）"; else echo "events_sync=off（${ES_REASON}）"; fi
    echo "log: $log"
    s=$(sent)
    echo "sent: $s"
    echo "unsent: $(($(lines) - s))"
    [ -f "$err_f" ] && echo "last error: $(cat "$err_f")"
    exit 0
    ;;
  flush)
    events_sync_check "$top" || {
      echo "events_sync=off（${ES_REASON}）" >&2
      exit 3
    }
    lock || {
      echo "another sender is running ($lock)" >&2
      exit 4
    }
    trap 'rmdir "$lock" 2> /dev/null' EXIT
    send_all
    rc=$?
    s=$(sent)
    echo "sent: $s, unsent: $(($(lines) - s))"
    [ $rc -eq 0 ] || echo "failed: $(cat "$err_f" 2> /dev/null)" >&2
    exit $rc
    ;;
  bg)
    events_sync_check "$top" || exit 0
    # A line written while the lock was held is picked up by the holder's
    # next round, or by trying again here once it is free.
    for _ in 1 2 3; do
      if lock; then
        send_all
        rc=$?
        rmdir "$lock" 2> /dev/null
        [ $rc -eq 0 ] || exit 0
      fi
      [ "$(sent)" -lt "$(lines)" ] || exit 0
      sleep 1
    done
    exit 0
    ;;
esac
