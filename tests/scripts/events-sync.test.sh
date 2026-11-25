#!/usr/bin/env bash
# Tests of events-sync.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"

# --- events-sync.sh ----------------------------------------------------------
# Sending the log to events.endpoint with TIXFORGE_EVENTS_TOKEN, against a
# small local endpoint (python3) that records each request and answers with
# the status in its "code" file (200 when there is none).
section="events-sync.sh"
if command -v python3 > /dev/null && command -v curl > /dev/null; then
  srv="$tmp/srv"
  mkdir -p "$srv"
  cat > "$tmp/server.py" << 'EOF'
import http.server, json, os, sys, threading, time
d = sys.argv[1]
n = [0]
lock = threading.Lock()
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            code = open(os.path.join(d, "code")).read().strip()
        except Exception:
            code = "200"
        if code == "sleep":
            time.sleep(15)
            return
        try:
            parsed = json.loads(body)
        except Exception:
            self.send_response(400)
            self.end_headers()
            open(os.path.join(d, "bad-json"), "a").write("x")
            return
        with lock:
            n[0] += 1
            k = n[0]
        rec = {"path": self.path, "auth": self.headers.get("Authorization"),
               "type": self.headers.get("Content-Type"), "body": parsed}
        code = int(code)
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"accepted":0,"duplicates":0}')
        with open(os.path.join(d, "req-%d.json.tmp" % k), "w") as f:
            json.dump(rec, f, ensure_ascii=False)
        os.rename(os.path.join(d, "req-%d.json.tmp" % k), os.path.join(d, "req-%d.json" % k))
    def log_message(self, *a):
        pass
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
s.daemon_threads = True
open(os.path.join(d, "port.tmp"), "w").write(str(s.server_address[1]))
os.rename(os.path.join(d, "port.tmp"), os.path.join(d, "port"))
s.serve_forever()
EOF
  python3 -I "$tmp/server.py" "$srv" &
  srv_pid=$!
  i=0
  while [ ! -f "$srv/port" ] && [ $i -lt 50 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  port=$(cat "$srv/port")
  es="$tmp/es"
  git init -q -b main "$es"
  cd "$es" || exit 1
  git commit -q --allow-empty -m init
  git remote add origin https://github.com/kmjak/demo.git
  esev="$es/.tixforge/events.jsonl"
  esh() { bash "$scripts/events-sync.sh" "$@"; }
  reqs() { find "$srv" -name 'req-*.json' | wc -l | tr -d ' '; }
  req() { cat "$srv/req-$1.json"; }
  # settle [n]: wait for the background sender: n requests in all, and no lock.
  settle() {
    local i=0
    while [ $i -lt 100 ]; do
      if [ "$(reqs)" -ge "${1:-0}" ] && [ ! -d "$esev.lock" ]; then
        sleep 0.2
        [ ! -d "$esev.lock" ] && return 0
      fi
      sleep 0.1
      i=$((i + 1))
    done
    ng "the background sender did not finish (requests: $(reqs))"
  }
  ps_sync() { bash "$scripts/project-status.sh" | sed -n 's/.* \(events_sync=.*\)$/\1/p'; }
  unset TIXFORGE_EVENTS_TOKEN

  # Off: no endpoint, no token, not https, no origin. Nothing is sent.
  st init GT-000001 > /dev/null
  printf 'language: ja\n' > .tixforge/config.yml
  eq "events_sync=off（events.endpoint なし）" "$(ps_sync)" "off without events.endpoint"
  mkdir -p .tixforge
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  eq "events_sync=off（TIXFORGE_EVENTS_TOKEN なし）" "$(ps_sync)" "off without the token"
  export TIXFORGE_EVENTS_TOKEN='tok-"secret\1'
  printf 'events:\n  endpoint: http://example.com/api/events\n' > .tixforge/config.yml
  eq "events_sync=off（events.endpoint が https:// でない）" "$(ps_sync)" "off for http:// other than localhost"
  for u in http://localhost:80@evil.example/x https://user@example.com/x; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=off（events.endpoint に使えない文字（空白・@・\\））" "$(ps_sync)" "off for user info in $u (the token would go to another host)"
  done
  for u in http://localhost.evil.example/x http://127.0.0.1.evil.example/ http://127.0.0.1:8a/x; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=off（events.endpoint が https:// でない）" "$(ps_sync)" "off for a look-alike of localhost: $u"
  done
  for u in https://example.com/api/events http://localhost:3000/api/events http://127.0.0.1/api http://localhost; do
    printf 'events:\n  endpoint: %s\n' "$u" > .tixforge/config.yml
    eq "events_sync=on" "$(ps_sync)" "on for $u"
  done
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  git remote set-url origin /srv/git/nothing
  eq "events_sync=off（origin から owner/repo が分からない）" "$(ps_sync)" "off when origin is not owner/repo"
  for u in git@github.com:kmjak/demo.git ssh://git@github.com/kmjak/demo https://github.com/kmjak/demo.git/; do
    git remote set-url origin "$u"
    eq "events_sync=on" "$(ps_sync)" "owner/repo from $u"
  done
  printf 'events:\n  endpoint: http://example.com/x\n' > .tixforge/config.yml
  esh flush > /dev/null 2>&1
  eq 3 $? "flush when off"
  printf 'events:\n  endpoint: http://127.0.0.1:%s/api/events\n' "$port" > .tixforge/config.yml
  eq 0 "$(reqs)" "nothing was sent while off"
  [ -e "$esev.sent" ] && ng "no .sent while off" || ok

  # On: the line written starts sending in the background; what was there
  # before (written while off, and a v3.3 line without an id) goes with it.
  printf '{"v":1,"at":"2026-11-21T10:00:00+09:00","ticket":"GT-000002","type":"run_started","status":"research:in-progress"}\n' >> "$esev"
  eq research:awaiting-approval "$(st set GT-000001 Status research:awaiting-approval)" "set prints what it did while sending"
  settle 1
  eq 1 "$(reqs)" "one request"
  eq /api/events "$(req 1 | jq -r .path)" "POST to the endpoint"
  eq 'Bearer tok-"secret\1' "$(req 1 | jq -r .auth)" "Authorization: Bearer <token>"
  eq application/json "$(req 1 | jq -r .type)" "Content-Type"
  eq kmjak/demo "$(req 1 | jq -r .body.repo)" "repo from origin"
  eq "$(jq -c 'del(.id)' "$esev")" "$(req 1 | jq -c '.body.events[] | del(.id)')" "events: the lines of the log, as they are"
  eq "$(jq -r 'select(.id) | .id' "$esev")" "$(req 1 | jq -r '.body.events[] | select(.ticket != "GT-000002") | .id')" "the ids of the log"
  oldid=$(req 1 | jq -r '.body.events[] | select(.ticket == "GT-000002") | .id')
  printf '%s\n' "$oldid" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-3[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' && ok || ng "a line without id gets one from its text: $oldid"
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" ".sent: all lines sent"
  eq "" "$(jq -c 'select(.id == null)' "$esev" | grep -v GT-000002)" "the log itself is not rewritten"
  # 2xx: the next request has only the new line.
  st set GT-000001 Status approach:in-progress > /dev/null
  settle 2
  eq 1 "$(req 2 | jq '.body.events | length')" "only the new line is sent"
  eq approach:in-progress "$(req 2 | jq -r '.body.events[0].to')" "and it is the new one"
  # 500: run-state works as before; the lines go again next time.
  echo 500 > "$srv/code"
  n=$(cat "$esev.sent")
  out=$(st set GT-000001 Status approach:awaiting-approval)
  eq "0:approach:awaiting-approval" "$?:$out" "set: same exit and output when the endpoint fails"
  settle 3
  eq "$n" "$(cat "$esev.sent")" "a 500 sends nothing"
  has "HTTP 500" "$(esh status)" "status shows the last failure"
  has "unsent: 1" "$(esh status)" "status counts the unsent line"
  esh flush > /dev/null 2>&1
  eq 1 $? "flush fails on 500"
  rm -f "$srv/code"
  eq "sent: $((n + 1)), unsent: 0" "$(esh flush)" "flush after the endpoint is back"
  eq approach:awaiting-approval "$(req "$(reqs)" | jq -r '.body.events[0].to')" "the same line goes again"
  case "$(esh status)" in *"last error"*) ng "a success clears the last failure" ;; *) ok ;; esac
  # Resending a line without id gives it the same id.
  echo 0 > "$esev.sent"
  esh flush > /dev/null
  eq "$oldid" "$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000002") | .id')" "the id from the text is the same every time"
  # At most a batch a time: the rest goes in the next request.
  echo 1 > "$esev.sent"
  r=$(reqs)
  total=$(wc -l < "$esev" | tr -d ' ')
  TIXFORGE_EVENTS_BATCH=2 esh flush > /dev/null
  eq "$(((total - 1 + 1) / 2))" "$(($(reqs) - r))" "batches of at most BATCH lines"
  eq "$total" "$(cat "$esev.sent")" "all sent in batches"
  # A record beyond the end of the log (the log was replaced) starts over.
  echo 999 > "$esev.sent"
  has "unsent: $total" "$(esh status)" "a .sent beyond the log counts as nothing sent"
  esh flush > /dev/null
  # A cut-short line is passed over (it would fail the whole request).
  printf '{"v":1,"id":"x","at":"t","ticket":"GT-000001","ty' >> "$esev"
  printf '\n' >> "$esev"
  esh flush > /dev/null
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "a broken line is passed over, not retried forever"
  # A write cut short has no newline: the next event joins it into one line
  # that starts with { and ends with }, but is not JSON. It is passed over
  # (the endpoint would answer 400 for every request with it).
  printf '{"v":1,"id":"cut","at":"t","ticket":"GT-000001","ty' >> "$esev"
  r=$(reqs)
  has "unsent: 0" "$(esh status)" "a line still being written is not counted"
  st set GT-000001 Status approach:in-progress > /dev/null
  settle $((r + 1))
  eq approach:in-progress "$(req "$(reqs)" | jq -r '.body.events[-1].to')" "the event after a cut-short write is sent"
  case "$(req "$(reqs)" | jq -c .body.events)" in *'"cut"'*) ng "the cut part is not sent" ;; *) ok ;; esac
  [ -e "$srv/bad-json" ] && ng "no request was rejected as bad JSON" || ok
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "and counted as sent"
  # Blank lines only: nothing to POST.
  printf '\n\n' >> "$esev"
  r=$(reqs)
  esh flush > /dev/null
  eq "$r" "$(reqs)" "blank lines make no request"
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "blank lines are passed over"
  # Two identical lines without id are two events, with ids that stay.
  dup='{"v":1,"at":"2026-11-21T10:00:01+09:00","ticket":"GT-000003","type":"wait_end","cause":"turn"}'
  printf '%s\n%s\n' "$dup" "$dup" >> "$esev"
  esh flush > /dev/null
  ids=$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' | paste -sd' ' -)
  eq 2 "$(printf '%s\n' $ids | sort -u | wc -l | tr -d ' ')" "identical lines without id get different ids"
  echo $(($(cat "$esev.sent") - 2)) > "$esev.sent"
  esh flush > /dev/null
  eq "$ids" "$(req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' | paste -sd' ' -)" "and the same ids when sent again"
  # Without md5sum and md5, cksum gives the id.
  nomd5="$tmp/nomd5-bin"
  mkdir -p "$nomd5"
  for t in bash git awk sed tr cat cut wc date mkdir mktemp mv rm rmdir find touch od curl cksum dirname sleep head grep; do
    p=$(command -v "$t") && ln -sf "$p" "$nomd5/$t"
  done
  echo $(($(cat "$esev.sent") - 2)) > "$esev.sent"
  PATH="$nomd5" bash "$scripts/events-sync.sh" flush > /dev/null
  eq 0 $? "flush works without md5"
  req "$(reqs)" | jq -r '.body.events[] | select(.ticket == "GT-000003") | .id' \
    | grep -cE '^[0-9a-f]{8}-[0-9a-f]{4}-3[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' | grep -qx 2 && ok || ng "cksum gives well-formed ids"
  # Two senders at once: every line is sent, .sent ends at the end.
  unset TIXFORGE_EVENTS_TOKEN
  for t in plan approach plan approach plan; do st set GT-000001 Status "$t:in-progress" > /dev/null; done
  export TIXFORGE_EVENTS_TOKEN='tok-"secret\1'
  want=$(jq -Rr 'fromjson? | select(.id) | .id' "$esev" | tail -5)
  r=$(reqs)
  esh flush > /dev/null 2>&1 &
  f1=$!
  esh flush > /dev/null 2>&1 &
  f2=$!
  wait "$f1" "$f2" # not a bare wait: the endpoint runs in the background too
  got=$(for i in $(seq $((r + 1)) "$(reqs)"); do req "$i" | jq -r '.body.events[].id'; done | sort -u)
  for id in $want; do printf '%s\n' "$got" | grep -qx "$id" || ng "two senders: $id was not sent"; done
  ok
  eq "$(wc -l < "$esev" | tr -d ' ')" "$(cat "$esev.sent")" "two senders: .sent reaches the end"
  [ -d "$esev.lock" ] && ng "two senders: the lock is released" || ok
  # The lock: another sender running, and one that died long ago.
  mkdir "$esev.lock"
  esh flush > /dev/null 2>&1
  eq 4 $? "flush waits for no one: another sender runs"
  touch -t 202601010000 "$esev.lock"
  esh flush > /dev/null 2>&1
  eq 0 $? "a lock older than 2 minutes is taken over"
  [ -d "$esev.lock" ] && ng "flush releases the lock" || ok
  # The endpoint takes the connection but never answers: run-state and the
  # hook return at once; the sender gives up after its timeout (5 s).
  echo sleep > "$srv/code"
  n=$(cat "$esev.sent")
  t0=$(date +%s)
  out=$(st set GT-000001 Status plan:awaiting-approval)
  eq "0:plan:awaiting-approval" "$?:$out" "set: same exit and output with an endpoint that never answers"
  printf '{"session_id":"s","cwd":"%s","hook_event_name":"Stop"}' "$es" | bash "$scripts/wait-hook.sh" | cat > /dev/null
  [ $(($(date +%s) - t0)) -le 1 ] && ok || ng "set and the hook do not wait for an endpoint that never answers"
  i=0
  while [ -d "$esev.lock" ] && [ $i -lt 300 ]; do # the background senders time out
    sleep 0.1
    i=$((i + 1))
  done
  t0=$(date +%s)
  esh flush > /dev/null 2>&1
  eq 1 $? "flush fails when the endpoint never answers"
  t=$(($(date +%s) - t0))
  [ "$t" -ge 4 ] && [ "$t" -le 8 ] && ok || ng "flush gives up after about 5 s (took $t s)"
  eq "$n" "$(cat "$esev.sent")" "nothing marked sent after a timeout"
  i=0
  while [ -d "$esev.lock" ] && [ $i -lt 100 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  rm -f "$srv/code"
  # The hook starts the sender too.
  r=$(reqs)
  printf '{"session_id":"s","cwd":"%s","hook_event_name":"Stop"}' "$es" | bash "$scripts/wait-hook.sh"
  settle $((r + 1))
  eq wait_start "$(req "$(reqs)" | jq -r '.body.events[-1].type')" "the hook's event is sent"
  # The endpoint is down: run-state does not wait, the line stays unsent.
  kill "$srv_pid" 2> /dev/null
  wait "$srv_pid" 2> /dev/null
  n=$(cat "$esev.sent")
  t0=$(date +%s)
  st set GT-000001 Status plan:in-progress > /dev/null
  eq 0 $? "set succeeds with the endpoint down"
  [ $(($(date +%s) - t0)) -le 1 ] && ok || ng "set does not wait for the sender"
  # The sender that set started may not hold its lock yet when settle looks:
  # a flush that meets it (exit 4) tries again.
  settle 0
  i=0
  while :; do
    esh flush > /dev/null 2>&1
    rc=$?
    [ "$rc" -eq 4 ] && [ $i -lt 50 ] || break
    sleep 0.2
    i=$((i + 1))
  done
  eq 1 "$rc" "flush fails with the endpoint down"
  eq "$n" "$(cat "$esev.sent")" "nothing marked sent"
  has "応答なし" "$(esh status)" "status says there was no answer"
  # The token is written nowhere.
  eq "" "$(grep -rlF 'secret' "$es/.tixforge" 2> /dev/null)" "the token is in no file"
  case "$(esh status)$(bash "$scripts/project-status.sh")" in *secret*) ng "the token is not printed" ;; *) ok ;; esac
  unset TIXFORGE_EVENTS_TOKEN
  cd "$repo" || exit 1
else
  echo "skip  [events-sync.sh] python3 or curl not found"
fi

done_file
