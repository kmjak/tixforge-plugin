#!/usr/bin/env bash
# The tixforge run state file, .tixforge/<id>/state.md: creates it and reads
# or writes its header table. Sections are written by Claude with Edit; this
# script owns the header so Status and Updated never drift apart. The ticket
# is .tixforge/<id>/snapshot.md and a GT id carries its issue number, so the
# header does not repeat them.
#
#   run-state.sh init <id>                   create state.md (Status research:in-progress)
#   run-state.sh get <id> [field]            print a header field (default Status)
#   run-state.sh set <id> <field> <value>    set Status / Branch / Base; also sets Updated
#   run-state.sh statuses                    every valid Status, one per line
#   run-state.sh list                        "<id>\t<Status>\t<Branch>" for every run
#   run-state.sh rewind <id> <phase> [--keep-log] [--reason <text>]
#                [--category <c>] [--trigger <t>]
#                                            go back to research / approach / plan / implement
#   run-state.sh cancel <id> [--category <c>] [--reason <text>]
#                                            set Status canceled
#   run-state.sh release <id> [--reason <text>]
#                                            remove the run: state.md, history/,
#                                            snapshot.md and its hash
#   run-state.sh categories <rewind|cancel>  every valid --category, one per line
#   run-state.sh triggers                    every valid --trigger, one per line
#   run-state.sh migrate [--check] <id>      bring state.md to the current format
#   run-state.sh review-next <id>            where Review goes on from (phase/review.md step 2)
#   run-state.sh pass <id> <phase>           pass the gate of research / approach / implement / review
#
# The Format row of the header is the version of the file's layout (none:
# 2, what v2 wrote). init writes the current one; migrate moves an older
# file up, and --check only prints what it would change (nothing when the
# file is current, or when the run is done or canceled: it goes no further,
# so it needs no change). Only init and migrate write Format. Raise
# STATE_FORMAT, and teach migrate the step, whenever a change makes the old
# layout wrong.
#
# rewind moves the sections of the target phase and every later phase into
# .tixforge/<id>/history/<time>.md (so they are not read as approved any
# more, but can be looked up), leaves them empty in state.md, puts
# "> <rewind_note>" (scripts/messages.yml, in this person's language; line
# breaks in the reason become spaces) under the target section, and sets
# Status to <phase>:in-progress. Going back to implement keeps the Implementation
# Log (the commits are still there) and moves Review and PR. --keep-log
# keeps the Implementation Log too when going back further (the work goes
# on on the same branch). Prints the history file. Refuses a done or
# canceled run, and a phase after the current one (rewinding to the current
# phase is fine: plan:awaiting-approval -> plan). Only the six fixed
# headings start a section (lib.sh), so "## " lines quoted in a fence stay
# with their section.
#
# --category is why (rewind: the cause of going back; cancel: why the ticket
# is dropped), --trigger is what started a rewind (the person, a Review
# finding, Implement or PR finding the plan cannot hold, a changed ticket).
# Both are fixed words (categories, triggers) for the event log only; the
# reason is the person's own text. cancel and release refuse a done or
# canceled run (exit 4).
#
# When a run leaves review:in-progress (to fix findings, to the gate, to the
# PR, or by a rewind from Review), the rounds of ## Review are logged too,
# one review_round event each (review_rounds), so the counts never depend on
# Claude writing an event.
#
# review-next reads ## Review and the Implementation Log and prints where
# Review goes on from, the first that holds of phase/review.md step 2:
#
#   step: <3|6|7|9|10|implement|rewind>
#   round: <latest round, or none>
#   drop: Round <n>          the latest round is cut short: remove it first
#   recheck: <#N ...>        Manual re-check items with no later check line
#   legacy: Round <n>, ...   rounds with a finding that has no Auto-fix line
#   why: <one line>
#
# "unfixed" is a finding decided fix / fix (auto) without "Fixed @". A round
# is cut short when it has fewer than two "#### " reviewer sections or one
# of them is empty. A finding without an Auto-fix line is step 6 in the
# latest round; it may also be 3.0's format (a decision line in the person's
# language), which the script cannot read, so its rounds are listed in
# legacy and Claude applies step 2's note on 3.0 to them. A Manual re-check #N is
# done by a later Log line "<word> @ <hash>: ... #N ..." (the manual check
# record, in the person's language); whether #N is still the user's to check
# is in the Plan's table, which Claude reads in step 9. Read only.
# pass is the automatic pass of a gate that is not in gates (skills/dev/run.md):
# it ends the phase's section with "> <gate_auto_pass>" (scripts/messages.yml,
# in this person's language) and sets Status to the next phase's
# in-progress, as set does. Only from <phase>:in-progress; plan and pr
# always stop, so they have no pass. Prints the new Status.
#
# Every change of Status, init, rewind, cancel and release append an event to
# .tixforge/events.jsonl (lib.sh event; docs/events.md lists them). A log that
# cannot be written stops nothing.
#
# Exit: 0 ok, 1 no such run, 2 usage or invalid value (a phase after the
#       current one, too), 3 run already exists, 4 the run is done or canceled,
#       5 the file is in a newer format than this tixforge knows.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2
  exit 2
}

top=$(tf_top)
sfile() { state_file "$1" "$top"; }

# Every Status a run can have, in phase order (statuses prints them). The
# meaning of each is in skills/dev/run.md ("Status のフォーマット").
STATUSES="research:in-progress research:awaiting-approval
approach:in-progress approach:awaiting-approval
plan:in-progress plan:awaiting-approval
implement:in-progress implement:awaiting-approval
review:in-progress review:awaiting-approval
pr:in-progress pr:awaiting-approval pr:awaiting-review pr:ready-to-merge
done canceled"
valid_status() {
  local v
  [ -n "$1" ] || return 1
  for v in $STATUSES; do [ "$v" = "$1" ] && return 0; done
  return 1
}

# put <file> <field> <value>: rewrite one row of the header table.
put() {
  local tmp
  tmp=$(mktemp) || exit 1
  awk -F'|' -v k="$2" -v v="$3" '
    { key = $2; gsub(/^[ \t]+|[ \t]+$/, "", key) }
    !done && key == k { printf "| %-7s | %-34s |\n", k, v; done = 1; next }
    { print }
    END { if (!done) exit 1 }' "$1" > "$tmp" || {
    rm -f "$tmp"
    echo "no field $2 in $1" >&2
    exit 2
  }
  cat "$tmp" > "$1"
  rm -f "$tmp"
}

STATE_FORMAT=3

# The words of --category and --trigger; the skill that asks lists each with
# its meaning (rewind.md, cancel.md), and the tests keep the lists the same.
REWIND_CATEGORIES="misread constraint infeasible spec_change other"
CANCEL_CATEGORIES="priority duplicate spec_change infeasible other"
TRIGGERS="human review implement pr ticket"
# review_rounds <state.md>: one line per "### Round <n>" of ## Review,
# "<n>\t<findings>\t<unparsed>". findings is a JSON array, one object per
# finding in the order written (a finding is a top-level "- " item of a
# round): id and label from "- **R1 [kind]**" (label as written, in the
# review's language; both "" for an item the implementer added), auto_fix
# (fix / accept / ask for ○ / × / △), decision (fix, fix (auto), accept,
# accept (auto), replan, reapproach; null before one is written) and fixed
# (the hash of "Fixed @", or null). Every finding has an Auto-fix line
# (skills/dev/phase/review.md); an item without one is not in findings but counted in unparsed,
# so a slip in the format shows. Lines in a fence are skipped. The symbols are
# matched as strings (index), never in a bracket expression: in the C locale
# [○×△] would match single bytes.
review_rounds() {
  LC_ALL=C awk "$_section_awk"'
    function esc(t,   o, i, c) {
      o = ""
      for (i = 1; i <= length(t); i++) {
        c = substr(t, i, 1)
        if (c == "\\" || c == "\"") o = o "\\" c; else o = o c
      }
      return "\"" o "\""
    }
    function str(t) { return t == "" ? "null" : esc(t) }
    function close_finding() {
      if (!open_f) return
      if (af == "") unparsed++
      else items = items (items == "" ? "" : ",") "{\"id\":" esc(fid) ",\"label\":" esc(lab) ",\"auto_fix\":" esc(af) ",\"decision\":" str(dec) ",\"fixed\":" str(fx) "}"
      open_f = 0; fid = ""; lab = ""; af = ""; dec = ""; fx = ""
    }
    function close_round() {
      close_finding()
      if (round != "") printf "%s\t[%s]\t%d\n", round, items, unparsed
      round = ""; items = ""; unparsed = 0
    }
    {
      line = $0; sub(/\r$/, "", line)
      h = heading_index(line)
      if (h) { if (inrev) close_round(); inrev = (h == 5); next }
      if (!inrev || _fence != "" || line ~ /^ ? ? ?(```|~~~)/) next
      if (line ~ /^### Round [0-9]+[ \t]*$/) {
        close_round(); round = line; sub(/^### Round /, "", round); sub(/[ \t]+$/, "", round); next
      }
      if (round == "") next
      if (line ~ /^- /) {
        close_finding(); open_f = 1
        if (line ~ /^- \*\*[A-Z][0-9]+ \[/ && index(line, "]")) {
          t = substr(line, 5)
          fid = substr(t, 1, index(t, " ") - 1)
          t = substr(t, index(t, "[") + 1); lab = substr(t, 1, index(t, "]") - 1)
        }
        next
      }
      if (line ~ /^[ \t]*- Auto-fix:/) {
        if (!open_f) next
        if (index(line, "○")) af = "fix"; else if (index(line, "×")) af = "accept"; else if (index(line, "△")) af = "ask"
        next
      }
      if (open_f && line ~ /^[ \t]*- Decision:/) {
        t = line; sub(/^[ \t]*- Decision:[ \t]*/, "", t)
        if (t ~ /^fix \(auto\)/) dec = "fix (auto)"; else if (t ~ /^accept \(auto\)/) dec = "accept (auto)"
        else if (t ~ /^fix/) dec = "fix"; else if (t ~ /^accept/) dec = "accept"
        else if (t ~ /^replan/) dec = "replan"; else if (t ~ /^reapproach/) dec = "reapproach"
        next
      }
      if (open_f && line ~ /^[ \t]*- Fixed @ /) { t = line; sub(/^[ \t]*- Fixed @ /, "", t); sub(/[ \t].*$/, "", t); fx = t }
    }
    END { if (inrev) close_round() }' "$1"
}
# log_review <state.md> <id>: a review_round event per round.
log_review() {
  local n items unparsed
  while IFS="$(printf '\t')" read -r n items unparsed; do
    [ -n "$n" ] || continue
    event "$top" "$2" review_round round "$n" findings "$items" unparsed "$unparsed"
  done << EOF
$(review_rounds "$1")
EOF
}

# review_facts <state.md>: the facts review-next decides on, one per line:
#   R <round> <verification hash or -> <cut short 0|1>
#   F <round> <auto_fix: fix|accept|ask|-> <decision or -> <fixed hash or ->
#   M <N> <done 0|1>
review_facts() {
  LC_ALL=C awk "$_section_awk"'
    function close_finding() {
      if (!open_f) return
      printf "F %s %s %s %s\n", round, (af == "" ? "-" : af), (dec == "" ? "-" : dec), (fx == "" ? "-" : fx)
      open_f = 0; af = ""; dec = ""; fx = ""
    }
    function close_sec() { if (sec_open && !sec_body) short = 1; sec_open = 0; sec_body = 0 }
    function close_round() {
      close_finding(); close_sec()
      if (round != "") printf "R %s %s %d\n", round, (vh == "" ? "-" : vh), (short || nsec < 2)
      round = ""; vh = ""; nsec = 0; short = 0
    }
    {
      line = $0; sub(/\r$/, "", line)
      h = heading_index(line)
      if (h) { if (inrev) close_round(); inrev = (h == 5); inlog = (h == 4); next }
      if (inlog && _fence == "") {
        if (line ~ /Manual re-check:/) {
          t = line; sub(/.*Manual re-check:[ \t]*/, "", t)
          while (match(t, /#[0-9]+/)) { n = substr(t, RSTART + 1, RLENGTH - 1); mr[n] = 1; done[n] = 0; t = substr(t, RSTART + RLENGTH) }
        } else if (line !~ /(Verification|PR comment|PR head) @/ && line ~ /@ [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*[^:]*:/) {
          for (n in mr) if (!done[n] && match(line, "#" n "([^0-9]|$)")) done[n] = 1
        }
        next
      }
      if (!inrev || _fence != "" || line ~ /^ ? ? ?(```|~~~)/) next
      if (line ~ /^### Round [0-9]+[ \t]*$/) {
        close_round(); round = line; sub(/^### Round /, "", round); sub(/[ \t]+$/, "", round); next
      }
      if (round == "") next
      if (vh == "" && line ~ /^Verification @ /) { t = line; sub(/^Verification @ /, "", t); sub(/[+: ].*$/, "", t); vh = t; next }
      if (line ~ /^#### /) { close_finding(); close_sec(); nsec++; sec_open = 1; next }
      if (sec_open && line ~ /[^ \t]/) sec_body = 1
      if (line ~ /^- /) { close_finding(); open_f = 1; next }
      if (!open_f) next
      if (line ~ /^[ \t]*- Auto-fix:/) {
        if (index(line, "○")) af = "fix"; else if (index(line, "×")) af = "accept"; else if (index(line, "△")) af = "ask"
      } else if (line ~ /^[ \t]*- Decision:/) {
        t = line; sub(/^[ \t]*- Decision:[ \t]*/, "", t)
        if (t ~ /^fix \(auto\)/) dec = "fix(auto)"; else if (t ~ /^accept \(auto\)/) dec = "accept(auto)"
        else if (t ~ /^fix/) dec = "fix"; else if (t ~ /^accept/) dec = "accept"
        else if (t ~ /^replan/) dec = "replan"; else if (t ~ /^reapproach/) dec = "reapproach"
      } else if (line ~ /^[ \t]*- Fixed @ /) { t = line; sub(/^[ \t]*- Fixed @ /, "", t); sub(/[ \t].*$/, "", t); fx = t }
    }
    END { if (inrev) close_round(); for (n in mr) printf "M %s %d\n", n, done[n] }' "$1"
}

# review_next <state.md>: phase/review.md step 2 (see the header).
review_next() {
  local facts last="" vh="" short=0 r a d f n dn recheck="" legacy
  facts=$(review_facts "$1")
  while read -r r a d f; do
    [ "$r" = R ] || continue
    last=$a vh=$d short=$f
  done << EOF
$facts
EOF
  while read -r r n dn _; do
    [ "$r" = M ] && [ "$dn" = 0 ] && recheck="$recheck #$n"
  done << EOF
$facts
EOF
  recheck=$(printf '%s' "$recheck" | tr ' ' '\n' | grep . | sort -t'#' -k2 -n | paste -sd' ' -)
  legacy=$(printf '%s\n' "$facts" | awk '$1 == "F" && $3 == "-" && !s[$2]++ { printf "%sRound %s", (n++ ? ", " : ""), $2 }')
  # say <step> <why>
  say() {
    printf 'step: %s\nround: %s\n' "$1" "${last:-none}"
    [ "$1" = 3 ] && [ "$short" = 1 ] && printf 'drop: Round %s\n' "$last"
    [ -n "$recheck" ] && printf 'recheck: %s\n' "$recheck"
    [ -n "$legacy" ] && printf 'legacy: %s\n' "$legacy"
    printf 'why: %s\n' "$2"
  }
  # has <pattern> <round|any>: a finding line "F <round> <af> <dec> <fixed>" matches.
  has() { printf '%s\n' "$facts" | awk -v p="$1" -v r="$2" '$1 == "F" && (r == "any" || $2 == r) && ($3 " " $4 " " $5) ~ p { f = 1 } END { exit !f }'; }
  if [ -z "$last" ]; then
    say 3 "no round yet"
    return
  fi
  if [ "$short" = 1 ]; then
    say 3 "Round $last is cut short (a reviewer section is missing or empty)"
    return
  fi
  if has '^- -' "$last"; then
    say 6 "Round $last has a finding with neither Auto-fix nor Decision"
    return
  fi
  if has '^(fix|accept) - ' "$last"; then
    say 7 "Round $last has a finding marked ○ or × without a Decision"
    return
  fi
  if has ' (reapproach|replan) ' any; then
    say rewind "a finding is decided replan or reapproach"
    return
  fi
  if has '^fix fix([(]auto[)])? -$' "$last"; then
    say implement "Round $last has a ○ finding decided fix and not fixed"
    return
  fi
  if [ "$vh" != - ] && ! git -C "$top" rev-parse -q --verify "$vh^{commit}" > /dev/null 2>&1; then
    say 3 "Round $last's Verification ($vh) is no commit here: verify again"
    return
  fi
  if [ "$vh" != - ] && [ -n "$(git -C "$top" rev-list "$vh..HEAD" 2> /dev/null | head -1)" ]; then
    say 3 "HEAD is ahead of Round $last's Verification ($vh)"
    return
  fi
  if has '^ask - ' any || [ -n "$recheck" ]; then
    say 9 "a △ finding has no Decision, or a Manual re-check is open"
    return
  fi
  if has ' fix([(]auto[)])? -$' any; then
    say implement "a finding decided fix is not fixed"
    return
  fi
  say 10 "every finding is decided and nothing is left to fix"
}

# one_of <value> <words>: exit 0 when the value is one of the words.
one_of() {
  local v
  for v in $2; do [ "$v" = "$1" ] && return 0; done
  return 1
}
# jtext <text>: json_str, or null for nothing.
jtext() { if [ -n "$1" ]; then json_str "$1"; else echo null; fi; }
# open_run <id>: the state.md of a run that is neither done nor canceled;
# exits 1 or 4 otherwise.
open_run() {
  local f st
  f=$(sfile "$1")
  [ -f "$f" ] || {
    echo "no run: $1" >&2
    exit 1
  }
  st=$(field "$f" Status)
  case $st in done | canceled)
    echo "run $1 is $st" >&2
    exit 4
    ;;
  esac
  printf '%s\n' "$f"
}

# phase_no <phase>: 1..6 in phase order, 0 for anything else (done, canceled).
phase_no() {
  case $1 in
    research) echo 1 ;; approach) echo 2 ;; plan) echo 3 ;;
    implement) echo 4 ;; review) echo 5 ;; pr) echo 6 ;; *) echo 0 ;;
  esac
}
# transition <from> <to>: what a change of Status was, for the status event.
#   gate     stopped at a gate (to <phase>:awaiting-approval)
#   approve  from a gate to the next phase
#   forward  to the next phase without stopping (a gate passed
#            automatically, or back to Review after fixing its findings)
#   back     to an earlier phase without a rewind (fixing Review findings,
#            a failed verification)
#   pr       within the PR phase (review, CI, conflicts)
#   done, cancel, other
transition() {
  local fp tp
  case $2 in
    done) echo done && return ;;
    canceled) echo cancel && return ;;
    *:awaiting-approval) echo gate && return ;;
  esac
  fp=$(phase_no "${1%%:*}") tp=$(phase_no "${2%%:*}")
  if [ "$fp" -eq 6 ] && [ "$tp" -eq 6 ]; then
    echo pr
  elif [ "$fp" -gt 0 ] && [ "$tp" -eq $((fp + 1)) ] && [ "${2#*:}" = in-progress ]; then
    case ${1#*:} in awaiting-approval) echo approve ;; in-progress) echo forward ;; *) echo other ;; esac
  elif [ "$tp" -gt 0 ] && [ "$tp" -lt "$fp" ]; then
    echo back
  else
    echo other
  fi
}

# The comments v2 wrote under each empty section (format 2). migrate removes
# exactly these lines; any other comment is the user's.
V2_PLACEHOLDERS='<!-- Phase 1: organized understanding of the ticket + relevant context -->
<!-- Phase 2: chosen implementation approach and key design decisions -->
<!-- Phase 3: branch, base, acceptance criteria -> verification table, ordered commits -->
<!-- Phase 4: commits, verification results, manual checks, notable decisions -->
<!-- Phase 5: reviewer findings as rounds, with recommendations and decisions -->
<!-- Phase 6: title, target branch, URL, review outcome -->'

# format_of <file>: the Format row of the header table, or 2 when there is
# none. Only the first table is read: a section may have a table of its own
# with a Format row.
format_of() {
  local v
  v=$(awk -F'|' '/^\|/ { t = 1; key = $2; gsub(/^[ \t]+|[ \t]+$/, "", key)
      if (key == "Format") { v = $3; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit }
      next }
    t { exit }' "$1")
  printf '%s\n' "${v:-2}"
}

# v2_step <file> <count|write>: count the v2 placeholders outside fences, or
# print the file without them and with a Format row after the header table.
v2_step() {
  RS_PH=$V2_PLACEHOLDERS awk -v mode="$2" -v fmt="$STATE_FORMAT" "$_section_awk"'
    BEGIN { n = split(ENVIRON["RS_PH"], p, "\n"); for (i = 1; i <= n; i++) ph[p[i]] = 1 }
    {
      line = $0; sub(/\r$/, "", line)
      heading_index($0)
      if (_fence == "" && line in ph) { found++; next }
      if (mode == "write" && !added && intable && line !~ /^\|/) { printf "| %-7s | %-34s |\n", "Format", fmt; added = 1 }
      if (line ~ /^\|/) intable = 1
      if (mode == "write") print
    }
    END {
      if (mode == "count") print found + 0
      else if (!added) printf "| %-7s | %-34s |\n", "Format", fmt
    }' "$1"
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
  init)
    [ $# -eq 1 ] || usage
    is_ticket_id "$1" || {
      echo "not a ticket id: $1" >&2
      exit 2
    }
    f=$(sfile "$1")
    [ -e "$f" ] && {
      echo "run already exists: ${f#$top/}" >&2
      exit 3
    }
    ensure_workspace "$top"
    mkdir -p "$(dirname "$f")"
    {
      printf '# Run: %s\n\n' "$1"
      printf '| %-7s | %-34s |\n' Field Value
      printf '|---------|------------------------------------|\n'
      printf '| %-7s | %-34s |\n' Status research:in-progress \
        Branch — Base — Updated "$(tf_now)" Format "$STATE_FORMAT"
      old_ifs=$IFS
      IFS='|'
      for sec in $STATE_SECTIONS; do printf '\n## %s\n' "$sec"; done
      IFS=$old_ifs
    } > "$f"
    event "$top" "$1" run_started status '"research:in-progress"'
    printf '%s\n' "${f#$top/}"
    ;;
  get)
    [ $# -ge 1 ] && [ $# -le 2 ] || usage
    f=$(sfile "$1")
    [ -f "$f" ] || {
      echo "no run: $1" >&2
      exit 1
    }
    field "$f" "${2:-Status}"
    ;;
  set)
    [ $# -eq 3 ] || usage
    f=$(sfile "$1")
    [ -f "$f" ] || {
      echo "no run: $1" >&2
      exit 1
    }
    case $2 in
      Status) valid_status "$3" || {
        echo "invalid Status: $3" >&2
        exit 2
      } ;;
      Branch | Base) ;;
      *)
        echo "field not settable: $2 (Status, Branch, Base)" >&2
        exit 2
        ;;
    esac
    [ "$2" = Status ] && before=$(field "$f" Status)
    [ "$2" = Status ] && [ "$before" = review:in-progress ] && [ "$3" != "$before" ] && log_review "$f" "$1"
    put "$f" "$2" "$3"
    put "$f" Updated "$(tf_now)"
    [ "$2" = Status ] && [ "$before" != "$3" ] \
      && event "$top" "$1" status from "$(json_str "$before")" to "$(json_str "$3")" \
        via "$(json_str "$(transition "$before" "$3")")"
    field "$f" "$2"
    ;;
  rewind)
    [ $# -ge 2 ] || usage
    id=$1 phase=$2 keep="" reason="" category="" trigger=""
    shift 2
    while [ $# -gt 0 ]; do
      case $1 in
        --keep-log)
          keep=1
          shift
          ;;
        --reason)
          [ $# -ge 2 ] || usage
          reason=$2
          shift 2
          ;;
        --category)
          [ $# -ge 2 ] || usage
          one_of "$2" "$REWIND_CATEGORIES" || {
            echo "invalid category: $2 ($REWIND_CATEGORIES)" >&2
            exit 2
          }
          category=$2
          shift 2
          ;;
        --trigger)
          [ $# -ge 2 ] || usage
          one_of "$2" "$TRIGGERS" || {
            echo "invalid trigger: $2 ($TRIGGERS)" >&2
            exit 2
          }
          trigger=$2
          shift 2
          ;;
        *) usage ;;
      esac
    done
    f=$(sfile "$id")
    [ -f "$f" ] || {
      echo "no run: $id" >&2
      exit 1
    }
    before=$(field "$f" Status)
    case $before in done | canceled)
      echo "run $id is $before: it cannot be rewound" >&2
      exit 4
      ;;
    esac
    # Phases in order; target is the section that gets the note.
    case $phase in
      research)
        from=1
        target=1
        ;;
      approach)
        from=2
        target=2
        ;;
      plan)
        from=3
        target=3
        ;;
      implement)
        from=5
        target=4
        keep=1
        ;;
      *)
        echo "cannot rewind to: $phase (research, approach, plan, implement)" >&2
        exit 2
        ;;
    esac
    case ${before%%:*} in
      research) at=1 ;; approach) at=2 ;; plan) at=3 ;; implement) at=4 ;; review) at=5 ;; *) at=6 ;;
    esac
    if [ "$target" -gt "$at" ]; then
      echo "cannot rewind to $phase: run $id is at $before (rewind goes back, not forward)" >&2
      exit 2
    fi
    case $before in review:*) log_review "$f" "$id" ;; esac
    now=$(tf_now)
    # Two rewinds in the same second must not share a file (awk truncates it).
    stamp=$(date '+%Y%m%d-%H%M%S')
    hist="$(dirname "$f")/history/$stamp.md"
    i=2
    while [ -e "$hist" ]; do
      hist="$(dirname "$f")/history/$stamp-$i.md"
      i=$((i + 1))
    done
    mkdir -p "$(dirname "$hist")"
    tmp=$(mktemp) || exit 1
    # Section n (1-based in STATE_SECTIONS) moves when n >= from, except the
    # Implementation Log (4) with --keep-log. Text goes in through ENVIRON:
    # awk -v would turn the \t of C:\temp into a tab.
    RW_HIST=$hist RW_HEAD="# Rewound to $phase ($now)" RW_WAS="Status before: $before" \
      RW_WHY=$reason RW_NOTE="> $(msg_fill rewind_note "$(user_lang "$top")" time "$now" reason "$(printf '%s' "$reason" | tr -s '\r\n' '  ')")" \
      awk -v from="$from" -v keep="$keep" -v target="$target" \
      "$_section_awk"'
      BEGIN {
        hist = ENVIRON["RW_HIST"]; why = ENVIRON["RW_WHY"]
        print ENVIRON["RW_HEAD"] > hist; print "" > hist; print ENVIRON["RW_WAS"] > hist
        if (why != "") print "Reason: " why > hist
      }
      { cur = heading_index($0) }
      cur {
        moving = cur >= from && !(cur == 4 && keep != "")
        print
        if (cur == target + 0 && why != "") print ENVIRON["RW_NOTE"]
        if (moving) { print "" > hist; print $0 > hist; print "" }
        next
      }
      moving { print > hist; next }
      { print }' "$f" > "$tmp" || {
      rm -f "$tmp"
      exit 1
    }
    cat "$tmp" > "$f"
    rm -f "$tmp"
    put "$f" Status "$phase:in-progress"
    put "$f" Updated "$now"
    event "$top" "$id" rewind from "$(json_str "$before")" to "$(json_str "$phase:in-progress")" \
      category "$(jtext "$category")" trigger "$(jtext "$trigger")" reason "$(jtext "$reason")" \
      history "$(json_str "${hist#$top/}")" keep_log "$(if [ -n "$keep" ]; then echo true; else echo false; fi)"
    printf '%s\n' "${hist#$top/}"
    ;;
  migrate)
    check=""
    [ "${1:-}" = --check ] && check=1 && shift
    [ $# -eq 1 ] || usage
    f=$(sfile "$1")
    [ -f "$f" ] || {
      echo "no run: $1" >&2
      exit 1
    }
    from=$(format_of "$f")
    case $from in '' | *[!0-9]*)
      echo "invalid Format in ${f#$top/}: $from" >&2
      exit 2
      ;;
    esac
    [ "$from" -gt "$STATE_FORMAT" ] && {
      echo "${f#$top/} is format $from, newer than this tixforge ($STATE_FORMAT): update the plugin" >&2
      exit 5
    }
    [ "$from" -eq "$STATE_FORMAT" ] && exit 0
    # Format 2 -> 3 is the only step so far.
    if [ -n "$check" ]; then
      case $(field "$f" Status) in done | canceled) exit 0 ;; esac
      printf 'format %s -> %s\n' "$from" "$STATE_FORMAT"
      n=$(v2_step "$f" count)
      [ "$n" -gt 0 ] && printf -- '- remove the placeholder comments (%s)\n' "$n"
      printf -- '- add the Format row\n'
      exit 0
    fi
    tmp=$(mktemp) || exit 1
    v2_step "$f" write > "$tmp" || {
      rm -f "$tmp"
      exit 1
    }
    cat "$tmp" > "$f"
    rm -f "$tmp"
    printf 'format %s -> %s: %s\n' "$from" "$STATE_FORMAT" "${f#$top/}"
    ;;
  cancel)
    [ $# -ge 1 ] || usage
    id=$1 reason="" category=""
    shift
    while [ $# -gt 0 ]; do
      case $1 in
        --reason)
          [ $# -ge 2 ] || usage
          reason=$2
          shift 2
          ;;
        --category)
          [ $# -ge 2 ] || usage
          one_of "$2" "$CANCEL_CATEGORIES" || {
            echo "invalid category: $2 ($CANCEL_CATEGORIES)" >&2
            exit 2
          }
          category=$2
          shift 2
          ;;
        *) usage ;;
      esac
    done
    f=$(open_run "$id") || exit $?
    before=$(field "$f" Status)
    put "$f" Status canceled
    put "$f" Updated "$(tf_now)"
    event "$top" "$id" canceled from "$(json_str "$before")" \
      category "$(jtext "$category")" reason "$(jtext "$reason")"
    field "$f" Status
    ;;
  release)
    [ $# -ge 1 ] || usage
    id=$1 reason=""
    shift
    while [ $# -gt 0 ]; do
      case $1 in
        --reason)
          [ $# -ge 2 ] || usage
          reason=$2
          shift 2
          ;;
        *) usage ;;
      esac
    done
    f=$(open_run "$id") || exit $?
    before=$(field "$f" Status)
    d=$(dirname "$f")
    rm -rf "$d/history"
    rm -f "$f" "$d/snapshot.md" "$d/.snapshot.md.hash"
    rmdir "$d" 2> /dev/null || true
    event "$top" "$id" released from "$(json_str "$before")" reason "$(jtext "$reason")"
    printf 'released: %s\n' "$id"
    ;;
  categories)
    [ $# -eq 1 ] || usage
    case $1 in
      rewind) words=$REWIND_CATEGORIES ;;
      cancel) words=$CANCEL_CATEGORIES ;;
      *) usage ;;
    esac
    for v in $words; do printf '%s\n' "$v"; done
    ;;
  triggers)
    [ $# -eq 0 ] || usage
    for v in $TRIGGERS; do printf '%s\n' "$v"; done
    ;;
  review-next)
    [ $# -eq 1 ] || usage
    f=$(sfile "$1")
    [ -f "$f" ] || {
      echo "no run: $1" >&2
      exit 1
    }
    review_next "$f"
    ;;
  pass)
    [ $# -eq 2 ] || usage
    f=$(sfile "$1")
    [ -f "$f" ] || {
      echo "no run: $1" >&2
      exit 1
    }
    case $2 in
      research) sec=1 nxt=approach ;;
      approach) sec=2 nxt=plan ;;
      implement) sec=4 nxt=review ;;
      review) sec=5 nxt=pr ;;
      *)
        echo "pass: research, approach, implement or review (plan and pr always stop)" >&2
        exit 2
        ;;
    esac
    cur=$(field "$f" Status)
    [ "$cur" = "$2:in-progress" ] || {
      echo "Status is $cur, not $2:in-progress" >&2
      exit 2
    }
    # The note goes after the section's last line that is not blank. Text
    # goes in through ENVIRON (-v and operands would read its backslashes).
    tmp=$(mktemp) || exit 1
    TF_NOTE="> $(msg gate_auto_pass "$(user_lang "$top")")" awk "$_section_awk"'
      function flush() { if (on) { printf "%s", body; if (body != "") print ""; print ENVIRON["TF_NOTE"]; print ""; on = 0; body = ""; blanks = ""; found = 1 } }
      { h = heading_index($0) }
      h { flush(); print; if (h == s) { on = 1 }; next }
      on && /^[ \t\r]*$/ { blanks = blanks $0 "\n"; next }
      on { body = body blanks $0 "\n"; blanks = ""; next }
      { print }
      END { flush(); exit !found }' s="$sec" "$f" > "$tmp" || {
      rm -f "$tmp"
      echo "no section for $2 in ${f#"$top"/}" >&2
      exit 2
    }
    cat "$tmp" > "$f"
    rm -f "$tmp"
    bash "$0" set "$1" Status "$nxt:in-progress"
    ;;
  statuses)
    [ $# -eq 0 ] || usage
    for v in $STATUSES; do printf '%s\n' "$v"; done
    ;;
  list)
    each_run "$top" | tr "$RUN_SEP" '\t' | cut -f1-3
    ;;
  *) usage ;;
esac
