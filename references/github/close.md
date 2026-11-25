# GitHub：チケットを閉じる

- 操作したら、スクリプトが出力した一行をユーザーに伝える。
- ラベルが無いというエラーなら、`/tixforge:project init` の再実行（`issue-label.sh setup`）でラベルを作れることを伝える。
- 閉じるときのコメント（完了・キャンセルの issue と PR に共通）は一時ファイルに書き、`gh issue comment <番号> --body-file <一時ファイル>`（PR は `gh pr comment <PR> --body-file <一時ファイル>`）で先に投稿してから、コメントを付けずに閉じる（改行と記号をそのまま渡し、`$(...)` の確認画面を出さないため。キャンセルの理由はユーザーの文なので、コマンドに直接書かない）。その印（`<!-- tixforge:closed -->`・`<!-- tixforge:canceled -->`）のコメントが既にあれば、投稿し直さずに閉じるだけにする（閉じる前に中断した後）。

## 完了（PR がマージされたとき）

- Base が GitHub の default branch → issue がまだ開いていれば、コメントを投稿して `gh issue close <番号>` で閉じる。コメントは 1 行目に `<!-- tixforge:closed -->`（画面には出ない印。閉じ方の判定に使う）、2 行目からドキュメント言語で「<PR URL> のマージで完了」の一言。`bash <scripts>/issue-label.sh <番号> done`。
- Base が default branch 以外（develop など）→ issue がすでに閉じていれば（`issue-sync.sh check` の `status:` が `completed`・`closed-completed`：リリース済み）`bash <scripts>/issue-label.sh <番号> done`。開いていれば `bash <scripts>/issue-label.sh <番号> merged`。issue は閉じない（issue が閉じるのはリリースのとき。Actions の `tixforge-issue-sync` がリリース PR のマージで閉じて `tixforge:done` にする。無ければ、最初の commit の `Closes` により GitHub が閉じるが、ラベルは `tixforge:merged` のまま）。
- Actions の `tixforge-issue-sync` を入れていれば、同じ付け替えはマージの時点で済んでいる。スクリプトの出力が `unchanged` 相当でも問題ない。

## キャンセル（cancel）

- 確認一覧には「issue を削除せずに閉じる（予定なし）。`tixforge:canceled` にする」と載せる（`closed-not-planned` のときは「`tixforge:canceled` にする」だけ）。
- issue を **削除せずに**、コメントを投稿して `gh issue close <番号> --reason "not planned"` で閉じ（コメントは 1 行目に `<!-- tixforge:canceled -->`、2 行目からドキュメント言語で「キャンセル：<理由>」）、`bash <scripts>/issue-label.sh <番号> canceled` を実行する。
- チケットの状態が `closed-not-planned`（手で閉じられた）のときは、閉じる操作を省き、`issue-label.sh <番号> canceled` だけを行う。
- このチケットの開いている PR を閉じるなら、コメントを投稿して `gh pr close <PR>`（コメントは issue と同じ形：1 行目に `<!-- tixforge:canceled -->`、2 行目からドキュメント言語で「キャンセル：<理由>」）。
