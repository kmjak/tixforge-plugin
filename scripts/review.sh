#!/usr/bin/env bash
# The Review of a /tixforge:dev run, kept as data (skills/dev/phase/review.md).
# Claude never edits it by hand: every change goes through a command here,
# and each command writes ## Review of state.md again from the data, for
# people to read.
#
#   review.sh round <id> <verification line>
#                     start the next round; prints its number
#   review.sh add <id> <round> <reviewer|quality> <report file>
#                     a reviewer's report (references/review.md 報告の規則):
#                     one finding per top-level "- **R1 [label]** ..." item, or
#                     no item ("指摘なし" in any language): no finding
#   review.sh own <id> <round> <finding file>
#                     a finding the implementer adds, written like a report
#                     item ("- **I1 [label]** ..." with Kind, Severity,
#                     Confidence); prints its id
#   review.sh judge <id> <round> <fid> <fix|accept|replan|reapproach> <yes|no> <note file>
#                     the recommendation, whether the fix is one way inside the
#                     agreement (yes / no), and the note shown under the
#                     finding (grounds, how to fix, what stays if accepted).
#                     Sets Auto-fix (○ × △) by the table of review.md step 6,
#                     and Decision fix (auto) / accept (auto) for ○ / ×.
#                     Prints the symbol.
#   review.sh decide <id> <round> <fid> <fix|accept|replan|reapproach> [<reason>]
#   review.sh fixed <id> <round> <fid> <hash> [--no-commit]
#   review.sh demote <id> <round> <fid> <reason>
#                     a ○ finding that cannot be fixed: Auto-fix △, no Decision
#   review.sh drop <id> <round>
#                     remove the latest round (cut short)
#   review.sh list <id> [ask|auto|all]
#                     findings, one per line: round, id, by, label, Kind,
#                     Severity, Confidence, Auto-fix, Decision, Fixed, body
#                     file. ask: △ without Decision, high Severity first (then
#                     Confidence); auto: ○ and × decided; all (default)
#   review.sh render <id>
#
# Data: .tixforge/<id>/review.tsv, tab-separated (\t, \n and \\ escaped):
#   round    <n> <verification line>
#   section  <n> <reviewer|quality>                  a report was taken in
#   finding  <n> <fid> <by> <label> <kind> <severity> <confidence> <refers>
#            <recommend> <auto_fix> <decision> <reason> <fixed>
# (- for none), and review/<n>-<fid>.md (the reviewer's item as written) and
# review/<n>-<fid>.note.md (the note). auto_fix is fix / accept / ask (○ ×
# △), decision fix, fix (auto), accept, accept (auto), replan, reapproach.
#
# Exit: 0 ok, 1 no such run, 2 usage, 3 the report or finding does not
#       follow the format (nothing is written; the problems are printed),
#       4 no such round or finding / not allowed in this state.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  grep '^#   review.sh' "$0" | sed 's/^#   //' >&2
  exit 2
}
top=$(tf_top)
tab=$(printf '\t')

KINDS_reviewer="mismatch missing out-of-scope undecided unfixed"
KINDS_quality="bug security performance error-handling test unfixed"
LEVELS="high medium low"
RECOMMENDS="fix accept replan reapproach"

# run_dir <id>: the run's folder (exit 1 without state.md).
run_dir() {
  local f
  f=$(state_file "$1" "$top")
  [ -f "$f" ] || {
    echo "no run: $1" >&2
    exit 1
  }
  dirname "$f"
}
one_of() {
  local v
  for v in $2; do [ "$v" = "$1" ] && return 0; done
  return 1
}

# The escapes of a field: \ -> \\, tab -> \t, newline -> \n.
_tsv_awk='
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

# last_round <tsv>: the number of the latest round, or 0.
last_round() {
  [ -f "$1" ] || {
    echo 0
    return
  }
  awk -F'\t' '$1 == "round" { n = $2 } END { print n + 0 }' "$1"
}

# finding_field <tsv> <round> <fid> <field index>: one field of a finding
# (escaped), nothing when there is no such finding.
finding_field() {
  awk -F'\t' -v r="$2" -v id="$3" -v k="$4" '$1 == "finding" && $2 == r && $3 == id { print $k; exit }' "$1"
}

# set_fields <tsv> <round> <fid> <index>=<value>...: rewrite fields of a
# finding (values are escaped here).
set_fields() {
  local t=$1 r=$2 id=$3 tmp a
  shift 3
  tmp=$(mktemp) || exit 1
  a=""
  for kv in "$@"; do a="$a${a:+$tab}$kv"; done
  SF_SET=$a LC_ALL=C awk -F'\t' -v OFS='\t' -v r="$r" -v id="$id" "$_tsv_awk"'
    BEGIN { n = split(ENVIRON["SF_SET"], kv, "\t"); for (i = 1; i <= n; i++) { p = index(kv[i], "="); want[substr(kv[i], 1, p - 1) + 0] = esc(substr(kv[i], p + 1)) } }
    $1 == "finding" && $2 == r && $3 == id { for (k in want) $k = want[k] }
    { print }' "$t" > "$tmp" && cat "$tmp" > "$t"
  rm -f "$tmp"
}

# render <id>: ## Review of state.md from the data. Lines that start with
# "> " at the end of the section (notes such as the automatic gate pass)
# stay after the rounds.
render() {
  local d f t tmp lang
  d=$(run_dir "$1") || exit 1
  f="$d/state.md"
  t="$d/review.tsv"
  lang=$(user_lang "$top")
  tmp=$(mktemp) || exit 1
  RV_TSV=$t RV_DIR="$d/review" RV_REVIEWER="$(msg review_section_reviewer "$lang")" \
  RV_QUALITY="$(msg review_section_quality "$lang")" RV_ADDED="$(msg review_section_added "$lang")" \
  RV_NONE="$(msg review_none "$lang")" LC_ALL=C awk "$_section_awk$_tsv_awk"'
    function slurp(p,   l, s) { s = ""; while ((getline l < p) > 0) s = s l "\n"; close(p); return s }
    function indent(s,   n, i, a, o) { n = split(s, a, "\n"); o = ""; for (i = 1; i <= n; i++) if (a[i] != "") o = o "  " a[i] "\n"; return o }
    function sym(a) { return a == "fix" ? "○" : a == "accept" ? "×" : a == "ask" ? "△" : "" }
    function one(r, j,   b, out) {
      b = slurp(ENVIRON["RV_DIR"] "/" r "-" fid[j] ".md"); sub(/\n+$/, "\n", b); out = b
      out = out indent(slurp(ENVIRON["RV_DIR"] "/" r "-" fid[j] ".note.md"))
      if (af[j] != "-") out = out "  - Auto-fix: " sym(af[j]) "\n"
      if (dec[j] != "-") out = out "  - Decision: " dec[j] (rsn[j] != "-" ? " " unesc(rsn[j]) : "") "\n"
      else if (rsn[j] != "-") out = out "  - " unesc(rsn[j]) "\n"
      if (fx[j] != "-") out = out "  - Fixed @ " fx[j] "\n"
      return out
    }
    function body(   r, j, s, k, by, label, any) {
      s = ""
      for (k = 1; k <= nr; k++) {
        r = rn[k]
        s = s "### Round " r "\n" ver[r] "\n"
        split("reviewer quality implementer", order, " ")
        for (o = 1; o <= 3; o++) {
          by = order[o]
          label = by == "reviewer" ? ENVIRON["RV_REVIEWER"] : by == "quality" ? ENVIRON["RV_QUALITY"] : ENVIRON["RV_ADDED"]
          any = 0
          for (j = 1; j <= nf; j++) if (fr[j] == r && fb[j] == by) any = 1
          if (!any && !((r SUBSEP by) in sec)) continue
          s = s "\n#### " label "\n"
          if (!any) { s = s ENVIRON["RV_NONE"] "\n"; continue }
          for (j = 1; j <= nf; j++) if (fr[j] == r && fb[j] == by) s = s one(r, j)
        }
        s = s "\n"
      }
      return s
    }
    BEGIN {
      t = ENVIRON["RV_TSV"]
      while ((getline l < t) > 0) {
        split(l, x, "\t")
        if (x[1] == "round") { rn[++nr] = x[2]; ver[x[2]] = unesc(x[3]) }
        else if (x[1] == "section") sec[x[2], x[3]] = 1
        else if (x[1] == "finding") { nf++; fr[nf] = x[2]; fid[nf] = x[3]; fb[nf] = x[4]; af[nf] = x[11]; dec[nf] = x[12]; rsn[nf] = x[13]; fx[nf] = x[14] }
      }
    }
    { h = heading_index($0) }
    h && on { printf "%s", body(); printf "%s", notes; on = 0 }
    h == 5 { print; print ""; on = 1; notes = ""; next }
    on { if ($0 ~ /^> /) notes = notes $0 "\n"; next }
    { print }
    END { if (on) { printf "%s", body(); printf "%s", notes } }' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

# parse <file> <prefix> <kinds>: the items of a report as lines
#   <fid> TAB <label> TAB <kind> TAB <severity> TAB <confidence> TAB <refers> TAB <start> TAB <end>
# (line numbers of the item), or "error: <text>" lines.
parse() {
  LC_ALL=C awk -v pre="$2" -v kinds=" $3 " -v levels=" $LEVELS " '
    function close_item() {
      if (!open) return
      if (kind == "") print "error: " fid ": no Kind line"
      else if (index(kinds, " " kind " ") == 0) print "error: " fid ": Kind " kind " is not one of" kinds
      if (index(levels, " " sev " ") == 0) print "error: " fid ": Severity must be high, medium or low"
      if (index(levels, " " conf " ") == 0) print "error: " fid ": Confidence must be high, medium or low"
      if (kind == "unfixed" && refers == "") print "error: " fid ": an unfixed finding needs Refers: Round N <id>"
      if (seen[fid]++) print "error: " fid ": the same id twice"
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\n", fid, label, kind, sev, conf, (refers == "" ? "-" : refers), start, last
      open = 0
    }
    { sub(/\r$/, "") }
    /^ ? ? ?(```|~~~)/ { fence = !fence }
    !fence && /^- / {
      close_item()
      if (match($0, /^- \*\*[A-Z][0-9]+ \[[^]]*\]\*\*/)) {
        t = substr($0, 5); fid = substr(t, 1, index(t, " ") - 1)
        t = substr(t, index(t, "[") + 1); label = substr(t, 1, index(t, "]") - 1)
        if (substr(fid, 1, 1) != pre) print "error: " fid ": ids of this report start with " pre
        open = 1; start = NR; last = NR; kind = ""; sev = ""; conf = ""; refers = ""
      } else print "error: line " NR ": a top-level item that is not - **" pre "<n> [label]** ..."
      next
    }
    open && /[^ \t]/ { last = NR }
    open && /^[ \t]+- Kind:/ { kind = $0; sub(/^[ \t]+- Kind:[ \t]*/, "", kind); sub(/[ \t]+$/, "", kind) }
    open && /^[ \t]+- Severity:/ { sev = $0; sub(/^[ \t]+- Severity:[ \t]*/, "", sev); sub(/[ \t]+$/, "", sev) }
    open && /^[ \t]+- Confidence:/ { conf = $0; sub(/^[ \t]+- Confidence:[ \t]*/, "", conf); sub(/[ \t]+$/, "", conf) }
    open && /^[ \t]+- Refers:/ { refers = $0; sub(/^[ \t]+- Refers:[ \t]*/, "", refers); sub(/[ \t]+$/, "", refers) }
    END { close_item() }' "$1"
}

# take <id> <round> <by> <file> <prefix> <kinds>: add the parsed items.
take() {
  local d t out errs
  d=$(run_dir "$1") || exit 1
  t="$d/review.tsv"
  out=$(parse "$4" "$5" "$6")
  errs=$(printf '%s\n' "$out" | grep '^error: ' || true)
  [ -z "$errs" ] || {
    printf '%s\n' "$errs" >&2
    exit 3
  }
  # Ids already taken in the round.
  printf '%s\n' "$out" | while IFS="$tab" read -r id _; do
    [ -n "$id" ] || continue
    [ -z "$(finding_field "$t" "$2" "$id" 3)" ] || {
      echo "error: $id is already in Round $2" >&2
      exit 3
    }
  done || exit 3
  mkdir -p "$d/review"
  printf '%s\n' "$out" | while IFS="$tab" read -r id label kind sev conf refers start end; do
    [ -n "$id" ] || continue
    sed -n "${start},${end}p" "$4" | tr -d '\r' > "$d/review/$2-$id.md"
    : > "$d/review/$2-$id.note.md"
    printf 'finding\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t-\t-\t-\t-\t-\n' "$2" "$id" "$3" "$label" "$kind" "$sev" "$conf" "$refers" >> "$t"
  done
}

# check_round <tsv> <round>: exit 4 unless the round exists.
check_round() {
  [ -f "$1" ] && awk -F'\t' -v r="$2" '$1 == "round" && $2 == r { f = 1 } END { exit !f }' "$1" || {
    echo "no Round $2" >&2
    exit 4
  }
}
# check_finding <tsv> <round> <fid>
check_finding() {
  [ -n "$(finding_field "$1" "$2" "$3" 3)" ] || {
    echo "no finding Round $2 $3" >&2
    exit 4
  }
}

cmd=${1:-}
[ $# -ge 1 ] && shift
case $cmd in
  round)
    [ $# -eq 2 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    n=$(($(last_round "$t") + 1))
    printf 'round\t%s\t%s\n' "$n" "$(printf '%s' "$2" | tr '\t\n\r' '   ')" >> "$t"
    render "$1"
    echo "$n"
    ;;
  add)
    [ $# -eq 4 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_round "$t" "$2"
    case $3 in
      reviewer) pre=R kinds=$KINDS_reviewer ;;
      quality) pre=Q kinds=$KINDS_quality ;;
      *) usage ;;
    esac
    [ -f "$4" ] || usage
    awk -F'\t' -v r="$2" -v by="$3" '$1 == "section" && $2 == r && $3 == by { f = 1 } END { exit !f }' "$t" && {
      echo "Round $2 already has the $3 report" >&2
      exit 4
    }
    take "$1" "$2" "$3" "$4" "$pre" "$kinds"
    printf 'section\t%s\t%s\n' "$2" "$3" >> "$t"
    render "$1"
    awk -F'\t' -v r="$2" -v by="$3" '$1 == "finding" && $2 == r && $4 == by { n++ } END { printf "Round %s %s: %d findings\n", r, by, n }' "$t"
    ;;
  own)
    [ $# -eq 3 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_round "$t" "$2"
    [ -f "$3" ] || usage
    n=$(awk -F'\t' -v r="$2" '$1 == "finding" && $2 == r && $3 ~ /^I[0-9]+$/ { k = substr($3, 2) + 0; if (k > m) m = k } END { print m + 1 }' "$t")
    tmp=$(mktemp) || exit 1
    # The id is given here: the item's own one is replaced.
    LC_ALL=C sed "1s/^- \*\*[A-Z][0-9]* \[/- **I$n [/" "$3" > "$tmp"
    take "$1" "$2" implementer "$tmp" I "$KINDS_reviewer $KINDS_quality"
    rm -f "$tmp"
    render "$1"
    echo "I$n"
    ;;
  judge)
    [ $# -eq 6 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_finding "$t" "$2" "$3"
    one_of "$4" "$RECOMMENDS" || usage
    case $5 in yes | no) ;; *) usage ;; esac
    [ -f "$6" ] || usage
    case $(finding_field "$t" "$2" "$3" 12) in fix | accept | replan | reapproach)
      echo "Round $2 $3 is already decided by the user" >&2
      exit 4
      ;;
    esac
    kind=$(finding_field "$t" "$2" "$3" 6)
    sev=$(finding_field "$t" "$2" "$3" 7)
    conf=$(finding_field "$t" "$2" "$3" 8)
    if [ "$kind" = unfixed ]; then
      af=ask
    elif [ "$4" = fix ] && [ "$5" = yes ] && [ "$conf" != low ] && [ "$2" -le 2 ]; then
      af=fix
    elif [ "$4" = accept ] && [ "$sev" != high ]; then
      af=accept
    else
      af=ask
    fi
    case $af in fix) dec="fix (auto)" ;; accept) dec="accept (auto)" ;; *) dec=- ;; esac
    tr -d '\r' < "$6" > "$d/review/$2-$3.note.md"
    set_fields "$t" "$2" "$3" "10=$4" "11=$af" "12=$dec" "13=-"
    render "$1"
    case $af in fix) echo "Auto-fix: ○" ;; accept) echo "Auto-fix: ×" ;; *) echo "Auto-fix: △" ;; esac
    ;;
  decide)
    [ $# -ge 4 ] && [ $# -le 5 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_finding "$t" "$2" "$3"
    one_of "$4" "$RECOMMENDS" || usage
    set_fields "$t" "$2" "$3" "12=$4" "13=${5:--}"
    render "$1"
    ;;
  fixed)
    [ $# -ge 4 ] && [ $# -le 5 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_finding "$t" "$2" "$3"
    case $(finding_field "$t" "$2" "$3" 12) in fix | "fix (auto)") ;; *)
      echo "Round $2 $3 is not decided fix" >&2
      exit 4
      ;;
    esac
    case $4 in *[!0-9a-f]* | "") usage ;; esac
    v=$4
    [ "${5:-}" = --no-commit ] && v="$4 (no commit)"
    [ -z "${5:-}" ] || [ "$5" = --no-commit ] || usage
    set_fields "$t" "$2" "$3" "14=$v"
    render "$1"
    ;;
  demote)
    [ $# -eq 4 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_finding "$t" "$2" "$3"
    [ "$(finding_field "$t" "$2" "$3" 11)" = fix ] || {
      echo "Round $2 $3 is not ○" >&2
      exit 4
    }
    set_fields "$t" "$2" "$3" "11=ask" "12=-" "13=$4"
    render "$1"
    ;;
  drop)
    [ $# -eq 2 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    check_round "$t" "$2"
    [ "$2" = "$(last_round "$t")" ] || {
      echo "only the latest round can be dropped" >&2
      exit 4
    }
    tmp=$(mktemp) || exit 1
    awk -F'\t' -v r="$2" '$1 != "round" && $1 != "section" && $1 != "finding" || $2 != r' "$t" > "$tmp" && cat "$tmp" > "$t"
    rm -f "$tmp" "$d/review/$2-"*
    render "$1"
    ;;
  list)
    [ $# -ge 1 ] && [ $# -le 2 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    [ -f "$t" ] || exit 0
    case ${2:-all} in ask | auto | all) ;; *) usage ;; esac
    LC_ALL=C awk -F'\t' -v OFS='\t' -v w="${2:-all}" -v dir="${d#"$top"/}/review" "$_tsv_awk"'
      function rank(v) { return v == "high" ? 1 : v == "medium" ? 2 : 3 }
      $1 != "finding" { next }
      w == "ask" && !($11 == "ask" && $12 == "-") { next }
      w == "auto" && $12 != "fix (auto)" && $12 != "accept (auto)" { next }
      { print rank($7) rank($8), $2, $3, $4, unesc($5), $6, $7, $8, $11, $12, $14, dir "/" $2 "-" $3 ".md" }' "$t" \
      | { if [ "${2:-all}" = ask ]; then sort -t"$tab" -k1,1 -k2,2n; else sort -t"$tab" -k2,2n; fi; } | cut -f2-
    ;;
  render)
    [ $# -eq 1 ] || usage
    run_dir "$1" > /dev/null
    render "$1"
    ;;
  _import)
    # migrate (format 3 -> 4): ## Review as written by hand, into the data.
    # Rounds, their Verification line, the #### sections (first: reviewer,
    # second: quality, more: implementer), each top-level item with its
    # Auto-fix, Decision and Fixed @ lines; the other lines of an item are
    # its body. An item without an id is the implementer's (I<n>). 3.0's
    # decision line ("- 決定：修正", "- Decision: Fix") becomes Decision;
    # its 修正 counts as fixed ("Fixed @ 3.0"), except in the latest round
    # when HEAD is still that round's Verification (3.0 fixed after the round).
    # Prints the number of rounds.
    [ $# -eq 1 ] || usage
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    [ ! -s "$t" ] || {
      echo "review.tsv already exists" >&2
      exit 4
    }
    mkdir -p "$d/review"
    head=$(git -C "$top" rev-parse HEAD 2> /dev/null || true)
    RV_DIR="$d/review" RV_HEAD=$head LC_ALL=C awk "$_section_awk$_tsv_awk"'
      function word(t) {
        if (t ~ /^(fix \(auto\))/) return "fix (auto)"; if (t ~ /^(accept \(auto\))/) return "accept (auto)"
        if (t ~ /^([Ff]ix|修正)/) return "fix"; if (t ~ /^([Aa]ccept|受け入れ)/) return "accept"
        if (t ~ /^([Rr]eplan|計画の見直し)/) return "replan"; if (t ~ /^([Rr]eapproach|方針の見直し)/) return "reapproach"
        return ""
      }
      function close_item() {
        if (!open) return
        f = ENVIRON["RV_DIR"] "/" round "-" fid ".md"
        printf "%s", body > f; close(f); printf "" > (ENVIRON["RV_DIR"] "/" round "-" fid ".note.md")
        rows[++n] = "finding\t" round "\t" fid "\t" fby "\t" esc(lab) "\t-\t-\t-\t-\t-\t" (af == "" ? "-" : af) "\t" (dec == "" ? "-" : dec) "\t" (rsn == "" ? "-" : esc(rsn)) "\t" (fx == "" ? (legacy && dec == "fix" ? "3.0" : "-") : fx)
        rr[n] = round
        if (legacy && dec == "fix" && fx == "") lastfix[round] = lastfix[round] " " n
        open = 0
      }
      function close_round() { close_item(); round = "" }
      {
        line = $0; sub(/\r$/, "", line)
        h = heading_index(line)
        if (h) { if (inrev) close_round(); inrev = (h == 5); next }
        if (!inrev) next
        if (_fence == "" && line ~ /^### Round [0-9]+[ \t]*$/) {
          close_round(); round = line; sub(/^### Round /, "", round); sub(/[ \t]+$/, "", round)
          rows[++n] = "round\t" round "\t-"; rr[n] = round; rl[round] = n; nsec = 0; nr++; latest = round; next
        }
        if (round == "") next
        if (_fence == "" && line ~ /^Verification @ / && !(round in vset)) { vset[round] = 1; rows[rl[round]] = "round\t" round "\t" esc(line); v = line; sub(/^Verification @ /, "", v); sub(/[+: ].*$/, "", v); vh[round] = v; next }
        if (_fence == "" && line ~ /^#### /) { close_item(); nsec++; by = nsec == 1 ? "reviewer" : nsec == 2 ? "quality" : "implementer"; pend = nsec <= 2; next }
        # A reviewer section counts once it has a line (a finding or "指摘なし").
        if (pend && line ~ /[^ \t]/ && line !~ /^> /) { rows[++n] = "section\t" round "\t" by; rr[n] = round; pend = 0 }
        if (_fence == "" && line ~ /^- /) {
          close_item(); open = 1; body = ""; af = ""; dec = ""; rsn = ""; fx = ""; legacy = 0; lab = ""
          if (match(line, /^- \*\*[A-Z][0-9]+ \[[^]]*\]\*\*/)) {
            t = substr(line, 5); fid = substr(t, 1, index(t, " ") - 1); t = substr(t, index(t, "[") + 1); lab = substr(t, 1, index(t, "]") - 1); fby = by
          } else { fid = "I" (++ni[round]); fby = "implementer" }
          body = line "\n"; next
        }
        if (!open) next
        if (_fence != "" || line ~ /^ ? ? ?(```|~~~)/) { body = body line "\n"; next }
        if (line ~ /^[ \t]*- Auto-fix:/) { if (index(line, "○")) af = "fix"; else if (index(line, "×")) af = "accept"; else if (index(line, "△")) af = "ask"; next }
        if (line ~ /^[ \t]*- Decision:/) { t = line; sub(/^[ \t]*- Decision:[ \t]*/, "", t); dec = word(t); r = t; sub(/^(fix|accept) \(auto\)|^[A-Za-z]+/, "", r); sub(/^[ \t]*(—|-)?[ \t]*/, "", r); rsn = r; next }
        if (line ~ /^[ \t]*- 決定(：|:)/) { t = line; sub(/^[ \t]*- 決定(：|:)[ \t]*/, "", t); dec = word(t); r = t; sub(/^(修正|受け入れ|計画の見直し|方針の見直し|[A-Za-z]+)/, "", r); sub(/^[ \t]*(—|-|：|:)?[ \t]*/, "", r); rsn = r; legacy = 1; next }
        if (line ~ /^[ \t]*- Fixed @ /) { t = line; sub(/^[ \t]*- Fixed @ /, "", t); fx = t; next }
        body = body line "\n"
      }
      END {
        if (inrev) close_round()
        # 3.0 fixed after its round: the latest round not followed by a commit is not fixed yet.
        if (latest != "" && vh[latest] != "" && index(ENVIRON["RV_HEAD"], vh[latest]) == 1 && lastfix[latest] != "") {
          k = split(lastfix[latest], ix, " "); for (i = 1; i <= k; i++) sub(/\t3\.0$/, "\t-", rows[ix[i] + 0])
        }
        for (i = 1; i <= n; i++) print rows[i]
        print nr + 0 > "/dev/stderr"
      }' "$d/state.md" > "$t" 2> "$d/.import-count"
    cat "$d/.import-count"
    rm -f "$d/.import-count"
    [ -s "$t" ] || rm -f "$t"
    [ -f "$t" ] && render "$1"
    ;;
  # Internal: run-state.sh reads these.
  _facts)
    # R <round> <hash or -> <cut short 0|1>; F <round> <auto_fix|-> <decision|-> <fixed|->
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    [ -f "$t" ] || exit 0
    LC_ALL=C awk -F'\t' '
      $1 == "round" { rn[++nr] = $2; v = $3; sub(/^Verification @ /, "", v); sub(/[+: ].*$/, "", v); vh[$2] = (v ~ /^[0-9a-f]+$/ ? v : "-") }
      $1 == "section" { sec[$2, $3] = 1 }
      $1 == "finding" { d = $12; gsub(/ /, "", d); f[++nf] = "F " $2 " " ($11 == "-" ? "-" : $11) " " d " " ($14 == "-" ? "-" : substr($14, 1, index($14 " ", " ") - 1)) }
      END {
        for (k = 1; k <= nr; k++) printf "R %s %s %d\n", rn[k], vh[rn[k]], !((rn[k] SUBSEP "reviewer") in sec && (rn[k] SUBSEP "quality") in sec)
        for (k = 1; k <= nf; k++) print f[k]
      }' "$t"
    ;;
  _rounds)
    # <round> TAB <findings JSON> TAB <unjudged count>, for the review_round event.
    d=$(run_dir "$1") || exit 1
    t="$d/review.tsv"
    [ -f "$t" ] || exit 0
    LC_ALL=C awk -F'\t' "$_tsv_awk"'
      function js(s,   o, i, c) { o = ""; for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "\\" || c == "\"") o = o "\\" c; else o = o c } return "\"" o "\"" }
      function jn(s) { return s == "-" ? "null" : js(s) }
      $1 == "round" { rn[++nr] = $2 }
      $1 == "finding" {
        if ($11 == "-") { un[$2]++; next }
        it[$2] = it[$2] (it[$2] == "" ? "" : ",") "{\"id\":" js($4 == "implementer" ? "" : $3) ",\"label\":" js($4 == "implementer" ? "" : unesc($5)) ",\"auto_fix\":" js($11) ",\"decision\":" jn($12) ",\"fixed\":" jn($14 == "-" ? "-" : substr($14, 1, index($14 " ", " ") - 1)) "}"
      }
      END { for (k = 1; k <= nr; k++) printf "%s\t[%s]\t%d\n", rn[k], it[rn[k]], un[rn[k]] + 0 }' "$t"
    ;;
  *) usage ;;
esac
