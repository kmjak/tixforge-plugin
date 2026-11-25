---
name: dev
description: tixforge の開発。1 つのチケットを 6 フェーズ Research → Approach → Plan → Implement → Review → PR で進める。進捗は .tixforge/<ticket-id>/state.md に集約するので、途中で止めても同じフェーズから再開できる。rewind で前のフェーズに戻す（最初から・チケットを手放すも）。/tixforge:dev で明示起動する。
argument-hint: "[<ticket-id> | rewind <ticket-id>]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-template.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/github-preflight.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/ticket-id.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/run-state.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-input.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/review.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-status.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-sync.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/issue-label.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pr-resume.sh *)
---

# /tixforge:dev — チケットの開発

引数：`$ARGUMENTS`

## 現在の状態

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/project-status.sh`

## サブコマンド

| 起動 | 内容 | 手順ファイル |
|------|------|--------------|
| `/tixforge:dev <ticket-id>` | 6 フェーズで実装から PR まで進める | `${CLAUDE_SKILL_DIR}/run.md` |
| `/tixforge:dev rewind <ticket-id>` | 前のフェーズに戻す | `${CLAUDE_SKILL_DIR}/rewind.md` |
| `/tixforge:dev` | 選択肢を出す（下記） | — |

**引数の解釈：** 先頭の語が `rewind` なら rewind で、残りはチケット id。それ以外は引数全体をチケット id として dev で進める。

### 引数が無い場合（`/tixforge:dev`）

上の「現在の状態」にある進行中の run を使い、AskUserQuestion で選んでもらう（単一選択）。推測で決めない。

1. **進行中の run を再開** — 進行中の run のチケット id と Status を説明に含める。**進行中の run が無ければこの選択肢は出さない。** 複数あるなら、どれを再開するか続けて尋ねる。
2. **チケットを選んで始める** — チケット id を尋ねる（`references/github/fetch.md` を Read し、その「探す」の着手できるチケットを候補として示す）。

質問文に「前のフェーズに戻すのは `/tixforge:dev rewind <ticket-id>`」と添える。

## 参照ファイル

| 参照ファイル | 読むとき |
|--------------|----------|
| `${CLAUDE_PLUGIN_ROOT}/references/github/<名前>.md` | 手順が指示したファイルだけ |
| `${CLAUDE_PLUGIN_ROOT}/references/config.md` | 設定のキーが無いとき・キーを説明するとき（共通規約が指示する） |
| `${CLAUDE_PLUGIN_ROOT}/references/frontend-design.md` | フロントエンドの設計を決めるとき（画面を触るのに設計が無いとき。`phase/approach.md` が指示する） |
| `${CLAUDE_SKILL_DIR}/phase/<フェーズ>.md` | そのフェーズに入るとき・再開するとき（`run.md` の「フェーズの手順」が指示する） |
| `${CLAUDE_SKILL_DIR}/pr.md` | PR フェーズに入るとき・`pr:*` から再開するとき（`run.md` が指示する） |
| `${CLAUDE_SKILL_DIR}/pr/<場面>.md` | PR を出すとき（`create`）・出した後（`follow`）（`pr.md` が指示する） |
| `${CLAUDE_PLUGIN_ROOT}/references/ticket-changed.md` | チケットが変わり、フェーズを戻すか決めるとき（`run.md`・`pr/create.md` が指示する） |

以下の置き場所・手順ファイルの読み方・共通規約は、このスキルのすべてに適用する。

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/common-rules.sh`
