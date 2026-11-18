---
name: ticket
description: tixforge のチケット操作。create（チケットを対話で作る。issue を作り、issue 番号から id を決める）、edit（チケットを編集し、進行中の run はフェーズを戻す）、cancel（チケットをキャンセル済みにする）。/tixforge:ticket で明示起動する。
argument-hint: "[create [作りたいもの] | edit <ticket-id> | cancel <ticket-id> | 作りたいもの]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/github-preflight.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-id.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-sync.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-label.sh *)
---

# /tixforge:ticket — チケット

引数：`$ARGUMENTS`

## 現在の状態

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh`

## サブコマンド

| 起動 | 内容 | 手順ファイル |
|------|------|--------------|
| `/tixforge:ticket create [作りたいもの]` | チケットを対話で作る | `${CLAUDE_SKILL_DIR}/create.md` |
| `/tixforge:ticket edit <ticket-id>` | 既存のチケットを対話で書き換える。進行中の run があれば、影響に応じてフェーズを戻す | `${CLAUDE_SKILL_DIR}/edit.md` |
| `/tixforge:ticket cancel <ticket-id>` | チケットを `canceled` として残す | `${CLAUDE_SKILL_DIR}/cancel.md` |
| `/tixforge:ticket` | 選択肢を出す（下記） | — |

**引数の解釈：** 先頭の語が `create` / `edit` / `cancel` ならそのサブコマンド。残りは、edit・cancel ではチケット id、create では作りたいものの説明（省略可）として扱う。先頭の語がサブコマンド名でなければ、引数全体を create の説明として扱う。

### 引数が無い場合（`/tixforge:ticket`）

AskUserQuestion で、create・edit・cancel から 1 つを選んでもらう（単一選択）。edit・cancel を選んだら、対象のチケット id を尋ねる。推測で決めない。

## 参照ファイル

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_PLUGIN_ROOT}/references/github/<名前>.md` | 手順が指示したファイルだけ |
| `${CLAUDE_PLUGIN_ROOT}/references/config.md` | 設定のキーが無いとき・キーを説明するとき（共通規約が指示する） |
| `${CLAUDE_PLUGIN_ROOT}/templates/docs/ticket.md` | create でチケットの下書きを作るとき・取り込んだ issue の足りない項目を埋めるとき（手順が指示する） |
| `${CLAUDE_PLUGIN_ROOT}/references/ticket-changed.md` | チケットが変わり、進行中の run のフェーズを戻すか決めるとき（edit が指示する） |
| `${CLAUDE_PLUGIN_ROOT}/skills/dev/rewind.md` | `ticket-changed.md` で戻すかを尋ねるとき（`ticket-changed.md` が指示する。手順 3 の出し方と、手順 2・5・7） |

以下の置き場所・手順ファイルの読み方・共通規約は、このスキルのすべてに適用する。

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh`
