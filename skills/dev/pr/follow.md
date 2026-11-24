# /tixforge:dev — Phase 6：PR — PR を出した後

`pr.md`（再開・PR の存在確認）の中で行う。

## PR の状況確認

`bash <scripts>/pr-status.sh <PR URL>` を実行する。1 行目が判定、2 行目以降が詳細。`.tixforge/config.yml` の `review.required` と合わせて、次のとおり進む：

- `merged` → `## PR` に結果を追記し、`Status: done` にする。`references/github/close.md` を Read し、その「完了」を行う。
- `approved` → `## PR` に結果を追記し、`Status: pr:ready-to-merge` にして停止する。マージはユーザーが行う。マージしたら `/tixforge:dev <ticket-id>` で再開すると `done` になることを伝える。
- `ready`（Approve は無いが、CI 成功・コンフリクトなし）→
  - `review.required: false` なら `approved` と同じく `pr:ready-to-merge` にする。
  - `review.required: true` なら `pending` と同じ（Approve 待ち）。1 人で開発していて自分の PR を Approve できない場合は、`/tixforge:project update` で `review.required: false` にできることを伝える。
- 詳細の `ci: none`（チェックが 1 つも無い）→ リポジトリに PR で動く workflow があるか（`.github/workflows/*.yml` に `pull_request` がある）を確かめる。あれば、CI がまだ始まっていないだけなので `pending` として扱う。無ければ CI の無いリポジトリなので、判定どおりに進む。
- `conflict`（Base とコンフリクト）→ `Status: pr:in-progress` に戻し、`git fetch origin <Base>` の後、`origin/<Base>` をブランチに取り込んで解消する。取り込み方は merge を既定とする（rebase は force push が必要になるため、ユーザーが望んだ場合だけ）。
- `ci_failing`（CI 失敗）→ `Status: pr:in-progress` に戻し、失敗したチェック（`failing_checks`）のログを確認して（`gh pr checks`・`gh run view --log-failed`）原因を直す。
- `changes_requested`（修正依頼）→ `Status: pr:in-progress` に戻し、指摘を要約して提示してから対応する。
- `pending`（draft・未レビュー・CI 実行中など）→ その旨と詳細を伝え、`pr:awaiting-review` のまま停止する（`pr:ready-to-merge` から戻ったなら `pr:awaiting-review` にする）。`commented_by` がある（コメントだけのレビュー）場合は内容を示し、対応するかユーザーに尋ねる。対応するなら `Status: pr:in-progress` にしてから直す。
- `closed`（マージされずにクローズ）→ 報告し、どうするか尋ねる。勝手に `done` にしない。

`conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」（個人の言語）として記録してから、「修正の push」を行う。対応が方針や計画の変更を伴う大きさなら、その場で直さずに停止し、`rewind.md` を Read し、その手順で戻るかユーザーに尋ねる（きっかけは `pr`）（PR を出した後に戻ると、追加の commit は既存の PR に入り、設定によっては Approve が外れる）。

## 修正の push

PR を出した後の commit を push する。PR 本文の検証は書き換えず、検証の結果を PR にコメントする（いつ・どの commit で確かめたかを残し、レビュアーが変化に気づけるように）。

1. **検証**（`phase/implement.md`「検証」。影響する手動確認もやり直す）を行い、出力の 1 行目を `## Implementation Log` に書き写す。
2. 変更内容・検証結果と、PR に投稿するコメント（ドキュメント言語。何に対応したかを 1 行、新しい `Verification @ <hash>: …` の行と、その下に確かめた手段ごとの `###` の小見出し（`pr/create.md` の「PR の準備」の検証のコメントと同じ書き方。未読なら Read する。手動確認はやり直したものだけを書く））を一覧で示して**停止し、確認を得る**。PR を出した後に Approach か Plan に戻した run で、方針か対応表が変わっていれば、PR 本文の方針・受け入れ条件の更新案（`gh pr edit`。検証は書き換えない）も一覧に載せる。push とコメントの投稿は別のコマンドで行い、確認画面がそれぞれ出る（一覧で合意した内容だと伝える）。
3. push し（済んでいれば飛ばす）、コメントを `gh pr comment <PR> --body-file <一時ファイル>` で投稿して、`## Implementation Log` に `PR comment @ <HEAD の短い hash>`（英語の固定キー）と記録する。呼んだ側に続きの指示があればそれに従い、無ければ `Status: pr:awaiting-review` にして停止する。
