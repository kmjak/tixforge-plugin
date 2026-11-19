# GitHub：PR と issue の紐付け

dev の Implement（最初の commit）と PR フェーズで読む。

## commit と PR 本文

- **最初の commit のメッセージに `Closes #<番号>` のトレーラーを入れる**（本文の末尾のトレーラーの段落。Co-Authored-By などと同じ段落で、順は問わない）。Base が default branch でも省かない（develop 運用では、これが default branch に入ったリリースで issue を閉じる）。
- **PR 本文の末尾に `Closes #<番号>` を必ず入れる**（下書きを示す時点で入っていること）。

## 紐付けの確認

- Base が default branch なら、`gh pr view <PR> --json closingIssuesReferences` にその番号が含まれることを確かめる。含まれなければ本文を直して（`gh pr edit`）もう一度確かめる。
- Base が default branch 以外なら、本文に `Closes #<番号>` があることだけ確かめる。
