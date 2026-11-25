# /tixforge:dev — Phase 6：PR — PR を出した後

`pr.md`（再開・PR の存在確認）の中で行う。

## PR の状況確認

`bash <scripts>/pr-status.sh <PR URL>` を実行する。1 行目が判定、2 行目以降が詳細。`.tixforge/config.yml` の `review.required` と合わせて進む：

- `merged` → `## PR` に結果を追記し、`Status: done` にする。`references/github/close.md` を Read し、その「完了」を行う。
- `approved` → `## PR` に結果を追記し、`Status: pr:ready-to-merge` にして止まる。マージはユーザーが行う。マージ後に `/tixforge:dev <ticket-id>` で再開すると `done` になると伝える。
- `ready`（Approve は無いが、CI 成功・コンフリクトなし）→
  - `review.required: false` なら `approved` と同じく `pr:ready-to-merge` にする。
  - `review.required: true` なら `pending` と同じ（Approve 待ち）。1 人で開発していて自分の PR を Approve できないなら、`/tixforge:project update` で `review.required: false` にできると伝える。
- 詳細が `ci: none`（チェックが 1 つも無い）→ `.github/workflows/*.yml` に `pull_request` があるか確かめる。あれば CI がまだ始まっていないだけなので `pending` として扱う。無ければ判定どおりに進む。
- `conflict` → `Status: pr:in-progress` に戻し、`git fetch origin <Base>` の後、`origin/<Base>` をブランチに取り込んで解消する。既定は merge（rebase は force push が要るので、ユーザーが望んだときだけ）。
- `ci_failing` → `Status: pr:in-progress` に戻し、失敗したチェック（`failing_checks`）のログ（`gh pr checks`・`gh run view --log-failed`）を見て原因を直す。
- `changes_requested` → `Status: pr:in-progress` に戻し、指摘を要約して示してから対応する。
- `pending`（draft・未レビュー・CI 実行中など）→ そう伝えて詳細を示し、`pr:awaiting-review` のまま止まる（`pr:ready-to-merge` から戻ったなら `pr:awaiting-review` にする）。`commented_by` がある（コメントだけのレビュー）なら内容を示し、対応するか尋ねる。対応するなら `Status: pr:in-progress` にしてから直す。
- `closed`（マージされずにクローズ）→ 報告し、どうするか尋ねる。勝手に `done` にしない。

`conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」（個人の言語）と記録してから「修正の push」を行う。方針や計画の変更を伴う大きさなら、直さずに止まり、`rewind.md` を Read して戻るか尋ねる（きっかけは `pr`。PR を出した後に戻ると、追加の commit は既存の PR に入り、設定によっては Approve が外れる）。

## 修正の push

PR を出した後の commit を push する。PR 本文の検証は書き換えず、検証の結果を PR にコメントする（いつ・どの commit で確かめたかを残し、レビュアーが変化に気づけるように）。

1. **検証**（`phase/implement.md`「検証」。影響する手動確認もやり直し、`checks.sh record` で残す）を行い、1 行目を `## Implementation Log` に書き写す。
2. 変更内容・検証結果と、投稿するコメント（ドキュメント言語。何に対応したかを 1 行、新しい `Verification @ <hash>: …` の行、その下に確かめた手段ごとの `###` の小見出し。`pr/create.md` の「PR の準備」の検証のコメントと同じ書き方で（未読なら Read する）、手動確認はやり直したものだけ）を一覧で示して**止まり、確認を得る**。PR を出した後に Approach か Plan に戻した run で、方針か対応表が変わっていれば、PR 本文の方針・受け入れ条件の更新案（`gh pr edit`。検証は書き換えない）も載せる。push とコメントの投稿は別のコマンドで行い、確認画面がそれぞれ出る（一覧で合意した内容だと伝える）。
3. push し（済んでいれば飛ばす）、`gh pr comment <PR> --body-file <一時ファイル>` で投稿して、`## Implementation Log` に `PR comment @ <HEAD の短い hash>` （英語の固定キー）と記録する。呼んだ側に続きの指示があれば従い、無ければ `Status: pr:awaiting-review` にして止まる。
