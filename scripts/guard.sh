#!/usr/bin/env bash
# PreToolUse guard for tixforge, shipped in the tixforge plugin's hooks/hooks.json
# with the matcher Bash|Edit|Write|MultiEdit|NotebookEdit|mcp__.*[Gg][Ii][Tt].*
# (the MCP tools it looks at: their names contain git). It runs
# for those tools in every project and acts only where a tixforge run is
# involved:
#
# On a run's branch (.tixforge/*/state.md whose Branch is the current branch):
#   deny  git push --force (any form), and gh pr create whose body does not
#         close the run's issue (Closes #N)
#   ask   every other push / PR creation, whatever the phase, so the user
#         confirms on the permission prompt even when git push is on the
#         allow list; the phase is shown in the prompt
#   ask   any git / gh subcommand outside the allow list below (merge,
#         rebase, reset, gh pr merge, gh api writes, ...), all of them named,
#         and GitHub / git MCP tools that are not reads; a lone gh pr comment
#         (dev posts the verification after a fix) asks as a PR comment
#   deny  a commit / push / merge / pull / rebase / am that skips the git
#         hooks (--no-verify, commit -n, -c / --config-env / GIT_CONFIG_*
#         moving core.hooksPath or include.path); asked when seen only with
#         the quotes removed, or through a hook tool's variable (HUSKY=0, SKIP=)
# On the Base of an open run (the branch a run merges into):
#   the same, and a commit on the Base asks too (work goes on ticket branches)
# On the branch of a run in Implement or pr:in-progress, editing an existing
#   lint / formatter / type-check / git hook config of the repository
#   (eslint, prettier, tsconfig, ruff, golangci, .husky/, pre-commit, ...)
#   asks: loosening the checks to pass them is not allowed (run.md), and a
#   planned change is confirmed on the prompt. pyproject.toml and CI
#   workflows hold more than checks, so they are left alone.
# While a run is before Implement (research / approach / plan), editing a
#   file of the repository outside docs/ and .tixforge/ asks: nothing is
#   implemented before the Plan is approved. Not on the branch of a run that
#   is already implementing, where that run's own work goes on.
#
# Detection is deliberately loose (quotes stripped, bash -c / eval / env
# forms, git + push anywhere) because a false positive only costs a prompt.
# It is accident prevention, not a sandbox: any command Claude can run can
# be written so that it is not recognised.
#
# Output: nothing + exit 0 = no decision (normal permission flow).
# exit 2 = deny; stderr goes to Claude. JSON on stdout = ask; the reason
# goes to the user only.
set -uo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

input=$(cat)
tool=$(printf '%s' "$input" | json_get tool_name)

# Cheap pre-filters: most calls never reach git.
case "$tool" in
  Bash | '') case "$input" in *git* | *gh*) ;; *) exit 0 ;; esac ;;
  Edit | Write | MultiEdit | NotebookEdit | mcp__*) ;;
  *) exit 0 ;;
esac
case "$tool" in mcp__*) case "$tool" in *[Gg][Ii][Tt]*) ;; *) exit 0 ;; esac ;; esac

deny() {
  {
    echo "[tixforge guard] $1"
    echo "この操作は tixforge のルールでブロックされました。コマンドを言い換えて回避せず、理由をユーザーに伝えて指示を待ってください。"
  } >&2
  exit 2
}

ask() {
  local reason
  reason=$(printf '[tixforge] %s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

cwd=$PWD
c=$(printf '%s' "$input" | json_get cwd)
[ -n "$c" ] && cwd=$c

top=$(git -C "$cwd" rev-parse --show-toplevel 2> /dev/null) || exit 0

# --- Edit / Write before the Plan is approved ------------------------------

case "$tool" in
  Edit | Write | MultiEdit | NotebookEdit)
    early=""
    own=""
    cur=$(git -C "$cwd" symbolic-ref --short -q HEAD 2> /dev/null || true)
    while IFS="$RUN_SEP" read -r id s b _; do
      [ -n "$id" ] || continue
      if is_early_status "$s"; then
        early="${early}${early:+、}${id}（${s}）"
        continue
      fi
      # On the branch of a run past its Plan: that run's work.
      case "$s" in implement:* | review:* | pr:*)
        if [ -n "$cur" ] && [ "$b" = "$cur" ]; then
          own="${id}（${s}）"
          break
        fi
        ;;
      esac
    done << EOF
$(each_run "$top")
EOF
    # Implement, and the PR phase, where CI failures and review comments are
    # fixed on the branch.
    case "$own" in "" | *"（implement:"* | *"（pr:in-progress）") ;; *) exit 0 ;; esac
    [ -n "$early" ] || [ -n "$own" ] || exit 0
    path=$(printf '%s' "$input" | json_get tool_input.file_path)
    [ -n "$path" ] || path=$(printf '%s' "$input" | json_get tool_input.notebook_path)
    if [ -n "$own" ]; then
      # Implement: only an existing check config inside the repository asks
      # (by the name it is edited under: a symlink's target is not looked at).
      case "$path" in /*) ;; *) path="$cwd/$path" ;; esac
      [ -f "$path" ] || exit 0
      path="$(cd "${path%/*}" && pwd -P)/${path##*/}"
      case "$path" in "$top"/*) ;; *) exit 0 ;; esac
      case "$path" in
        "$top"/.git/hooks/* | "$top"/.git/config | */.husky/*) ;;
        "$top"/.git/*) exit 0 ;;
        *)
          case "${path##*/}" in
            .eslintrc* | eslint.config.* | .eslintignore | .prettierrc* | prettier.config.* | .prettierignore | biome.json | biome.jsonc | \
              tsconfig*.json | jsconfig*.json | tslint.json | .jshintrc | .oxlintrc.json | dprint.json | deno.json | deno.jsonc | \
              ruff.toml | .ruff.toml | .flake8 | .pylintrc | pylintrc | mypy.ini | .mypy.ini | pyrightconfig.json | \
              .golangci.yml | .golangci.yaml | .golangci.toml | .golangci.json | .rubocop.yml | .rubocop_todo.yml | \
              .stylelintrc* | stylelint.config.* | .stylelintignore | .markdownlint* | .yamllint* | .shellcheckrc | \
              rustfmt.toml | .rustfmt.toml | clippy.toml | .clang-format | .clang-tidy | .swiftlint.yml | .swiftformat | detekt.yml | \
              phpstan.neon* | .php-cs-fixer* | phpcs.xml* | \
              .pre-commit-config.yaml | lefthook.yml | lefthook.yaml | .lefthook.yml | .lintstagedrc* | lint-staged.config.*) ;;
            *) exit 0 ;;
          esac
          ;;
      esac
      ask "run ${own} で、lint・formatter・型チェック・git hook の設定（${path#"$top"/}）を編集しようとしています。Plan にある変更か確かめてください。テストや lint を通すために検査を緩める変更（ルールの無効化・除外の追加・strict を外すなど）なら止めてください（run.md）。承認しますか？"
    fi
    [ -n "$path" ] || ask "Plan の承認前の run があります：${early}。hook の入力から編集するファイルを読み取れなかったため、docs/・.tixforge/ の中かを判定できません。承認しますか？"
    case "$path" in /*) ;; *) path="$cwd/$path" ;; esac
    # Resolve symlinks (/tmp, /var on macOS) through the nearest existing
    # directory, as git does for the toplevel; the file may not exist yet.
    d=$path
    tail=""
    while [ ! -d "$d" ]; do
      tail="/${d##*/}$tail"
      d=${d%/*}
      [ -n "$d" ] || d=/
    done
    path="$(cd "$d" && pwd -P)$tail"
    case "$path" in
      "$top"/docs/* | "$top"/.tixforge/*) exit 0 ;;
      "$top"/*) ask "Plan の承認前の run があります：${early}。docs/・.tixforge/ 以外のファイル（${path#$top/}）を編集しようとしています。tixforge と無関係の作業なら許可してください。" ;;
      *) exit 0 ;;
    esac
    ;;
esac

# --- the run this branch belongs to ----------------------------------------

branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2> /dev/null) || exit 0

# The first run whose Branch this is (done or canceled ones too: pushing to
# a finished run's branch asks), else the first open run whose Base this is.
state=""
base_of=""
while IFS="$RUN_SEP" read -r id s b ba; do
  [ -n "$id" ] || continue
  if [ "$b" = "$branch" ]; then
    state=$(state_file "$id" "$top")
    break
  fi
  [ -z "$base_of" ] && is_open_status "$s" && [ "$ba" = "$branch" ] && base_of=$id
done << EOF
$(each_run "$top")
EOF
[ -n "$state" ] || [ -n "$base_of" ] || exit 0

if [ -n "$state" ]; then
  status=$(field "$state" Status)
  base=$(field "$state" Base)
  where="ブランチ ${branch}、Status ${status}（${state#$top/}）"
else
  where="Base ブランチ ${branch}（進行中の run ${base_of} の Base）"
fi

# --- MCP -------------------------------------------------------------------

case "$tool" in
  mcp__*)
    verb=${tool##*__}
    case "$verb" in get* | list* | search* | read* | view* | fetch*) exit 0 ;; esac
    ask "MCP の ${tool} は git / GitHub への書き込みの可能性があります。${where}。許可しますか？"
    ;;
esac

# --- Bash ------------------------------------------------------------------

cmd=$(printf '%s' "$input" | json_get tool_input.command)
# The pre-filter saw git or gh in the input, so a command we cannot read is
# asked about, not passed.
[ -n "$cmd" ] || ask "hook の入力からコマンドを読み取れなかったため、push / PR 作成かを判定できません。${where}。承認しますか？"

# Precise forms: a command segment starts at line start or after ; & | ( {
# and may be prefixed by `command`, env assignments, or git/gh options.
seg_start='(^|[;&|({])[[:space:]]*(command[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
git_push_re="${seg_start}git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+push([[:space:]]|$)"
gh_pr_create_re="${seg_start}gh([[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+pr[[:space:]]+create([[:space:]]|$)"

# Loose forms: words anywhere once quotes and backslashes are removed, so
# bash -c "git push", eval, env, "git" push and gh api .../pulls are caught.
# `stash push` is local and dropped first.
unquoted=$(printf '%s\n' "$cmd" | awk '{ if (sub(/\\$/, "")) printf "%s ", $0; else print }' | tr -d "\"'\\\\")
norm=$(printf '%s\n' "$unquoted" | sed -E 's/stash[[:space:]]+push//g')
has_word() { printf '%s\n' "$norm" | grep -Eq "(^|[^[:alnum:]_-])$1([^[:alnum:]_-]|$)"; }

is_pr_create=0
precise_pr=0
printf '%s\n' "$cmd" | grep -Eq "$gh_pr_create_re" && {
  is_pr_create=1
  precise_pr=1
}
if has_word gh && { { has_word pr && has_word create; } || { has_word api && has_word pulls; }; }; then
  is_pr_create=1
fi
is_push=0
precise_push=0
printf '%s\n' "$cmd" | grep -Eq "$git_push_re" && {
  is_push=1
  precise_push=1
}
has_word git && has_word push && is_push=1

# Allow list: every git / gh in command position must be a read or a local,
# recoverable step. The first one that is not becomes $other.
other=""
others=""
has_arg() { # has_arg <pattern>...: one of the remaining words matches
  local w p
  for w in $rest; do for p in "$@"; do
    # shellcheck disable=SC2254 # $p is a pattern on purpose
    case "$w" in $p) return 0 ;; esac
  done done
  return 1
}
git_ok() { # git_ok <sub>
  case "$1" in
    '' | push | status | diff | log | show | rev-parse | symbolic-ref | ls-files | ls-tree | ls-remote | check-ignore | merge-base | merge-tree | add | rm | mv | blame | grep | describe | cat-file | for-each-ref | rev-list | shortlog | name-rev | show-ref | diff-tree | diff-files | diff-index | help | version | --version) return 0 ;;
    commit)
      [ -z "$state" ] && return 1
      has_arg --amend && return 1
      return 0
      ;;
    # Switching and fetching are safe unless forced: -f / --discard-changes
    # throw away local changes, -C / -B reset an existing branch, and a
    # +refspec or --force overwrites a local branch.
    switch) ! has_arg -f --force --discard-changes -C '--force-create' '--force-create=*' ;;
    checkout) [ -z "$rest" ] || { has_arg -b && ! has_arg -B -f --force; } ;;
    fetch) ! has_arg '+*' '*:+*' -f --force ;;
    branch) ! has_arg '-[dDmMcCfu]' '--delete' '--move' '--copy' '--force' '--set-upstream-to*' '--unset-upstream' '--edit-description' ;;
    stash) [ -z "$rest" ] || has_arg push list show pop apply save ;;
    tag) [ -z "$rest" ] || has_arg -l '--list' ;;
    config) has_arg --get '--get-all' '--get-regexp' --list -l ;;
    remote) [ -z "$rest" ] || has_arg -v get-url show ;;
    worktree) has_arg list ;;
    *) return 1 ;;
  esac
}
gh_ok() { # gh_ok <sub> <sub2>
  case "$1 $2" in
    'pr create'*) return 0 ;; # handled above: Closes check and a prompt
    'pr view'* | 'pr list'* | 'pr checks'* | 'pr diff'* | 'pr status'*) return 0 ;;
    'issue view'* | 'issue list'* | 'issue status'*) return 0 ;;
    'run view'* | 'run list'* | 'run watch'* | 'repo view'* | 'auth status'* | 'label list'*) return 0 ;;
    'release view'* | 'release list'* | 'workflow view'* | 'workflow list'* | 'search '*) return 0 ;;
    'status '* | 'help '* | 'version '* | '--version '* | ' ') return 0 ;;
    'api '*) ! has_arg -X '--method' -f -F '--field' '--raw-field' '--input' '-X*' '--method=*' ;;
    *) return 1 ;;
  esac
}

segments=$(printf '%s\n' "$unquoted" | tr ';&|(){}`' '\n\n\n\n\n\n\n\n')
set -f
while IFS= read -r seg; do
  # shellcheck disable=SC2206 # word splitting (globbing off) is the point
  words=($seg)
  n=${#words[@]}
  i=0
  cmdpos=1
  while [ $i -lt $n ] && [ $cmdpos -eq 1 ]; do
    w=${words[$i]}
    case "$w" in
      [A-Za-z_]*=* | command | env | sudo | exec | xargs | eval | time | nohup | nice | bash | sh | zsh | -*)
        i=$((i + 1))
        continue
        ;;
      git | */git)
        j=$((i + 1))
        while [ $j -lt $n ]; do
          case "${words[$j]}" in
            -C | -c | --git-dir | --work-tree | --namespace) j=$((j + 2)) ;;
            -*) j=$((j + 1)) ;;
            *) break ;;
          esac
        done
        sub=${words[$j]:-}
        rest="${words[*]:$((j + 1))}"
        git_ok "$sub" || {
          others="${others}${others:+、}git ${sub}"
          [ -n "$other" ] || other="git ${sub}"
        }
        ;;
      gh | */gh)
        j=$((i + 1))
        while [ $j -lt $n ]; do
          case "${words[$j]}" in
            -R | --repo | --hostname) j=$((j + 2)) ;;
            -*) j=$((j + 1)) ;;
            *) break ;;
          esac
        done
        sub=${words[$j]:-}
        sub2=${words[$((j + 1))]:-}
        rest="${words[*]:$((j + 1))}"
        if ! gh_ok "$sub" "$sub2"; then
          o="gh ${sub} ${sub2}"
          [ "$o" = "gh pr comment" ] && has_arg --delete-last --edit-last && o="gh pr comment（編集・削除）"
          others="${others}${others:+、}${o}"
          [ -n "$other" ] || other=$o
        fi
        ;;
    esac
    cmdpos=0
  done
done << EOF
$segments
EOF

# --- skipping the git hooks -------------------------------------------------
# hook_skip <segment>: sets hook_deny or hook_ask when the git commit / push /
# merge / pull / rebase / am in the segment skips the hooks: --no-verify (or
# a prefix of it, which git accepts), commit -n, a config that moves the
# hooks (-c / --config-env / GIT_CONFIG_* with core.hooksPath, include.path,
# includeIf.*.path), or a hook tool's skip variable (HUSKY=0, SKIP=, ... :
# asked, as they are per tool).
hook_deny="" hook_ask=""
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
moves_hooks() {
  case "$(lc "$1")" in *core.hookspath* | *include.path* | includeif.*.path* | *"includeif."*".path"*) return 0 ;; esac
  return 1
}
hook_skip() {
  local ws n i w cfg="" tool="" j sub k a x ch vals
  # shellcheck disable=SC2206 # word splitting (globbing off) is the point
  ws=($1)
  n=${#ws[@]}
  i=0
  while [ $i -lt $n ]; do
    w=${ws[$i]}
    case "$w" in
      GIT_CONFIG_PARAMETERS=* | GIT_CONFIG_KEY_*=*) moves_hooks "${w#*=}" && cfg="$w" ;;
      HUSKY=0 | HUSKY_SKIP_HOOKS=* | LEFTHOOK=0 | SKIP=*) tool="$w" ;;
      # The options of env / sudo / timeout that take a value: skip it too.
      -u | -g | -s | -k | -C | -D | -U | -p) i=$((i + 1)) ;;
      [A-Za-z_]*=* | command | env | */env | sudo | */sudo | exec | xargs | eval | time | nohup | nice | timeout | */timeout | \
        bash | sh | zsh | if | then | do | else | elif | while | until | '!' | -* | [0-9]*) ;;
      git | */git)
        j=$((i + 1))
        while [ $j -lt $n ]; do
          case "${ws[$j]}" in
            -c | --config-env)
              moves_hooks "${ws[$((j + 1))]:-}" && cfg="git ${ws[$j]} ${ws[$((j + 1))]}"
              j=$((j + 2))
              ;;
            --config-env=*)
              moves_hooks "${ws[$j]#--config-env=}" && cfg="git ${ws[$j]}"
              j=$((j + 1))
              ;;
            -C | --git-dir | --work-tree | --namespace) j=$((j + 2)) ;;
            -*) j=$((j + 1)) ;;
            *) break ;;
          esac
        done
        sub=${ws[$j]:-}
        case "$sub" in commit | push | merge | pull | rebase | am) ;; *) return ;; esac
        [ -n "$cfg" ] && hook_deny=$cfg && return
        k=$((j + 1))
        while [ $k -lt $n ]; do
          a=${ws[$k]}
          case "$a" in
            --) break ;;
            --no-veri*)
              hook_deny="git ${sub} ${a}"
              return
              ;;
            --message | --file | --template | --author | --date | --reuse-message | --reedit-message | --fixup | --squash | --cleanup | --trailer | --strategy | --strategy-option) k=$((k + 1)) ;;
            --*) ;;
            -?*)
              # A cluster of short flags, read up to the first that takes a
              # value (the rest of the word, or the next word, is the value).
              # Only commit has -n for --no-verify (push -n is a dry run).
              case "$sub" in
                commit) vals=mFcCt ;;
                merge | pull) vals=mFsX ;;
                rebase) vals=sXx ;;
                push) vals=o ;;
                *) vals="" ;;
              esac
              x=1
              while [ $x -lt ${#a} ]; do
                ch=${a:$x:1}
                [ "$ch" = n ] && [ "$sub" = commit ] && hook_deny="git commit ${a}" && return
                # -u<mode> and -S<keyid> take a value only when it is attached.
                case "$ch" in u | S) break ;; esac
                case "$vals" in *"$ch"*)
                  [ $((x + 1)) -eq ${#a} ] && k=$((k + 1))
                  break
                  ;;
                esac
                x=$((x + 1))
              done
              ;;
          esac
          k=$((k + 1))
        done
        [ -n "$tool" ] && hook_ask="${tool} git ${sub}"
        return
        ;;
      *) return ;;
    esac
    i=$((i + 1))
  done
}
# Precisely: quoted text masked (a commit message or a PR body is not a
# command), heredoc bodies dropped, and the string after bash -c / sh -c /
# eval read as a command of its own. A finding there is denied; one seen
# only in the loose reading (quotes removed) is asked.
masked=$(printf '%s\n' "$cmd" | awk -v sq="'" '
  # mask(s): s with each quoted string replaced by Q. Heredoc bodies and
  # comments are dropped, a backslash-newline joins the lines, the string
  # after bash -c / sh -c / eval goes to `inner` (read as its own command),
  # and the quoted value right after git -c / --config-env / GIT_CONFIG_*=
  # is kept as is.
  function mask(s,   out, i, n, c, q, esc, rest, j, m, d, buf, need, raw, x, docs, k, line) {
    n = length(s); i = 1; docs = ""
    while (i <= n) {
      c = substr(s, i, 1)
      if (c == "\n") {
        out = out "\n"; i++
        # Skip the bodies of the heredocs opened on the line just ended.
        while (docs != "") {
          k = index(docs, "\n"); d = substr(docs, 1, k - 1); docs = substr(docs, k + 1)
          while (i <= n) {
            j = index(substr(s, i), "\n"); line = j ? substr(s, i, j - 1) : substr(s, i)
            i += j ? j : length(line) + 1
            if (substr(d, 1, 1) == "-") { sub(/^\t+/, "", line); if (line == substr(d, 2)) break }
            else if (line == d) break
          }
        }
        continue
      }
      if (c == "\\") { out = out (substr(s, i + 1, 1) == "\n" ? " " : substr(s, i, 2)); i += 2; continue }
      if (c == "#" && (out == "" || out ~ /[ \t\n;&|(]$/)) {
        j = index(substr(s, i), "\n"); if (!j) break; i += j - 1; continue
      }
      if (c == "<" && substr(s, i, 3) != "<<<" && substr(s, i, 2) == "<<" && substr(out, length(out)) != "<") {
        rest = substr(s, i + 2)
        if (match(rest, "^-?[ \t]*[\\\\\"" sq "]?[A-Za-z_][A-Za-z0-9_]*[\"" sq "]?")) {
          d = substr(rest, 1, RLENGTH); x = (substr(d, 1, 1) == "-") ? "-" : ""
          gsub("[- \t\\\\\"" sq "]", "", d); docs = docs x d "\n"
          out = out " "; i += 2 + RLENGTH; continue
        }
      }
      if (c == "\"" || c == sq) {
        esc = (c == "\"" || substr(out, length(out)) == "$")
        x = substr(out, length(out) - 59)
        need = (x ~ /(^|[^A-Za-z0-9_])((ba|z)?sh[ \t]+(-[A-Za-z]+[ \t]+)*-[A-Za-z]*c|eval)[ \t]*$/)
        raw = !need && (x ~ /(^|[^A-Za-z0-9_])git([ \t]+[^ \t]+)*[ \t]+(-c|--config-env)[ \t]+$|--config-env=$|(^|[ \t])GIT_CONFIG_[A-Z0-9_]*=$/)
        rest = substr(s, i + 1); m = length(rest); buf = ""
        if (!esc) { j = index(rest, c); if (!j) j = m + 1; buf = substr(rest, 1, j - 1) }
        else {
          # Jump from one backslash or closing quote to the next.
          j = 1
          while (1) {
            if (!match(substr(rest, j), "[\\\\" c "]")) { if (need || raw) buf = buf substr(rest, j); j = m + 1; break }
            k = j + RSTART - 1
            if (need || raw) buf = buf substr(rest, j, k - j)
            if (substr(rest, k, 1) == c) { j = k; break }
            if (need || raw) buf = buf substr(rest, k + 1, 1)
            j = k + 2
          }
        }
        if (need) { x = mask(buf); inner = inner x "\n" }
        out = out (raw ? buf : "Q"); i += j + 1; continue
      }
      rest = substr(s, i)
      if (!match(rest, "[\\\\\"\n#<" sq "]")) { out = out rest; break }
      if (RSTART == 1) { out = out c; i++; continue }
      out = out substr(rest, 1, RSTART - 1); i += RSTART - 1
    }
    return out
  }
  { all = all (NR > 1 ? "\n" : "") $0 }
  END { printf "%s\n%s", mask(all), inner }
')
while IFS= read -r seg; do
  [ -z "$hook_deny" ] || break
  hook_skip "$seg"
done << EOF
$(printf '%s\n' "$masked" | sed -E 's/[0-9]*>&[0-9-]*|&>>?|>&/ /g' | tr ';&|(){}`' '\n\n\n\n\n\n\n\n')
EOF
if [ -z "$hook_deny" ]; then
  while IFS= read -r seg; do
    [ -z "$hook_deny" ] || break
    hook_skip "$seg"
  done << EOF
$segments
EOF
  [ -n "$hook_deny" ] && hook_ask="${hook_deny}（引用符を外して読んだ形。commit メッセージなどの中の語かもしれません）" && hook_deny=""
fi
set +f
[ -z "$hook_deny" ] || deny "git の hook を飛ばす操作は禁止です（${hook_deny}。${where}）。hook を飛ばさずに、失敗の原因を直してください。本当に必要なら、ユーザー自身が ! で実行してください。"
# A possible skip is asked after the denies below (force push, Closes), as a
# note on the prompt.
hook_note=""
[ -z "$hook_ask" ] || hook_note="（git の hook を飛ばす可能性：${hook_ask}。hook を飛ばさずに失敗の原因を直すのが原則）"
[ $is_push -eq 1 ] || [ $is_pr_create -eq 1 ] || [ -n "$other" ] || [ -n "$hook_note" ] || exit 0

# deny: force push, in any form, inside a segment that is a git push (quotes
# removed; bash -c / eval / env / sudo wrappers allowed). A force flag seen
# only by the loose match (e.g. "push -f" inside a commit message) asks.
force_note=""
if [ $is_push -eq 1 ]; then
  force_re='(^|[[:space:]])(--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|$)|[[:space:]]\+[^[:space:]]'
  wrap='((command|env|sudo|exec|eval|nohup|time|(ba|z)?sh[[:space:]]+-c)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
  push_seg_re="^[[:space:]]*${wrap}git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+push([[:space:]]|$)"
  push_segs=$(printf '%s\n' "$unquoted" | tr ';&|(){}`' '\n\n\n\n\n\n\n\n' | grep -E "$push_seg_re" || true)
  if [ -n "$push_segs" ] && printf '%s\n' "$push_segs" | sed -E 's/.*[[:space:]]push([[:space:]]|$)/ /' | grep -Eq "$force_re"; then
    deny "force push は禁止です（ブランチ ${branch}）。履歴の書き換えが本当に必要なら、ユーザー自身が ! git push --force-with-lease などで実行してください。"
  fi
  printf '%s\n' "$norm" | grep -Eo 'push([[:space:]][^;&|]*)?' | grep -Eq "$force_re" \
    && force_note="（force push の可能性あり。コマンドを確認してください）"
fi

if [ -z "$state" ]; then
  # On the Base of an open run.
  if [ $is_push -eq 1 ]; then what="push"; elif [ $is_pr_create -eq 1 ]; then what="PR 作成"; elif [ -n "$other" ]; then what=$other; else what="git の操作"; fi
  ask "⚠ ${where} で ${what} を実行しようとしています。tixforge の作業はチケットのブランチで行います。承認しますか？${force_note}${hook_note}"
fi

# deny: the PR must close the run's issue. Only the precise form has a body
# we can read; anything else is left to the prompt.
run_id=${state%/state.md}
run_id=${run_id##*/}
issue=$(issue_of "$run_id")
if [ $precise_pr -eq 1 ] && [ -n "$issue" ]; then
  haystack=$cmd
  body_file=$(printf '%s\n' "$cmd" | grep -Eo '(--body-file|-F)([[:space:]]+|=)[^[:space:];&|]+' | head -1 \
    | sed -E 's/^(--body-file|-F)([[:space:]]+|=)//; s/^["'\'']//; s/["'\'']$//')
  if [ -n "$body_file" ]; then
    case "$body_file" in /*) ;; *) body_file="$cwd/$body_file" ;; esac
    [ -f "$body_file" ] && haystack="$haystack
$(cat "$body_file")"
  fi
  if ! printf '%s\n' "$haystack" | grep -Eiq "(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#${issue}([^0-9]|$)"; then
    deny "PR 本文に \"Closes #${issue}\" がありません。issue #${issue} を閉じる紐付けを本文に入れてから作成してください（--fill や本文なしでは作成できません）。"
  fi
fi

if [ $is_push -eq 0 ] && [ $is_pr_create -eq 0 ]; then
  [ -n "$other" ] || ask "git の hook を飛ばす可能性があります（${hook_ask}）。${where}。hook を飛ばさずに失敗の原因を直すのが原則です。承認しますか？"
  # dev posts the verification on its PR after each fix (pr.md): a write,
  # so it asks, but not as an unknown operation.
  [ "$others" = "gh pr comment" ] && ask "PR へのコメントの投稿です（dev の「修正の push」なら、チャットで合意した内容か確かめてください）。${where}。承認しますか？${hook_note}"
  ask "${others} は tixforge の許可リストにない git / gh 操作です（merge・rebase・reset・gh pr merge など）。${where}。承認しますか？${hook_note}"
fi

# ask: everything else that leaves the machine. The phase goes in the prompt.
if [ $is_pr_create -eq 1 ]; then
  what="PR 作成"
  obj="PR 作成を"
else
  what="push"
  obj="push を"
fi
detail="${where}、Base ${base:-—}"
[ $is_pr_create -eq 1 ] && [ -n "$issue" ] && detail="${detail}、Closes #${issue}"
[ -n "$other" ] && detail="${detail}、ほかに ${other} を含む"
pr_url=$(awk '/^## PR/{p=1; next} /^## /{p=0} p' "$state" | grep -Eo -m1 'https://[^[:space:]]+/pull/[0-9]+' || true)

case "$status" in
  pr:awaiting-approval)
    note="PR ゲート：${obj}承認しますか？"
    ;;
  pr:awaiting-review | pr:in-progress | pr:ready-to-merge)
    if [ $is_pr_create -eq 1 ] && [ -n "$pr_url" ]; then
      note="⚠ PR は既にあります（${pr_url}）。${obj}承認しますか？"
    elif [ -n "$pr_url" ]; then
      note="PR 作成後の ${what}（${pr_url}）を承認しますか？"
    else
      note="⚠ ## PR に URL がありません。${obj}承認しますか？"
    fi
    ;;
  done | canceled)
    note="⚠ このブランチの run は ${status} です（完了済み）。${obj}承認しますか？"
    ;;
  *)
    note="⚠ まだ PR ゲート前です。${obj}承認しますか？"
    ;;
esac
note="${note}${force_note}${hook_note}"
if { [ $is_push -eq 1 ] && [ $precise_push -eq 0 ]; } || { [ $is_pr_create -eq 1 ] && [ $precise_pr -eq 0 ]; }; then
  note="${note}（コマンドの形から ${what} の可能性があると判断）"
fi
ask "${note} ${detail}"
