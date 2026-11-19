# /tixforge:dev — Phase 6：PR（強ゲート）

目的：明示的な確認の後にだけ PR を出し、完了まで見届ける。

「PR と紐づける」（`references/github/pr.md`）を Read する。

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

## PR の準備

1. `Status: pr:in-progress` にする。「PR の存在確認」で PR が無いことを確かめる。
   - 開いている PR があれば（PR を出した後に Implement 以前へ戻した run など）、新しく作らない：その URL を `## PR` に書き、「修正の push」で push していない commit（`git fetch origin <ブランチ>` の後、`git log --oneline origin/<ブランチ>..<ブランチ>`）を push する（最後は停止せずに「PR の状況確認」へ進む）。
2. 取り返しのつかない操作の前に、次を提示する：**ブランチ**・**向き先ブランチ**（ヘッダ表の `Base`）・**PR タイトル**・**PR 本文の下書き**（本文はドキュメント言語。`state.md` から写す内容も、ドキュメント言語で書き直す。タイトルは `docs/context/commit.md` の件名の形式と `Language:` に従う（squash でマージされると main の commit になるため）。`commit.md` が無ければドキュメント言語）。
   - **本文**：`bash <scripts>/pr-template.sh` が `path: <パス>` を出したら、その既定の PR テンプレートの見出しに沿って埋める。`path: none` なら `<plugin>/templates/github/pull_request_template.md` の見出しで書く（見出しはドキュメント言語に訳し、テンプレートのコメントは書かない）。
   - **受け入れ条件**（対応表の各項目の確かめ方と結果）と**検証**は必ず書く。既定のテンプレートに同じ役割の見出し（Testing など）があればそこに書き、無ければ紐付けの行（それを含む見出しがあればその見出し）より前に足す。検証には、HEAD に対する `Verification @ <hash>: …` の行と、手動確認の結果（誰が・どう確かめたか）を書く。テストのログは載せない（CI の画面で見られる）。
   - **検証の行**：`## Implementation Log` に HEAD（`+dirty` 無し）に対する全て pass の行（または `commands: {}` のときの行）が無ければ、下書きを示す前に `run.md` の「検証」を行い、出力の 1 行目を Log に書き写す（失敗があれば PR に進まず、`Status: implement:in-progress` に戻る）。行はそのまま写す。検証コマンドが無いときの行だけ、その言葉をドキュメント言語に直す。
   - **方針**は、Approach で合意した**結論と理由を 2〜3 行**だけ書く。
   - 本文に、「PR と紐づける」の紐付けを必ず入れる。
3. `Status: pr:awaiting-approval` にして、**停止して明示的な確認を求める。**
4. 確認されたら：
   - push の**直前に**、`references/github/fetch.md` を Read し、チケットを「取ってくる」。変更があったら、PR を作らずに停止し、`references/ticket-changed.md` で戻すか尋ねる（実装が変更後のチケットを満たしているとは限らないため）。
   - `Status` は `pr:awaiting-approval` のまま push して（`git push -u origin <ブランチ>`）PR を作成する（例：`gh pr create --base <Base> --body-file <一時ファイル>`。`--fill` は使わず本文を明示する）。
   - 作成後に「PR と紐づける」の「紐付けの確認」を行い、`references/github/labels.md` を Read し、その「PR の作成」でレビュー中にする。
5. PR タイトル・向き先・URL と `PR head @ <作成時の HEAD の短い hash>` を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、停止する。ユーザーには、レビューが進んだら（1 人なら CI が通ったら）`/tixforge:dev <ticket-id>` で再開するよう案内する。

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

`conflict`・`ci_failing`・`changes_requested` への対応はブランチに commit し、`## Implementation Log` に「PR 対応：<判定>」（個人の言語）として記録してから、「修正の push」を行う。対応が方針や計画の変更を伴う大きさなら、その場で直さずに停止し、`rewind.md` を Read し、その手順で戻るかユーザーに尋ねる（PR を出した後に戻ると、追加の commit は既存の PR に入り、設定によっては Approve が外れる）。

## 修正の push

PR を出した後の commit を push する。PR 本文の検証は書き換えず、検証の結果を PR にコメントする（いつ・どの commit で確かめたかを残し、レビュアーが変化に気づけるように）。

1. **検証**（`run.md`「検証」。影響する手動確認もやり直す）を行い、出力の 1 行目を `## Implementation Log` に書き写す。
2. 変更内容・検証結果と、PR に投稿するコメント（ドキュメント言語。何に対応したかを 1 行、新しい `Verification @ <hash>: …` の行（「PR の準備」の検証の行と同じ写し方）、やり直した手動確認の結果）を一覧で示して**停止し、確認を得る**。PR を出した後に Approach か Plan に戻した run で、方針か対応表が変わっていれば、PR 本文の方針・受け入れ条件の更新案（`gh pr edit`。検証は書き換えない）も一覧に載せる。push とコメントの投稿は別のコマンドで行い、確認画面がそれぞれ出る（一覧で合意した内容だと伝える）。
3. push し（済んでいれば飛ばす）、コメントを `gh pr comment <PR> --body-file <一時ファイル>` で投稿して、`## Implementation Log` に `PR comment @ <HEAD の短い hash>`（英語の固定キー）と記録する。呼んだ側に続きの指示があればそれに従い、無ければ `Status: pr:awaiting-review` にして停止する。
