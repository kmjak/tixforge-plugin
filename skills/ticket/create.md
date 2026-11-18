# /tixforge:ticket create — チケット作成

目的：チケットを、ユーザーとの対話で作る。**中身を書くのはユーザー**で、Claude は質問で引き出して形を整える。

1. `.tixforge/config.yml` が無い場合は、その旨を伝えて `/tixforge:project init` を案内し、止まる。
2. `.tixforge/config.yml` の `language` を使う（SKILL.md の「現在の状態」にある）。`references/github/create.md` を Read し、その「事前チェック」を行う。
3. **既存のチケットを指していないか**を確かめる：引数を `bash <scripts>/ticket-id.sh detect "<引数>"` に渡す（自分で解釈しない）。
   - `invalid: <語>` なら、`bash <scripts>/ticket-id.sh normalize <語>` のエラーを示し、正しい id を尋ねる。`rest:` が空でなければ、「説明の中で触れているだけ」も選択肢に出し、選ばれたら引数全体を説明として新しく作る（手順 4 へ）。
   - `id: <id>` で `rest:` も空でない（説明の中に id がある）なら、先に「既存のチケット `<id>` を指しているか、説明の中で触れているだけか」を尋ねる。触れているだけなら、引数全体を説明として新しく作る（手順 4 へ）。
   - `note:` の行があれば示し、その issue を指しているか尋ねる。
   - `id: <id>` なら `bash <scripts>/ticket-id.sh exists <id>` で確かめる（終了コード 3 なら、出力を示して止まる）：
     - `none` → そのチケットは無いことを伝え、`rest:` を説明として新しく作るか尋ねる。
     - `pull-request` → その番号は PR であることを伝えて止まる。
     - `issue` で、tixforge の目印の無い issue（`bash <scripts>/issue-sync.sh check <番号>` の 1 行目が `no-markers`）→ `references/github/create.md` の「GitHub 上で作られた issue を取り込む」に進む。
     - それ以外（既存のチケット）→ 状態を確かめる（`bash <scripts>/issue-sync.sh check <番号>` の `status:`）。
       - **`completed`・`canceled`・`closed-completed`・`closed-not-planned`・`closed`（完了・キャンセル済み・手で閉じられた）** → その旨を伝え、「このチケットを参考にして新しく作るか」を尋ねる。作るなら、元のチケットを読んで示し、下の対話を元の内容から始める（そのまま写さず、変えたい点をユーザーに尋ねる）。元のチケットには触らない。
       - **それ以外** → 新規作成ではない。何もせずに、編集なら `/tixforge:ticket edit <id>`、実装なら `/tixforge:dev <id>` を案内する。**既存のチケットを黙って上書きしない。**
4. `id: none` なら、`rest:` を作りたいものの説明として扱う（空なら尋ねる）。
5. **対話で埋める**：`<plugin>/templates/docs/ticket.md`（チケットの雛形）を Read し、その先頭のコメントの決まりに従う。何を作りたいか・なぜ必要かを尋ね、雛形の各項目を埋める。
   - 共通規約の「チケットを書く対話」に従う。
   - 受け入れ条件は「できた／できていない」を判定できる形までにする。何で確かめるか（テスト・ブラウザなど）は dev の Plan で決めるので、ここでは書かない。
   - **大きさ**：明らかに独立した機能が複数入っている（1 つの PR に収まりそうにない）なら、複数のチケットに分けて作ることを提案する。止めはしない（分けるかはユーザーが決める）。
   - **似たチケット**：タイトルが決まったら、似たものが既に無いか、`references/github/fetch.md` を Read し、その「探す」の似たチケットで探して示す。似たものがあれば、そのチケットを edit するか、このまま新しく作るかを尋ねる。
6. **下書きを示して合意を得る**（id はまだ決まっていないので `<ticket-id>` のまま）。一緒に「Base：<`repository.base_branch`>（既定）」を 1 行添える。hotfix などで別のブランチから作るなら、ユーザーがここで直す（質問は増やさない）。既定と違う Base になったときだけ、雛形の `## Base` の節を入れる。`references/github/create.md`「作成」の確認一覧も示し、「この内容で issue を作成する」ことへの確認を得る。
7. **作る**：「作る」の「作成」（`references/github/create.md`）を行う。id もここで決まる。
8. **次の一手**：作った id と issue の URL を伝え、AskUserQuestion で尋ねる（単一選択）：
   - **このチケットの開発を始める** — dev は明示起動のスキルなので、呼び出さずに `<plugin>/skills/dev/SKILL.md` と `<plugin>/skills/dev/run.md` を Read し、`bash <scripts>/project-status.sh` を実行してから、その手順で `<ticket-id>` を進める。説明に「長い作業になるので、新しいセッションで `/tixforge:dev <ticket-id>` から始めると文脈を節約できる」と添える。
   - **別のチケットを作る** — このセッションのまま、手順 3 からもう一度行う（まとめて何枚も作るとき）。
   - **ここで終わる** — `/tixforge:dev <ticket-id>` で始められることを伝えて終わる。

   状態ファイル（`.tixforge/<ticket-id>/state.md`）は create では作らない。
