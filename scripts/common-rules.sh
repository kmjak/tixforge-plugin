#!/usr/bin/env bash
# Print what the project, ticket and dev skills share: where the plugin is,
# how to read the instruction files, and references/common.md. Each
# SKILL.md injects it with !`...` when the skill starts (a plain `cat` of a
# file outside the working directory is refused there).
# Always exits 0: a failing injected command would abort the skill.
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/.." && pwd)
cat << EOF2
## 置き場所

- \`<plugin>\`：${plugin}
- \`<scripts>\`：${plugin}/scripts

## 手順ファイルの読み方

サブコマンドが決まったら、**作業を始める前に必ずその手順ファイルを Read する**。読まずに記憶や推測で進めない。手順ファイルは、選んだサブコマンドのものと、手順が Read するよう指示したものだけを読む。参照ファイル（SKILL.md の「参照ファイル」の表）も、手順が指示したときだけ読む。

EOF2
cat "$plugin/references/common.md" 2> /dev/null || echo "（共通規約を読めませんでした: $plugin/references/common.md）"
exit 0
