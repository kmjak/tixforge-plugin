# /tixforge:dev — Phase 6：PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、完了まで見届ける。

「PR と紐づける」（`references/github/pr.md`）を Read する。

手順は場面ごとのファイルにある。その場面になったら、このセッションで未読なら Read し、その手順で行う。

| 場面 | ファイル |
|------|----------|
| 「PR の準備」：PR を出すまで（`pr:in-progress` で PR が無い・`pr:awaiting-approval`） | `<plugin>/skills/dev/pr/create.md` |
| 「PR の状況確認」「修正の push」：PR を出した後（`pr:awaiting-review`・`pr:ready-to-merge`・PR がある `pr:in-progress`） | `<plugin>/skills/dev/pr/follow.md` |

## 再開（`pr:*` から再開したとき）

- **`pr:in-progress`**：まず「PR の存在確認」。
  - PR が無い → 「PR の準備」から。
  - 開いている PR がある → PR を出した後の対応（コンフリクト・CI の失敗・修正依頼）の途中。`git fetch origin <ブランチ>` の後、`git rev-list --count origin/<ブランチ>..<ブランチ>` が 0 でなければ、push していない修正がある：「修正の push」から。0 でも、HEAD（`git rev-parse --short HEAD`）が `## PR` の `PR head @ <hash>` とも `## Implementation Log` の最新の `PR comment @ <hash>` とも違い、PR のコメント（`gh pr view <PR> --json comments`）に HEAD の `Verification @` も無ければ、push の後にコメントせずに止まっている：「修正の push」の手順 2 から（push は飛ばす）。それ以外は「PR の状況確認」から。
- **`pr:awaiting-approval`**：ゲートを出し直す**前に**「PR の存在確認」。開いている PR があれば作成の後に中断したので、新しく作らずに「PR の準備」の作成の後を済ませる：
  1. `gh pr view <PR> --json headRefOid,comments` で PR の head とコメントを見る。head の短い hash の `Verification @` のコメントが無ければ、「PR の準備」の手順 2 の決まりで `## Implementation Log` から検証のコメントを作り直し、示して確認を得てから投稿する。
  2. 「PR と紐づける」の「紐付けの確認」を行い、`references/github/labels.md` を Read し、その「PR の作成」でレビュー中にする（済んでいても、もう一度行ってよい）。
  3. 「PR の準備」の手順 5 を行う（`PR head @` は PR の head の短い hash）。
  PR が無ければゲートを出し直す。
- **`pr:awaiting-review`・`pr:ready-to-merge`**：「PR の状況確認」から。

## PR の存在確認

`gh pr list --head <ブランチ> --state all --json number,state,url` で探し、順に扱う：

1. 開いている（`OPEN`）PR があれば、それがこの run の PR。
2. 無く、マージ済み（`MERGED`）があれば完了している。URL を `## PR` に記録し、「PR の状況確認」の `merged` の扱いへ。
3. 閉じた（`CLOSED`）PR だけなら使わない。PR は無いものとして扱い、閉じた PR があったことだけ伝える。
