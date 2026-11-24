# /tixforge:dev — Phase 6：PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、完了まで見届ける。

「PR と紐づける」（`references/github/pr.md`）を Read する。

手順は場面ごとのファイルにある。使う場面になったら、このセッションでまだ読んでいなければ Read し、その手順で行う。

| 場面 | ファイル |
|------|----------|
| 「PR の準備」：PR を出すまで（`pr:in-progress` で PR が無い・`pr:awaiting-approval`） | `<plugin>/skills/dev/pr/create.md` |
| 「PR の状況確認」「修正の push」：PR を出した後（`pr:awaiting-review`・`pr:ready-to-merge`・PR がある `pr:in-progress`） | `<plugin>/skills/dev/pr/follow.md` |

## 再開（`pr:*` の Status から再開したとき）

- **`pr:in-progress`**：まず PR の有無を確かめる（下記「PR の存在確認」）。
  - PR が無い → 「PR の準備」から。
  - PR がある（開いている）→ PR を出した後の対応（コンフリクト・CI の失敗・修正依頼）の途中。手元のブランチがリモートより進んでいるか（`git fetch origin <ブランチ>` の後、`git rev-list --count origin/<ブランチ>..<ブランチ>`）を確かめる。進んでいれば、push していない修正がある：「修正の push」から続ける。進んでいなくても、HEAD（`git rev-parse --short HEAD`）が `## PR` の `PR head @ <hash>` とも `## Implementation Log` の最新の `PR comment @ <hash>` とも違い、PR のコメント（`gh pr view <PR> --json comments`）に HEAD の `Verification @` も無ければ、push の後にコメントせずに止まっている：「修正の push」の手順 2 から続ける（push は済んでいるので飛ばす）。それ以外は「PR の状況確認」から。
- **`pr:awaiting-approval`**：ゲートを出し直す**前に**、PR が既にあるか確かめる（「PR の存在確認」）。開いている PR があれば、作成の後に中断したということなので、新しく作らずに URL を `## PR` に記録し、`Status: pr:awaiting-review` にして「PR の状況確認」へ。無ければゲートを出し直す。
- **`pr:awaiting-review`・`pr:ready-to-merge`**：「PR の状況確認」から。

## PR の存在確認

`gh pr list --head <ブランチ> --state all --json number,state,url` で探し、次の順に扱う：

1. 開いている（`OPEN`）PR があれば、それがこの run の PR。
2. 無く、マージ済み（`MERGED`）の PR があれば、完了している。URL を `## PR` に記録し、「PR の状況確認」の `merged` の扱いへ。
3. 閉じた（`CLOSED`）PR だけなら、それは使わない（以前に閉じたもの）。PR は無いものとして扱い、閉じた PR があったことだけ伝える。
