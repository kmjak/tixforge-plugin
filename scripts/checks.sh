#!/usr/bin/env bash
# The acceptance criteria -> checks table of a /tixforge:dev run and the
# results of its manual checks, kept as data (skills/dev/phase/plan.md,
# implement.md). Claude never edits them by hand: every change goes through
# a command here, and each command writes the table into ## Plan and the
# manual check records into ## Implementation Log again, between the marks
# <!-- tixforge:checks --> and <!-- tixforge:manual -->.
#
#   checks.sh put <id> <table file> [--reset]
#                     the table, as a markdown table: # | criterion | how |
#                     kind, one row per acceptance criterion numbered 1..n.
#                     kind: auto, browser, api or user (自動, Claude（ブラウザ）,
#                     Claude（API）, ユーザー are read too). Refused (exit 4)
#                     once a manual check is recorded, unless --reset.
#   checks.sh record <id> <no> <ok|ng|skipped> <hash> <claude|user> <file>
#                     a manual check of row <no>: the commit checked, who
#                     checked, and the file with the steps and what was seen
#                     (for skipped: why). Clears a recheck of the row.
#   checks.sh recheck <id> <no>
#                     row <no> must be checked again (a fix touched it)
#   checks.sh show <id>
#                     one line per row: no, kind, result (- before any),
#                     commit, by, recheck (0|1), criterion, how, steps file
#   checks.sh pr <id> [<verification line>]
#                     the PR's acceptance criteria (a checklist: auto rows
#                     are checked when the verification line has no fail)
#                     and, per manual row, a "### <criterion>（#<no>）"
#                     section with its steps; Claude rewrites them in the
#                     document language when that differs.
#   checks.sh render <id>
#
# Data: .tixforge/<id>/checks.tsv, tab-separated (\t, \n, \\ escaped):
#   check <no> <kind> <criterion> <how> <result> <commit> <by> <recheck>
# and checks/<no>.md, the steps of the latest manual check.
#
# Exit: 0 ok, 1 no such run, 2 usage, 3 the table does not follow the
#       format (nothing is written; the problems are printed), 4 no such row
#       / not allowed in this state.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   checks.sh' "$0" | sed 's/^#   //' >&2
  exit 2
}
top=$(tf_top)
tab=$(printf '\t')

run_dir() {
  local f
  f=$(state_file "$1" "$top")
  [ -f "$f" ] || {
    echo "no run: $1" >&2
    exit 1
  }
  dirname "$f"
}

_esc_awk='
function esc(s,   o, i, c) {
  o = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\") o = o "\\\\"; else if (c == "\t") o = o "\\t"; else if (c == "\n") o = o "\\n"; else o = o c
  }
  return o
}
function unesc(s,   o, i, c, d) {
  o = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\" && i < length(s)) {
      d = substr(s, ++i, 1)
      if (d == "t") o = o "\t"; else if (d == "n") o = o "\n"; else o = o d
    } else o = o c
  }
  return o
}
'

# render <id>: the table into ## Plan and the records into ## Implementation
# Log, each between its marks (added at the end of the section the first
# time).
render() {
  local d f t tmp lang
  d=$(run_dir "$1") || exit 1
  f="$d/state.md"
  t="$d/checks.tsv"
  [ -f "$t" ] || return 0
  lang=$(user_lang "$top")
  tmp=$(mktemp) || exit 1
  CK_TSV=$t CK_DIR="$d/checks" CK_HEAD="$(msg checks_header "$lang")" \
  CK_AUTO="$(msg check_kind_auto "$lang")" CK_BROWSER="$(msg check_kind_browser "$lang")" \
  CK_API="$(msg check_kind_api "$lang")" CK_USER="$(msg check_kind_user "$lang")" \
  CK_RECHECK="$(msg check_recheck "$lang")" CK_NONE="$(msg check_not_yet "$lang")" \
  LC_ALL=C awk "$_section_awk$_esc_awk"'
    function kw(k) { return k == "auto" ? ENVIRON["CK_AUTO"] : k == "browser" ? ENVIRON["CK_BROWSER"] : k == "api" ? ENVIRON["CK_API"] : ENVIRON["CK_USER"] }
    function cell(s) { gsub(/\|/, "\\|", s); gsub(/\n/, " ", s); return s }
    function table(   k, s) {
      s = "<!-- tixforge:checks -->\n" ENVIRON["CK_HEAD"] "\n|---|---|---|---|\n"
      for (k = 1; k <= n; k++) s = s "| " no[k] " | " cell(cond[k]) " | " cell(how[k]) " | " kw(kind[k]) " |\n"
      return s "<!-- /tixforge:checks -->\n"
    }
    function slurp(p,   l, s) { s = ""; while ((getline l < p) > 0) s = s "    " l "\n"; close(p); return s }
    function records(   k, s, any) {
      s = "<!-- tixforge:manual -->\n"
      for (k = 1; k <= n; k++) {
        if (kind[k] == "auto") continue
        any = 1
        if (res[k] == "-") s = s "- #" no[k] " " ENVIRON["CK_NONE"] "（" kw(kind[k]) "）\n"
        else s = s "- #" no[k] " " res[k] " @ " at[k] "（" by[k] "）\n" slurp(ENVIRON["CK_DIR"] "/" no[k] ".md")
        if (rc[k] == 1) s = s "  - " ENVIRON["CK_RECHECK"] "\n"
      }
      return any ? s "<!-- /tixforge:manual -->\n" : ""
    }
    BEGIN {
      t = ENVIRON["CK_TSV"]
      while ((getline l < t) > 0) {
        split(l, x, "\t"); if (x[1] != "check") continue
        n++; no[n] = x[2]; kind[n] = x[3]; cond[n] = unesc(x[4]); how[n] = unesc(x[5]); res[n] = x[6]; at[n] = x[7]; by[n] = x[8]; rc[n] = x[9]
      }
    }
    function put_block(which) { if (which == "checks") printf "%s", table(); else printf "%s", records(); done[which] = 1 }
    function opening(l) { return l == "<!-- tixforge:checks -->" || l == "<!-- tixforge:manual -->" }
    function closing(l) { return l == "<!-- /tixforge:checks -->" || l == "<!-- /tixforge:manual -->" }
    # Two passes over the file. The first notes, for each opening mark
    # outside fences, whether its closing mark follows before the next
    # section: only then is the old block between them replaced. A lost
    # closing mark keeps the text after the opening one (only the
    # opening line gives way to the block). Marks inside fences are text.
    FNR == 1 && NR != FNR { second = 1; _fence = ""; open_at = 0 }
    !second {
      line = $0; sub(/\r$/, "", line)
      if (heading_index($0)) { open_at = 0; next }
      if (_fence != "") next
      if (opening(line)) open_at = FNR
      else if (closing(line) && open_at) { closed[open_at] = 1; open_at = 0 }
      next
    }
    {
      line = $0; sub(/\r$/, "", line)
      h = heading_index($0)
      if (h) {
        skip = 0
        if (cur == 3 && !done["checks"]) { put_block("checks"); print "" }
        if (cur == 4 && !done["manual"] && records() != "") { put_block("manual"); print "" }
        cur = h; print; next
      }
      if (skip) { if (_fence == "" && closing(line)) skip = 0; next }
      if (_fence == "" && line == "<!-- tixforge:checks -->") { skip = (FNR in closed); put_block("checks"); next }
      if (_fence == "" && line == "<!-- tixforge:manual -->") { skip = (FNR in closed); put_block("manual"); next }
      print
    }
    END {
      # A fence left open above: the sections were not seen; add nothing
      # (each render would add another block inside the fence).
      if (_fence != "") exit
      if (cur == 3 && !done["checks"]) put_block("checks")
      if (cur == 4 && !done["manual"] && records() != "") put_block("manual")
    }' "$f" "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

# row_field <tsv> <no> <index>
row_field() { awk -F'\t' -v n="$2" -v k="$3" '$1 == "check" && $2 == n { print $k; exit }' "$1"; }

# set_row <tsv> <no> <index>=<value>...
set_row() {
  local t=$1 n=$2 tmp a=""
  shift 2
  for kv in "$@"; do a="$a${a:+$tab}$(printf '%s' "$kv" | tr '\t\n\r' '   ')"; done
  tmp=$(mktemp) || exit 1
  CK_SET=$a LC_ALL=C awk -F'\t' -v OFS='\t' -v n="$n" "$_esc_awk"'
    BEGIN { c = split(ENVIRON["CK_SET"], kv, "\t"); for (i = 1; i <= c; i++) { p = index(kv[i], "="); want[substr(kv[i], 1, p - 1) + 0] = esc(substr(kv[i], p + 1)) } }
    $1 == "check" && $2 == n { for (k in want) $k = want[k] }
    { print }' "$t" > "$tmp" && cat "$tmp" > "$t"
  rm -f "$tmp"
}

# parse_table <file>: "check" rows from a markdown table, or "error: " lines.
parse_table() {
  LC_ALL=C awk "$_esc_awk"'
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function kindof(s) {
      s = trim(s); gsub(/`/, "", s)
      if (s == "auto" || s == "自動") return "auto"
      if (s == "browser" || s ~ /^Claude[ ]*(（|\()(ブラウザ|browser)(）|\))$/) return "browser"
      if (s == "api" || s ~ /^Claude[ ]*(（|\()(API|api)(）|\))$/) return "api"
      if (s == "user" || s == "ユーザー" || s == "User") return "user"
      return ""
    }
    { sub(/\r$/, "") }
    /^[ \t]*\|/ {
      line = $0; sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
      # \| inside a cell is not a separator.
      gsub(/\\\|/, "\001", line)
      c = split(line, f, "|")
      for (i = 1; i <= c; i++) { gsub(/\001/, "|", f[i]); f[i] = trim(f[i]) }
      if (f[1] ~ /^:?-+:?$/) next
      if (f[1] ~ /^[0-9]/ && f[1] !~ /^[0-9]+$/) { print "error: row " f[1] ": the # column is a number"; next }
      if (f[1] !~ /^[0-9]+$/) { if (rows) print "error: a row after row " rows " has no number in the # column (" f[1] ")"; else header++; next }
      rows++
      if (c != 4) { print "error: row " f[1] ": 4 columns (#, criterion, how, kind), got " c; next }
      if (f[1] + 0 != rows) print "error: row " f[1] ": rows are numbered 1, 2, ... in order"
      k = kindof(f[4]); if (k == "") print "error: row " f[1] ": kind must be auto, browser, api or user (got " f[4] ")"
      if (f[2] == "" || f[3] == "") print "error: row " f[1] ": the criterion and how to check are needed"
      printf "check\t%d\t%s\t%s\t%s\t-\t-\t-\t0\n", f[1], k, esc(f[2]), esc(f[3])
    }
    END { if (!rows) print "error: no table rows (| 1 | criterion | how | kind |)" }' "$1"
}

cmd=${1:-}
[ $# -ge 1 ] && shift
case $cmd in
  put)
    [ $# -ge 2 ] && [ $# -le 3 ] || usage
    [ -z "${3:-}" ] || [ "$3" = --reset ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$2" ] || usage
    if [ -f "$t" ] && [ "${3:-}" != --reset ] && awk -F'\t' '$1 == "check" && $6 != "-" { f = 1 } END { exit !f }' "$t"; then
      echo "a manual check is recorded; --reset to replace the table (the records go)" >&2
      exit 4
    fi
    out=$(parse_table "$2")
    errs=$(printf '%s\n' "$out" | grep '^error: ' || true)
    [ -z "$errs" ] || {
      printf '%s\n' "$errs" >&2
      exit 3
    }
    printf '%s\n' "$out" > "$t"
    rm -rf "$d/checks"
    render "$1"
    printf '%s rows\n' "$(grep -c '^check' "$t")"
    ;;
  record)
    [ $# -eq 6 ] || usage
    case $2 in "" | *[!0-9]*) usage ;; esac
    set -- "$1" "$((10#$2))" "$3" "$4" "$5" "$6"
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$t" ] && [ -n "$(row_field "$t" "$2" 2)" ] || {
      echo "no row #$2" >&2
      exit 4
    }
    [ "$(row_field "$t" "$2" 3)" != auto ] || {
      echo "#$2 is checked by the tests (auto)" >&2
      exit 4
    }
    case $3 in ok | ng | skipped) ;; *) usage ;; esac
    case $4 in "" | *[!0-9a-f]*) usage ;; esac
    case $5 in claude | user) ;; *) usage ;; esac
    [ -f "$6" ] || usage
    LC_ALL=C awk '{ sub(/\r$/, "") } match($0, /^ ? ? ?(```+|~~~+)/) { m = substr($0, RSTART, RLENGTH); sub(/^ +/, "", m); if (f == "") f = m; else if (substr(m, 1, 1) == substr(f, 1, 1) && length(m) >= length(f) && substr($0, RSTART + RLENGTH) ~ /^[ \t]*$/) f = "" } END { exit f != "" }' "$6" || {
      echo "the steps have a code fence that is not closed" >&2
      exit 3
    }
    mkdir -p "$d/checks"
    tr -d '\r' < "$6" > "$d/checks/$2.md"
    set_row "$t" "$2" "6=$3" "7=$4" "8=$5" "9=0"
    render "$1"
    ;;
  recheck)
    [ $# -eq 2 ] || usage
    case $2 in "" | *[!0-9]*) usage ;; esac
    set -- "$1" "$((10#$2))"
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$t" ] && [ -n "$(row_field "$t" "$2" 2)" ] && [ "$(row_field "$t" "$2" 3)" != auto ] || {
      echo "no manual row #$2" >&2
      exit 4
    }
    set_row "$t" "$2" "9=1"
    render "$1"
    ;;
  show)
    [ $# -eq 1 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$t" ] || exit 0
    LC_ALL=C awk -F'\t' -v OFS='\t' -v dir="${d#"$top"/}/checks" "$_esc_awk"'
      $1 == "check" { print $2, $3, $6, $7, $8, $9, unesc($4), unesc($5), ($6 == "-" ? "-" : dir "/" $2 ".md") }' "$t"
    ;;
  pr)
    [ $# -ge 1 ] && [ $# -le 2 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$t" ] || {
      echo "no checks table" >&2
      exit 4
    }
    # Auto rows are checked when the line has a pass, no fail and no +dirty
    # (no commands configured: nothing ran, nothing is checked).
    passed=0
    case ${2:-} in "Verification @ "*" pass"*) case $2 in *" fail"* | *+dirty*) ;; *) passed=1 ;; esac ;; esac
    LC_ALL=C awk -F'\t' -v passed="$passed" -v dir="$d/checks" "$_esc_awk"'
      $1 != "check" { next }
      { n++; no[n] = $2; kind[n] = $3; cond[n] = unesc($4); how[n] = unesc($5); res[n] = $6; at[n] = $7; by[n] = $8; rc[n] = $9 }
      END {
        print "criteria:"
        for (k = 1; k <= n; k++) {
          ok = kind[k] == "auto" ? passed : (res[k] == "ok" && rc[k] != 1)
          r = kind[k] == "auto" ? "" : res[k] == "-" ? "（not checked）" : "（" res[k] " @ " at[k] ", " by[k] (rc[k] == 1 ? ", to check again" : "") "）"
          printf "- [%s] %s — %s%s\n", (ok ? "x" : " "), cond[k], how[k], r
        }
        print "manual:"
        for (k = 1; k <= n; k++) {
          if (kind[k] == "auto") continue
          printf "### %s（#%s）\n", cond[k], no[k]
          if (res[k] == "-") { print "(not checked)"; print ""; continue }
          p = dir "/" no[k] ".md"; while ((getline l < p) > 0) print l; close(p)
          printf "\n%s @ %s, %s\n\n", res[k], at[k], by[k]
        }
      }' "$t"
    ;;
  render)
    [ $# -eq 1 ] || usage
    run_dir "$1" > /dev/null || exit 1
    render "$1"
    ;;
  _import)
    # migrate (format 4 -> 5): the table in ## Plan and the manual check
    # lines of the Implementation Log as written by hand. Prints what it did,
    # or "kept as text: ..." when the table cannot be read (the run then
    # puts the table again with checks.sh put).
    [ $# -eq 1 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    f="$d/state.md"
    [ ! -s "$t" ] || {
      echo "checks.tsv already exists" >&2
      exit 4
    }
    # The first table of ## Plan, outside fences, that reads as the checks
    # table (a Base / branch or commit table may come first).
    tdir=$(mktemp -d) || exit 1
    awk "$_section_awk"'
      { h = heading_index($0); if (h) { on = (h == 3); next } }
      on && _fence == "" && /^[ \t]*\|/ { if (!in_t) { if (n) close(dir "/" n); n++; in_t = 1 }; print > (dir "/" n); next }
      { in_t = 0 }' dir="$tdir" "$f"
    out="" pick=0 first=""
    for tf in $(ls "$tdir" | sort -n); do
      o=$(parse_table "$tdir/$tf")
      if printf '%s\n' "$o" | grep -q '^error: '; then
        [ -n "$first" ] || first=$(printf '%s\n' "$o" | grep '^error: ' | head -1)
      else
        out=$o pick=$tf
        break
      fi
    done
    rm -rf "$tdir"
    [ "$pick" != 0 ] || {
      echo "kept as text: ${first:-no table in ## Plan}"
      exit 0
    }
    printf '%s\n' "$out" > "$t"
    mkdir -p "$d/checks"
    # Manual check lines: "<word> @ <hash>: #2 ok（...）・#3 未確認（...）";
    # "Manual re-check: #N" asks for one again until a later line checks it.
    LC_ALL=C awk "$_section_awk"'
      function res(w) { return w ~ /^(ok|OK)/ ? "ok" : w ~ /^(ng|NG|失敗|fail)/ ? "ng" : w ~ /^(未確認|skipped|not)/ ? "skipped" : "" }
      { line = $0; sub(/\r$/, "", line); h = heading_index(line); if (h) { on = (h == 4); next } }
      !on || _fence != "" { next }
      line ~ /Manual re-check:/ { t = line; while (match(t, /#[0-9]+/)) { n = substr(t, RSTART + 1, RLENGTH - 1); rc[n] = 1; t = substr(t, RSTART + RLENGTH) }; next }
      line !~ /(Verification|PR comment|PR head) @/ && match(line, /@ [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*/) {
        hash = substr(line, RSTART + 2, RLENGTH - 2); t = substr(line, RSTART + RLENGTH)
        while (match(t, /#[0-9]+[ \t]*[^ \t・,、（(]+/)) {
          m = substr(t, RSTART + 1, RLENGTH - 1); n = m; sub(/[^0-9].*/, "", n); w = m; sub(/^[0-9]+[ \t]*/, "", w)
          rest = substr(t, RSTART + RLENGTH); who = (rest ~ /^[ \t]*(（|\()?[ \t]*(ユーザー|user|User)/ ? "user" : "claude")
          r = res(w); if (r != "") { R[n] = r; H[n] = hash; B[n] = who; L[n] = line; rc[n] = 0 }
          t = rest
        }
      }
      END { for (n in R) printf "%s\t%s\t%s\t%s\t%s\n", n, R[n], H[n], B[n], L[n]; for (n in rc) if (rc[n]) printf "%s\trecheck\n", n }' "$f" \
      | while IFS="$tab" read -r n r h b l; do
        [ -n "$(row_field "$t" "$n" 2)" ] && [ "$(row_field "$t" "$n" 3)" != auto ] || continue
        if [ "$r" = recheck ]; then
          set_row "$t" "$n" "9=1"
        else
          printf '%s\n' "$l" > "$d/checks/$n.md"
          set_row "$t" "$n" "6=$r" "7=$h" "8=$b"
        fi
      done
    # The hand-written table gives way to the rendered one.
    tmp=$(mktemp) || exit 1
    awk "$_section_awk"'
      { h = heading_index($0); if (h) on = (h == 3) }
      on && !h && _fence == "" && /^[ \t]*\|/ { if (!in_t) { n++; in_t = 1 }; if (n == pick) { t = 1; next } }
      !(on && !h && _fence == "" && /^[ \t]*\|/) { in_t = 0 }
      on && t && !gone { gone = 1; if ($0 ~ /^[ \t\r]*$/) next }
      { print }' pick="$pick" "$f" > "$tmp" && cat "$tmp" > "$f"
    rm -f "$tmp"
    render "$1"
    echo "$(grep -c '^check' "$t") rows"
    ;;
  _facts)
    # M <no> <done 0|1> for rows that wait for a re-check (review-next).
    d=$(run_dir "$1") || exit 1
    t="$d/checks.tsv"
    [ -f "$t" ] || exit 0
    awk -F'\t' '$1 == "check" && $9 == 1 { printf "M %s 0\n", $2 }' "$t"
    ;;
  *) usage ;;
esac
