#!/usr/bin/env bash
# Tests of project-status.sh (tests/scripts/lib.sh sets up).
set -u
# shellcheck source=tests/scripts/lib.sh
. "$(dirname "$0")/lib.sh"
run_901

# --- project-status.sh -------------------------------------------------------------
section="project-status.sh"
out=$(bash "$scripts/project-status.sh")
has "tracker=github" "$out" "config"
has "gates=approach,plan,pr" "$out" "gates"
has "GT-000901: Status implement:in-progress、Branch GT-000901-a" "$out" "open run, with its Branch"
out=$(cd "$tmp" && bash "$scripts/project-status.sh")
eq 0 $? "outside a repo exits 0"
has "config.yml が無い" "$out" "no config"
cp .tixforge/config.yml "$tmp/keep-gates.yml"
sed 's/^gates: .*/gates: []/' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "gates=[]（pr のみ）" "$(bash "$scripts/project-status.sh")" "explicit empty gates"
grep -v '^gates:' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "gates=（未設定）" "$(bash "$scripts/project-status.sh")" "missing gates"
# init writes config.yml one answer at a time: a config with a single key
# (stopped part way) still reads.
printf 'language: ja\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
eq 0 $? "a partial config.yml exits 0"
has "gates=（未設定）" "$out" "a partial config.yml shows the missing keys"
has "init が途中（無いキー：repository.base_branch、commands、ticket.tracker）" "$out" "a partial config.yml says init stopped part way"
printf 'repository:\n  base_branch: main\n  close_issues: release\ncommands: {}\nticket:\n  tracker: github\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
eq 0 $? "a v2 config with close_issues still reads"
case "$out" in *close_issues*) ng "close_issues is no longer shown" ;; *) ok ;; esac
printf 'repository:\n  base_branch: main\ncommands: {}\nticket:\n  tracker: github\n' > .tixforge/config.yml
case "$(bash "$scripts/project-status.sh")" in *init*途中*) ng "the keys init needs are there" ;; *) ok ;; esac
git rm -q --cached .tixforge/config.yml
has "init が途中（config.yml が commit されていない）" "$(bash "$scripts/project-status.sh")" "an uncommitted config.yml means init has not finished"
git add .tixforge/config.yml
case "$out" in *移行が要る*) ng "a partial config.yml needs no migration" ;; *) ok ;; esac
cp "$tmp/keep-gates.yml" .tixforge/config.yml
has "この人が使う値: language=ja（config.yml） gates=approach,plan,pr（config.yml）" "$(bash "$scripts/project-status.sh")" "personal values from config.yml"
printf 'language: en\ngates: []\n' > .tixforge/config.local.yml
has "この人が使う値: language=en（config.local.yml） gates=[]（pr のみ）（config.local.yml）" "$(bash "$scripts/project-status.sh")" "personal values from config.local.yml"
printf 'language: en\n' > .tixforge/config.local.yml
has "language=en（config.local.yml） gates=approach,plan,pr（config.yml）" "$(bash "$scripts/project-status.sh")" "a local language with the team's gates"
rm -f .tixforge/config.local.yml
grep -v '^language:' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "language=ja（既定）" "$(bash "$scripts/project-status.sh")" "a language nobody wrote is the default"
cp "$tmp/keep-gates.yml" .tixforge/config.yml
# What v2 left: local tickets, tracker: local, host: none.
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "nothing to migrate" ;; *) ok ;; esac
mkdir -p .tixforge/LT-000003
printf '# LT-000003: A\n\n## 背景\n' > .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a local ticket to move"
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a canceled local ticket needs nothing" ;; *) ok ;; esac
printf '# LT-000003: A\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | done |\n' > .tixforge/LT-000003/state.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a done local run needs nothing" ;; *) ok ;; esac
printf '| Field | Value |\n|---|---|\n| Status | plan:awaiting-approval |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a local run in progress"
bash "$scripts/run-state.sh" set LT-000003 Status canceled > /dev/null && ok || ng "run-state set on a local run"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "update closes a local run with run-state set" ;; *) ok ;; esac
printf '| Field | Value |\n|---|---|\n| Status | pr:awaiting-review |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
bash "$scripts/run-state.sh" set LT-000003 Status done > /dev/null && ok || ng "a local run with a PR is finished by hand"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "update closes a local run with run-state set" ;; *) ok ;; esac
# A move stopped halfway: the ticket is canceled, the run is still open.
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | implement:in-progress |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "a canceled ticket with an open run"
# A run with no ticket.md.
rm .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "an open run with no ticket"
rm .tixforge/LT-000003/state.md
# Only the header says canceled: a "Status: canceled" line in the body does not.
printf '# LT-000003: A\n\n## 背景\n```\nStatus: canceled\n```\n' > .tixforge/LT-000003/ticket.md
has "移行が要る: LT-000003（" "$(bash "$scripts/project-status.sh")" "Status: canceled in the body is not the header"
printf '# LT-000003: A\r\nStatus: canceled\r\n\r\n## 背景\r\n' > .tixforge/LT-000003/ticket.md
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a canceled ticket with CRLF" ;; *) ok ;; esac
# Before init (no config.yml) nothing is reported: init comes first.
printf '# LT-000003: A\n' > .tixforge/LT-000003/ticket.md
mv .tixforge/config.yml "$tmp/no-conf.yml"
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "no migration before init" ;; *) ok ;; esac
mv "$tmp/no-conf.yml" .tixforge/config.yml
rm -rf .tixforge/LT-000003
# project-status.sh lt: the folders to move, the same ones counted above.
mkdir -p .tixforge/LT-000003
printf '# LT-000003: A\nStatus: canceled\nReason: GT-000061 に移した\n' > .tixforge/LT-000003/ticket.md
printf '| Field | Value |\n|---|---|\n| Status | pr:awaiting-review |\n| Updated | 2026-10-21 16:40 |\n' > .tixforge/LT-000003/state.md
mkdir -p .tixforge/LT-000005 .tixforge/LT-000006/history
printf '# LT-000005: B\n\n## 背景\n' > .tixforge/LT-000005/ticket.md
printf '| Field | Value |\n|---|---|\n| Branch | x |\n' > .tixforge/LT-000006/state.md
eq "$(printf 'LT-000003\tpr:awaiting-review\tcanceled\tGT-000061 に移した\nLT-000005\t-\topen\t\nLT-000006\t?\tnone\t')" \
  "$(bash "$scripts/project-status.sh" lt)" "lt lists each folder to move"
has "移行が要る: LT-000003 LT-000005 LT-000006（" "$(bash "$scripts/project-status.sh")" "the summary counts the same folders"
rm -rf .tixforge/LT-000003 .tixforge/LT-000005 .tixforge/LT-000006
mkdir -p ".tixforge/LT-000007 copy"
printf '# LT-000007: C\nStatus: canceled\nReason: a\tb\n' > ".tixforge/LT-000007 copy/ticket.md"
printf '| Field | Value |\n|---|---|\n| Status | plan:in-progress |\n' > ".tixforge/LT-000007 copy/state.md"
eq "$(printf 'LT-000007 copy\tplan:in-progress\tcanceled\ta b')" "$(bash "$scripts/project-status.sh" lt)" "a folder copy is listed, and a tab in Reason stays one column"
rm -rf ".tixforge/LT-000007 copy"
# Quoted values are read too.
printf 'ticket:\n  tracker: "local"\nrepository:\n  host: \x27none\x27   # v2\n' > .tixforge/config.yml
out=$(bash "$scripts/project-status.sh")
has "移行が要る: tracker: local（" "$out" "a quoted tracker: local"
has "移行が要る: repository.host: none（" "$out" "a quoted host: none"
cp "$tmp/keep-gates.yml" .tixforge/config.yml
mkdir -p .tixforge/LT-000004/history
case "$(bash "$scripts/project-status.sh")" in *移行が要る*) ng "a folder with neither file needs nothing" ;; *) ok ;; esac
sed 's/tracker: github/tracker: local/' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "移行が要る: tracker: local（" "$(bash "$scripts/project-status.sh")" "tracker: local"
printf '# LT-000004: A\n' > .tixforge/LT-000004/ticket.md
has "移行が要る: tracker: local / LT-000004（" "$(bash "$scripts/project-status.sh")" "tracker: local and a local ticket"
rm -rf .tixforge/LT-000004
awk '{ print } /^repository:$/ { print "  host: none" }' "$tmp/keep-gates.yml" > .tixforge/config.yml
has "移行が要る: repository.host: none（" "$(bash "$scripts/project-status.sh")" "host: none"
cp "$tmp/keep-gates.yml" .tixforge/config.yml

done_file
