# /tixforge:dev — Phase 6：PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、完了まで見届ける。

「PR と紐づける」（`references/github/pr.md`）を Read する。

手順は場面ごとのファイルにある。その場面になったら、このセッションで未読なら Read し、その手順で行う。

| 場面 | ファイル |
|------|----------|
| 「PR の準備」：PR を出すまで（`pr:in-progress` で PR が無い・`pr:awaiting-approval`） | `<plugin>/skills/dev/pr/create.md` |
| 「PR の状況確認」「修正の push」：PR を出した後（`pr:awaiting-review`・`pr:ready-to-merge`・PR がある `pr:in-progress`） | `<plugin>/skills/dev/pr/follow.md` |

## 再開（`pr:*` から再開したとき）

`bash <scripts>/pr-resume.sh <ticket-id>` を実行し、`next:` に従う（自分で git・gh を叩いて判定し直さない）。`pr:` がこの run の PR。`closed:` があれば、閉じた PR があったことだけ伝える（使わない）。

- `create` → 「PR の準備」から。
- `gate` → ゲートを出し直す。
- `finish-create` → PR を作った後に中断した。新しく作らずに、作成の後を済ませる：
  1. `comment: missing` なら、「PR の準備」の手順 2 の決まりで `## Implementation Log` から検証のコメント（`head:` の hash で）を作り直し、示して確認を得てから投稿する。
  2. 「PR と紐づける」の「紐付けの確認」を行い、`references/github/labels.md` を Read し、その「PR の作成」でレビュー中にする（済んでいても、もう一度行ってよい）。
  3. 「PR の準備」の手順 5 を行う（`PR head @` は `head:`）。
- `push-fix` → push していない修正がある：「修正の push」から。
- `comment-fix` → push の後にコメントせずに止まっている：「修正の push」の手順 2 から（push は飛ばす）。
- `status` → 「PR の状況確認」から（`pr:` の PR で）。
- `merged` → URL を `## PR` に記録し、「PR の状況確認」の `merged` の扱いへ。

## PR の存在確認

`bash <scripts>/pr-resume.sh <ticket-id>` の `pr:` を見る。開いている PR があればそれ、無くマージ済みがあればそれ（完了している：`merged` の扱い）。`none` なら PR は無い（閉じた PR は使わない。`closed:` があれば、あったことだけ伝える）。
