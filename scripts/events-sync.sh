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
# answer within the timeouts) leaves them for next time.
#
# Only complete lines are read (a line still being written has no newline
# yet), and only lines that are one JSON object go (valid_awk). A write cut
# short has no newline, so the next event is joined to it: the event at the
# end of such a line goes alone, the cut part is dropped. Anything else
# that is not one JSON object, and blank lines, are passed over and counted
# as sent, so one bad line never makes every later request fail.
# Lines written before events had an id get one from their text and the
# number of identical lines before them (md5, or cksum without md5): the
# same every time, so sending them again is still one event, and two
# identical lines are two events. The log itself is never rewritten.
#
# Next to the log: <log>.sent (how many lines are sent; it only moves
# forward), <log>.sync-error (the last failure: time and HTTP status, or no
# answer; never the response body; removed after a success) and <log>.lock
# (a mkdir lock with its owner inside, so two senders do not run at once;
# the holder touches it every batch, and one untouched for 2 minutes is a
# sender that died). The token goes to curl on its stdin (not in ps) and is
# never written anywhere.
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
me="$$-$(new_uuid)"

# lines: the complete lines of the log (wc counts newlines; awk would also
# count a last line still being written).
lines() { if [ -f "$log" ]; then wc -l < "$log" | tr -d ' '; else echo 0; fi; }
read_sent() {
  local n
  n=$(cat "$sent_f" 2> /dev/null)
  case $n in '' | *[!0-9]*) n=0 ;; esac
  echo "$n"
}
# sent: the lines already sent; 0 when the record is more than the log has
# (the log was replaced: send it again, the ids fold it).
sent() {
  local n
  n=$(read_sent)
  [ "$n" -gt "$(lines)" ] && n=0
  echo "$n"
}
# mark_sent <n>: record n lines as sent, unless another sender got further.
mark_sent() {
  local tmp cur
  cur=$(read_sent)
  [ "$cur" -le "$(lines)" ] && [ "$cur" -ge "$1" ] && return 0
  tmp=$(mktemp "$sent_f.XXXXXX") || return 1
  echo "$1" > "$tmp" && mv "$tmp" "$sent_f"
}

# hex32 <text>: 32 hex digits from the text, the same every time.
hex32() {
  if command -v md5sum > /dev/null 2>&1; then
    printf '%s' "$1" | md5sum | cut -c1-32
  elif command -v md5 > /dev/null 2>&1; then
    printf '%s' "$1" | md5 -q
  else
    # cksum is POSIX: four CRCs of the text with different prefixes.
    local i out=""
    for i in a b c d; do
      out="$out$(printf '%s%s' "$i" "$1" | cksum | awk '{ printf "%08x", $1 }')"
    done
    printf '%s\n' "$out"
  fi
}

# valid_awk: valid(line) is 1 when the line is exactly one JSON object
# (strings, numbers, true / false / null, nested objects and arrays). Run
# in the C locale: it walks bytes, and UTF-8 inside strings passes. It uses
# the globals s, n and p: a program using it must not.
# shellcheck disable=SC2016 # awk code, not shell
valid_awk='
function ws() { while (p <= n && index(" \t", substr(s, p, 1))) p++ }
function jstr(   c) {
  if (substr(s, p, 1) != "\"") return 0
  p++
  while (p <= n) {
    c = substr(s, p, 1)
    if (c == "\\") { p += 2; continue }
    p++
    if (c == "\"") return 1
  }
  return 0
}
function jnum(   st) {
  st = p
  while (p <= n && index("-+.0123456789eE", substr(s, p, 1))) p++
  return p > st && substr(s, st, p - st) ~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/
}
function jlit(w) { if (substr(s, p, length(w)) == w) { p += length(w); return 1 } return 0 }
function jval(   c) {
  ws(); c = substr(s, p, 1)
  if (c == "{") return jobj()
  if (c == "[") return jarr()
  if (c == "\"") return jstr()
  if (c == "t") return jlit("true")
  if (c == "f") return jlit("false")
  if (c == "n") return jlit("null")
  return jnum()
}
function jobj(   c) {
  p++; ws()
  if (substr(s, p, 1) == "}") { p++; return 1 }
  while (1) {
    ws(); if (!jstr()) return 0
    ws(); if (substr(s, p, 1) != ":") return 0
    p++; if (!jval()) return 0
    ws(); c = substr(s, p, 1); p++
    if (c == "}") return 1
    if (c != ",") return 0
  }
}
function jarr(   c) {
  p++; ws()
  if (substr(s, p, 1) == "]") { p++; return 1 }
  while (1) {
    if (!jval()) return 0
    ws(); c = substr(s, p, 1); p++
    if (c == "]") return 1
    if (c != ",") return 0
  }
}
function valid(line) {
  s = line; n = length(s); p = 1
  ws()
  if (substr(s, p, 1) != "{" || !jobj()) return 0
  ws()
  return p > n
}
'

# batch <from> <body-file>: write the body for lines from+1..from+BATCH and
# print "<lines covered> <events in the body>".
batch() {
  local from=$1 out=$2 n=0 k=0 tag l h
  printf '{"repo":%s,"events":[' "$(json_str "$ES_REPO")" > "$out"
  while IFS="$(printf '\t')" read -r tag l; do
    [ -n "$tag" ] || continue
    n=$((n + 1))
    case $tag in
      ok) ;;
      bad) continue ;;
      *)
        # tag is the count of identical id-less lines up to this one.
        h=$(hex32 "$l
$tag")
        l="{\"id\":\"${h:0:8}-${h:8:4}-3${h:13:3}-$(printf '%x' $(((0x${h:16:1} & 3) | 8)))${h:17:3}-${h:20:12}\",${l#\{}"
        ;;
    esac
    [ $k -eq 0 ] || printf ',' >> "$out"
    k=$((k + 1))
    printf '%s' "$l" >> "$out"
  done << EOF
$(LC_ALL=C awk -v skip="$from" -v most="$BATCH" -v total="$(lines)" "$valid_awk"'
  NR > total { exit }
  {
    line = $0; sub(/\r$/, "", line)
    # A write cut short, joined with the next event: keep the event at the
    # end when it is whole on its own.
    if (line != "" && !valid(line)) {
      rest = line; at = 0
      while ((k = index(rest, "{\"v\":")) > 0) { at += k; rest = substr(rest, k + 1) }
      if (at > 1 && valid(substr(line, at))) line = substr(line, at)
    }
    noid = index(line, "\"id\":\"") == 0
    if (noid) seen[line]++
    if (NR <= skip) next
    if (NR > skip + most) exit
    if (line == "" || !valid(line)) print "bad\t"
    else if (noid) print seen[line] "\t" line
    else print "ok\t" line
  }' "$log")
EOF
  printf ']}\n' >> "$out"
  echo "$n $k"
}

# post <body-file>: the HTTP status, 000 when there was no answer.
post() {
  local tok=${TIXFORGE_EVENTS_TOKEN//\\/\\\\}
  tok=${tok//\"/\\\"}
  printf 'header = "Authorization: Bearer %s"\n' "$tok" \
    | curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 \
      -X POST -H 'Content-Type: application/json' -K - --data-binary "@$1" "$ES_ENDPOINT" 2> /dev/null
}

# lock / unlock: the lock holds its owner, so a sender only frees its own.
# A lock untouched for 2 minutes is taken by moving it away first (only one
# mover wins), then looked at again: one touched meanwhile is put back.
lock() {
  local old="$lock.$me"
  if mkdir "$lock" 2> /dev/null; then
    echo "$me" > "$lock/owner"
    return 0
  fi
  [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2> /dev/null)" ] || return 1
  mv "$lock" "$old" 2> /dev/null || return 1
  if [ -z "$(find "$old" -maxdepth 0 -mmin +2 2> /dev/null)" ]; then
    mv "$old" "$lock" 2> /dev/null || rm -rf "$old"
    return 1
  fi
  rm -rf "$old"
  mkdir "$lock" 2> /dev/null || return 1
  echo "$me" > "$lock/owner"
}
unlock() { [ "$(cat "$lock/owner" 2> /dev/null)" = "$me" ] && rm -rf "$lock"; }

# send_all: send batches until nothing is left (0) or one fails (1).
send_all() {
  local from res covered events code body
  body=$(mktemp) || return 1
  while :; do
    from=$(sent)
    [ "$from" -lt "$(lines)" ] || break
    touch "$lock" 2> /dev/null
    res=$(batch "$from" "$body")
    covered=${res% *} events=${res#* }
    if [ "${covered:-0}" -eq 0 ]; then # cannot read the log: do not spin
      printf '%s ログを読めない\n' "$(tf_stamp)" > "$err_f"
      rm -f "$body"
      return 1
    fi
    if [ "$events" -gt 0 ]; then
      code=$(post "$body")
    else
      code=200 # only lines passed over: nothing to send
    fi
    case $code in
      2??)
        mark_sent $((from + covered))
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
    trap unlock EXIT
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
        unlock
        [ $rc -eq 0 ] || exit 0
      fi
      [ "$(sent)" -lt "$(lines)" ] || exit 0
      sleep 1
    done
    exit 0
    ;;
esac
