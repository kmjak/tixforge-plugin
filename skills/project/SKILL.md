---
name: project
description: tixforge のプロジェクト設定。init でこのプロジェクトを tixforge で使える状態にする（設定・検証コマンド・commit 規約・ブランチ運用・チケット管理（GitHub issue）・GitHub Actions・context）。update で設定の値を変える・v2 の LT を issue に移す・テンプレートを最新にする。/tixforge:project で明示起動する。
argument-hint: "[init | update]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-template.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh lt), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/github-preflight.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-label.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-sync.sh *)
---

# /tixforge:project — プロジェクトの設定

引数：`$ARGUMENTS`

## 現在の状態

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh`

## サブコマンド

| 起動 | 内容 | 手順ファイル |
|------|------|--------------|
| `/tixforge:project init` | プロジェクトを初期化する。足りない設定を足すだけで、既にある値は変えない | `${CLAUDE_SKILL_DIR}/init.md` |
| `/tixforge:project update` | 設定の値を変える・v2 の LT を issue に移す・テンプレートと Actions を最新にする | `${CLAUDE_SKILL_DIR}/update.md` |
| `/tixforge:project` | `.tixforge/config.yml` が無ければ init。「現在の状態」に「移行が要る」があれば update。それ以外は init・update のどちらかを選択肢で尋ねる（単一選択） | — |

それ以外の引数が渡されたら実行せず、使えるサブコマンドを示して止まる。

## 参照ファイル

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_PLUGIN_ROOT}/references/github/<名前>.md` | 手順が指示したファイルだけ |

以下の置き場所・手順ファイルの読み方・共通規約は、このスキルのすべてに適用する。

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh`
