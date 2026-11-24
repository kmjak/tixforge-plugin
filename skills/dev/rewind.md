# /tixforge:dev rewind — 前のフェーズに戻す

## Phase 1 — 準備

目的：戻す run と、今の状態を示す。

1. **準備**：チケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる。SKILL.md の「現在の状態」の進行中の run を候補として示す）。`.tixforge/<ticket-id>/state.md` を読む。
   - 無ければ、戻す run が無いことを伝えて止まる（`/tixforge:dev <ticket-id>` で始められる）。
   - `Status` が `done`・`canceled` なら拒否する。
2. **今の状態を示す**：`Status`、書かれているセクション、`Branch` にブランチがあればその commit（`git log --oneline <Base>..<Branch>`）と未コミットの変更の有無、リモートブランチ（`git ls-remote --heads origin <Branch>`）と開いている PR（`gh pr list --head <Branch> --state open`）。

## Phase 2 — 戻り先の選択

目的：戻り先・ブランチの扱い・理由を決める。

3. **戻り先を選ぶ**（Review の「計画の見直し」「方針の見直し」から来たなら、戻り先は決まっているので飛ばす）：AskUserQuestion で、今のフェーズより前のフェーズ（**Research（最初から）**・**Approach**・**Plan**・**Implement** のうち今より前のもの）と **戻さない** から選んでもらう（単一選択）。戻したい理由を聞いていれば、それに合う戻り先に推奨を付ける（例：commit 分割を変えたい → Plan、方針から変えたい → Approach）。
   - 選択肢は最大 4 つなので、今が Review・PR のときは Research（最初から）を出さず、質問文に「最初からやり直すなら Research と入力」と添える。
   - 戻り先が無い（今が Research）なら、「手放す」「戻さない」を尋ねる。
   - 「戻さない」なら、何もせずに止まる。
4. **Research（最初から）を選んだとき**：続けて「自分で続ける」「このチケットを手放す（他の人に渡す）」を尋ねる。手放すなら下記「手放す」へ。
5. **ブランチの扱い**（Plan 以前に戻り、ブランチに commit があるとき）：尋ねる：
   - **このブランチの上で続ける** — commit を残し、その上でやり直す。`## Implementation Log` は残す（既存の commit の記録なので）。
   - **新しいブランチで作り直す** — 次の Plan で別の名前のブランチを決める。古いブランチは「残す」か「削除する」かも尋ねる。削除するなら、マージされていない commit があるので `git branch -D` を使う（取り消せないことを伝える）。今そのブランチにいれば、先に `Base` に切り替える（未コミットの変更があれば止まる。勝手に stash や破棄をしない）。リモートブランチがあれば削除するか（`git push origin --delete <Branch>`）、開いている PR があれば閉じるか（`gh pr close <PR>`）も同じ一覧で尋ねる。
   - PR を出した後（`pr:*`）から戻し、同じブランチで続ける（Implement に戻す・「このブランチの上で続ける」）なら、戻り先に関係なく、この後の commit は既存の PR に入ること、リポジトリの設定によっては Approve が外れることを伝える。
6. **理由**を尋ねる。**きっかけ**（`--trigger`）は聞かずに決める：呼び出し元が示したもの（Review の見直し → `review`、Implement で計画どおりに進められない → `implement`、PR の対応 → `pr`、チケットの変更 → `ticket`）、示していなければ `human`。
   - **分類**（`--category`）：AskUserQuestion で 1 つ選んでもらう（単一選択。選択肢は下の `other` 以外の 4 つ。きっかけと分かったことから推奨を付ける）。「Other」に書かれたら `other` にし、その文を理由にする。値は `bash <scripts>/run-state.sh categories rewind` が出すものだけ：
     - `misread`：要件・チケットの読み違い
     - `constraint`：既存のコード・制約を知らなかった
     - `infeasible`：技術的に無理だった・方針が誤っていた
     - `spec_change`：仕様が変わった（人間の気が変わった）
     - `other`：その他
   - 続けて、理由を 1 行で尋ねる（Review の見直しから来たなら、その指摘の番号と要約でよい。分類で Other に書かれたなら尋ねない）。

## Phase 3 — 確認と実行（ゲート）

目的：行うことに 1 回の確認を得てから戻す。

7. **行うことを一覧で示し、1 回の確認でまとめて承認をもらってから実行する**：
   - `## Approach` が書かれていて、Approach 以前に戻す（方針を捨てる）なら、`references/github/record.md` を Read し、「記録を残す」を行う（状態ファイルから方針が消える前に）。
   - `bash <scripts>/run-state.sh rewind <ticket-id> <phase> --category <分類> --trigger <きっかけ> --reason "<理由>"`（「このブランチの上で続ける」なら `--keep-log` を付ける）。出力された history のファイルを伝える（戻したセクションは消えずに、このファイルに移る）。
   - 「新しいブランチで作り直す」なら、`bash <scripts>/run-state.sh set <ticket-id> Branch —` でヘッダのブランチを外し、決めたブランチの片付けを行う。
8. 戻したフェーズから、`<plugin>/skills/dev/run.md` の「フェーズの手順」に従い、そのフェーズのファイルを Read して続ける。

## 手放す（チケットを他の人に渡す）

手順 3・4 で「手放す」を選んだときに、手順 5 以降の代わりに行う分岐。番号は振らない。

- 手順 2・5 と同じくブランチの扱いを尋ね、理由を 1 行で尋ねる（分類は尋ねない）。
- `references/github/labels.md` を Read する（`## Approach` が書かれていれば `references/github/record.md` も）。行うことを一覧で示し、確認を得てから実行する：
   - `## Approach` が書かれていれば、「記録を残す」を行う（見出しは「手放す」）。
   - 「状態を変える」で手放す（着手前に戻し、担当者から自分を外す）。
   - ブランチの片付け（決めたもの）。
   - 手元の run（`.tixforge/<ticket-id>/state.md` と `history/`）と、チケットの `snapshot.md`・`.snapshot.md.hash` を削除する：`bash <scripts>/run-state.sh release <ticket-id> --reason "<理由>"`（手で消さない）。
- 行ったことを伝える。
