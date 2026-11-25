# /tixforge:dev — Phase 6：PR — PR を出す

`pr.md`（再開・PR の存在確認）の中で行う。

## PR の準備

1. `Status: pr:in-progress` にし、「PR の存在確認」で PR が無いことを確かめる。
   - 開いている PR があれば（PR を出した後に Implement 以前へ戻した run など）、新しく作らない：URL を `## PR` に書き、`pr/follow.md` の「修正の push」（未読なら Read する）で、push していない commit（`git fetch origin <ブランチ>` の後、`git log --oneline origin/<ブランチ>..<ブランチ>`）を push する（最後は止まらずに「PR の状況確認」へ）。
2. 取り返しのつかない操作の前に、次を提示する：**ブランチ**・**向き先ブランチ**（ヘッダ表の `Base`）・**PR タイトル**・**PR 本文の下書き**・**検証のコメントの下書き**。本文とコメントはドキュメント言語（`state.md` から写す内容も書き直す）。タイトルは commit の件名と同じ決まり（`phase/implement.md` の commit の項：`docs/context/commit.md`、`Source:` があればそのファイル、無ければ直近の `git log` の件名。squash でマージされると Base の commit になるため）。
   - **本文の見出し**：`bash <scripts>/pr-template.sh` が `path: <パス>` を出したら、その PR テンプレートの見出しに沿う。`path: none` なら `<plugin>/templates/github/pull_request_template.md` の見出し（ドキュメント言語に訳し、テンプレートのコメントは書かない）。
   - **受け入れ条件**（対応表の各項目の確かめ方と結果）と**検証**は必ず書く。テンプレートに同じ役割の見出し（Testing など）があればそこ、無ければ紐付けの行（それを含む見出しがあればその見出し）より前に足す。検証には、HEAD に対する `Verification @ <hash>: …` の行と、確かめた手段の詳細は PR のコメントにあることを 1 行書く。テストのログは載せない（CI の画面で見られる）。
   - **方針**は、Approach で合意した**結論と理由を 2〜3 行**だけ。
   - 本文に「PR と紐づける」の紐付けを必ず入れる。
   - **検証の行**：下書きを示す前に `bash <scripts>/verify.sh --reuse` を実行する（今の commit で全て通った結果があれば、実行せずにその行を出す）。1 行目が Log の最新の `Verification @` と違えば Log に書き写す。失敗か `+dirty` があれば、PR に進まず `Status: implement:in-progress` に戻り、`phase/implement.md` の「検証」で扱う。行はそのまま写す。検証コマンドが無いときの行だけ、その言葉をドキュメント言語に直す。
   - **検証のコメント**：PR を作った直後に投稿する。1 行目に `Verification @ <hash>: …` の行、その下に**確かめた手段ごとに `###` の小見出しを 1 つ**立て、何をして何が分かったかを書く（レビュアーが何を確認済みか読むだけで分かるように。本文が長くならず、修正の push の後のコメントと同じ形で並ぶので、コメントにする）。テストのログ全体は載せない。
     - **検証コマンド**：`.tixforge/config.yml` の `commands` のキーごとに、`### <キー>`、そのコマンドを ` ```bash ` のコードブロックで、続けて結果（`pass` / `fail`）。件数などの要約がログ（`verify.sh` が残す。`git rev-parse --absolute-git-dir` の出力の下の `tixforge/verify/<キー>.log` を Read する）の最後にあれば、1〜2 行まで写してよい。
     - **手動確認**：対応表の手動の行ごとに、`### <確かめたこと>（#<番号>）`、番号付きの操作の手順（開いた URL・押したもの・入れた値）、続けて結果（何が見えたか、誰が・何で確かめたか）。`## Implementation Log` の手動確認の記録から写す。確かめなかった行は理由を書く。
     - 例（ドキュメント言語が日本語のとき）：

       ~~~markdown
       Verification @ 59a2058: test pass, lint pass

       ### test
       ```bash
       pnpm test
       ```
       pass（Tests 42 passed）

       ### lint
       ```bash
       pnpm lint
       ```
       pass

       ### トップにボタンが出る（#2）
       1. `pnpm dev` で起動し、http://localhost:3000/ を開く
       2. ヘッダの右に「新規作成」ボタンがあるかを見る

       結果：ボタンが出ていた（Claude がブラウザのスクリーンショットで確かめた）
       ~~~
3. `Status: pr:awaiting-approval` にして、**止まって明示的な確認を求める。**
4. 確認されたら：
   - push の**直前に**、`references/github/fetch.md` を Read し、チケットを「取ってくる」。変更があれば PR を作らずに止まり、`references/ticket-changed.md` で戻すか尋ねる（実装が変更後のチケットを満たすとは限らないため）。
   - `Status` は `pr:awaiting-approval` のまま、`git push -u origin <ブランチ>` して PR を作る（例：`gh pr create --base <Base> --body-file <一時ファイル>`。`--fill` は使わず本文を明示する）。
   - 作ったら、検証のコメントを `gh pr comment <PR> --body-file <一時ファイル>` で投稿する（確認画面が出る。手順 2 で合意した内容だと伝える）。
   - 「PR と紐づける」の「紐付けの確認」を行い、`references/github/labels.md` を Read し、その「PR の作成」でレビュー中にする。
5. PR タイトル・向き先・URL と `PR head @ <作成時の HEAD の短い hash>` を `## PR` に書き、`Status: pr:awaiting-review` にして URL を報告し、止まる。レビューが進んだら（1 人なら CI が通ったら）`/tixforge:dev <ticket-id>` で再開するよう案内する。
