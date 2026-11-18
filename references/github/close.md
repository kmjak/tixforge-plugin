# GitHub：チケットを閉じる

- 操作したら、スクリプトが出力した一行をユーザーに伝える。
- ラベルが無いというエラーなら、`/tixforge:project init` の再実行（`issue-label.sh setup`）でラベルを作れることを伝える。

## 完了（PR がマージされたとき）

- 閉じるときのコメントは一時ファイルに書き、`--comment "$(cat <一時ファイル>)"` で渡す（改行と記号をそのまま渡すため。理由はユーザーの文なので、コマンドに直接書かない）。
- Base が GitHub の default branch → issue がまだ開いていれば `gh issue close <番号> --comment <コメント>` で閉じる。コメントは 1 行目に `<!-- tixforge:closed -->`（画面には出ない印。閉じ方の判定に使う）、2 行目からドキュメント言語で「<PR URL> のマージで完了」の一言。`bash <scripts>/issue-label.sh <番号> done`。
- Base が default branch 以外（develop など）→ issue がすでに閉じていれば（`issue-sync.sh check` の `status:` が `completed`・`closed-completed`：リリース済み）`bash <scripts>/issue-label.sh <番号> done`。開いていれば `bash <scripts>/issue-label.sh <番号> merged`。issue は閉じない（issue が閉じるのはリリースのとき。Actions の `tixforge-issue-sync` がリリース PR のマージで閉じて `tixforge:done` にする。無ければ、最初の commit の `Closes` により GitHub が閉じるが、ラベルは `tixforge:merged` のまま）。
- Actions の `tixforge-issue-sync` を入れていれば、同じ付け替えはマージの時点で済んでいる。スクリプトの出力が `unchanged` 相当でも問題ない。

## キャンセル（cancel）

- 確認一覧には「issue を削除せずに閉じる（予定なし）。`tixforge:canceled` にする」と載せる（`closed-not-planned` のときは「`tixforge:canceled` にする」だけ）。
- issue を **削除せずに** `gh issue close <番号> --reason "not planned" --comment <コメント>` で閉じ（コメントは 1 行目に `<!-- tixforge:canceled -->`、2 行目からドキュメント言語で「キャンセル：<理由>」）、`bash <scripts>/issue-label.sh <番号> canceled` を実行する。
- チケットの状態が `closed-not-planned`（手で閉じられた）のときは、閉じる操作を省き、`issue-label.sh <番号> canceled` だけを行う。
- このチケットの開いている PR を閉じるなら、`gh pr close <PR> --comment <コメント>`（コメントは issue と同じ形：1 行目に `<!-- tixforge:canceled -->`、2 行目からドキュメント言語で「キャンセル：<理由>」）。
