# GitHub：Actions（任意）

`project init` の「GitHub Actions」で読む（update が init のその手順を行うときも）。ローカルの tixforge は誰かが実行したときにしか動かないので、サーバー側で次の workflow を動かす。雛形は `<plugin>/templates/github/`。

| workflow | 起動 | 内容 |
|----------|------|------|
| `tixforge-issue-sync.yml` | PR の作成・再オープン・ready for review・本文の編集（開いている PR）・クローズ、issue のクローズ | PR 本文の `Closes #N` の issue（`tixforge:*` ラベル付きのものだけ）を `tixforge:in-review` に（`tixforge:merged` の issue は変えない。develop → main のリリース PR で戻らないように）。マージされたら：default branch 向けなら閉じて `tixforge:done`、それ以外（develop など）は `tixforge:merged` にして開いたまま。default branch 向けの PR（develop → main のリリース PR）がマージされたら、その commit の `Closes #N` の issue のうち `tixforge:merged` のものを閉じて `tixforge:done` に（squash の設定に関係なく）。`tixforge:merged` の issue が完了として閉じられたら `tixforge:done` に（not planned で閉じたときは変えない） |
| `tixforge-pr-link.yml` | PR の作成・編集・push | `GT-<番号>-` ブランチの PR の本文に `Closes #<番号>` があるかを検査する。必須チェックにするかはユーザーがブランチ保護で決める（tixforge は設定しない） |
| `tixforge-issue-guard.yml` | issue のタイトル・本文の編集 | 本文のハッシュが合わなければ（GitHub 上で直接編集された）`tixforge:out-of-sync` とコメントを付け、合えば外す |

1. 入れるものを尋ねる（複数選択。既に `.github/workflows/` にあるものは除く）。`repository.base_branch` が GitHub の default branch と違う（develop など）なら、`tixforge-issue-sync` に「強く推奨」と添える（リリース PR のマージで、squash の設定に関係なく issue を閉じるため）。
2. 選ばれたものを `.github/workflows/` にそのままコピーする（内容は変えない）。`tixforge-issue-guard` か `tixforge-pr-link` なら `<plugin>/templates/github/tixforge/messages.yml` を `.github/tixforge/` にもコピーする（コメントやエラーをドキュメント言語で出すため）。`tixforge-issue-guard` なら `<scripts>/ticket-hash.sh` も `.github/tixforge/` にコピーする（ハッシュの計算方法をローカルと揃えるため）。作るファイルを一覧で示し、確認を得てから作る。
3. 次をユーザーに伝える：
   - フォークからの PR には対応しない（Actions のトークンが読み取り専用になるため）。
   - plugin を更新しても、コピーした workflow は自動では更新されない。`/tixforge:project update` が雛形の先頭のバージョン（`v6` など）を比べて更新する。
