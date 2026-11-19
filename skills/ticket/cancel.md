# /tixforge:ticket cancel — チケットをやめる

**チケットは消さずに残す。** ブランチ・リモートブランチには触らない。run だけをやり直したいなら `/tixforge:dev rewind` を案内する。

## Phase 1 — 準備

目的：チケットを読み、やめられる状態か確かめる。

1. **準備**：引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる）。`references/github/fetch.md`・`close.md`・`record.md` を Read する。
2. **チケットを読む**：
   - `fetch.md` の手順 1〜3 で状況を見る（手元のファイルは作らない。タイトルは `check` の `title:`）。閉じていればチケットの状態に従う（`canceled`：キャンセル済みとして止まる。`completed`・`closed-completed`：完了済みなので拒否する。`closed-not-planned`：キャンセルとして記録し直すか尋ね、そうするなら下の「行うこと」を、`close.md` のとおり閉じる操作を省いて進める。`closed`：状況を示してどうするか尋ねる）。
   - `.tixforge/<ticket-id>/state.md` の `Status` が `done` なら拒否する。
   - 状態が `merged` なら拒否する（Base にマージ済みでリリース待ち。チケットが開いていて state.md が手元に無くても、完了した作業）。`in-review` なら、PR が出ていることを示して続けるか尋ねる。

## Phase 2 — 確認（ゲート）

目的：理由と、行うことに確認を得る。

3. やめる理由を 1 行で尋ねる（「優先度が下がった」「GT-000045 に統合」など）。
4. **行うことを一覧で示し、確認を得る**（実行もこの順に行う。GitHub の操作を先にし、state.md を最後にする：途中で失敗しても、state.md だけが canceled になってやり直せなくなるのを防ぐため）：
   - 取ってきた担当者に自分（`gh api user --jq .login`）以外がいれば、「担当者：<login>（自分以外）」を一覧の先頭に載せる。
   - 「閉じる」の「キャンセル」（`close.md`）。
   - `state.md` の `## Approach` が書かれていれば、`record.md` のとおり「記録を残す」を行う。投稿する本文もこの一覧で示す。
   - このチケットのブランチに開いている PR（`gh pr list --head <Branch> --state open`）があれば、**閉じるかどうかだけ**を尋ねる（残すと、レビュアーからは生きている PR に見える、と添える。閉じるなら `close.md` の「キャンセル」の PR の閉じ方で）。
   - 最後に、`.tixforge/<ticket-id>/state.md` があれば、`bash <scripts>/run-state.sh set <ticket-id> Status canceled` を実行する。

## Phase 3 — 実行

目的：確認したとおりに実行する。

5. 確認されたら実行する。
6. 行ったことを伝える。ブランチとリモートブランチは残していること（不要なら自分で削除できること）を伝える。
