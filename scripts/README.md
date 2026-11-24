# scripts

tixforge のスクリプトの一覧（人向け。Claude は読まない）。使い方・出力・終了コードは、各ファイルの冒頭のコメントにある。ここには書かない（2 か所に書くと片方だけ直してずれるため）。

| スクリプト | 何をするか | 呼ぶもの | 触るもの |
|---|---|---|---|
| `guard.sh` | push・PR 作成・危ない git 操作と、Plan の承認前のコード編集に確認を出す／止める | hook（PreToolUse） | なし（判定だけ） |
| `events-sync.sh` | イベントログのまだ送っていない行を、チームの受け口（`events.endpoint`）に送る。状況を見る（`status`）・すぐ送る（`flush`） | イベントを書いたとき（`lib.sh` の `event` が裏で起動）・人が直接 | `<イベントログ>.sent`・`.sync-error`・`.lock` |
| `wait-hook.sh` | 人を待っている時間をイベントログに書く | hook（Stop・UserPromptSubmit・AskUserQuestion の前後） | `.tixforge/events.jsonl` |
| `session-start.sh` | 会話の要約・再開の後に、読み直すファイルを伝える | hook（SessionStart） | なし |
| `statusline.sh` | 画面の下に今の run と Status を出す | 利用者の statusline の設定（README） | なし |
| `common-rules.sh` | 共通規約（`references/common.md`）をスキルに差し込む | 3 つの SKILL.md | なし |
| `project-status.sh` | 設定・進行中の run・v2 から移すもの（`lt`）を出す | 3 つの SKILL.md・ticket の create・project の update | なし |
| `ticket-id.sh` | チケット id の取り出し・正規化・実在の確認・issue 番号への変換 | ticket・dev の手順 | なし（GitHub は読むだけ） |
| `run-state.sh` | state.md の作成・ヘッダの読み書き・巻き戻し・キャンセル・手放す・前の形式からの更新・Review をどこから進めるかの判定 | dev の手順・ticket の cancel・project の update | `.tixforge/<id>/`・`.tixforge/events.jsonl` |
| `verify.sh` | 検証コマンドを実行し、結果を 1 行で出す | dev の手順 | `.git/tixforge/verify/`（ログ） |
| `review-input.sh` | Review の agent が読む入力（差分・チケット・Approach・Plan・共通の規則の `index.md`）を書き出す | dev の Review | `.git/tixforge/review/` |
| `pr-template.sh` | リポジトリの既定の PR テンプレートを探す | dev の PR・project の init | なし |
| `branch.sh` | Plan の Base とブランチ名を決める | dev の Plan | なし（git を読むだけ） |
| `pr-status.sh` | PR の状況（レビュー・CI・コンフリクト）を判定する | dev の PR | なし（GitHub は読むだけ） |
| `pr-resume.sh` | PR フェーズをどこから再開するかを判定する | dev の PR | なし（`git fetch` と GitHub を読むだけ） |
| `github-preflight.sh` | gh が使えるか（インストール・ログイン・リポジトリ）を確かめる | GitHub を使う手順 | なし |
| `issue-sync.sh` | issue の作成・状態の判定と、手元のコピー（`snapshot.md`・`editing.md`）との同期 | ticket・dev の手順・project の update | `.tixforge/<id>/`・GitHub issue |
| `issue-label.sh` | issue の状態ラベルと担当者を変える・ラベルを作る | ticket・dev の手順・project の init と update | GitHub issue |
| `panel-data.sh` | `/tixforge-panel` のパネルに出す PR・チケット・チケットの詳細を出す | `hooks/panel.tsx`（mod） | なし（GitHub は読むだけ） |
| `ticket-hash.sh` | issue の本文のハッシュを計算する（Actions と共通） | `issue-sync.sh`・Actions | なし |
| `lib.sh` | 共通の関数（設定・state.md の読み取り、run の一覧、イベントログの書き込みなど） | 多くのスクリプト | `.tixforge/.gitignore`（無いときに作る） |

Actions がコピーして使う文言（`messages.yml`）は、コピー先に合わせて `templates/github/tixforge/` にある。state.md に書く決まった文言は `scripts/messages.yml`。
