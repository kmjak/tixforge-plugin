# /tixforge:dev — Plan

`run.md` の起動・状態ファイル・承認ゲートの決まりの中で行う。

## Phase 3 — Plan

目的：方針を具体的なブランチ・確かめ方・commit 計画に落とす。

0. **`Mode` が `small` なら**（`bash <scripts>/run-state.sh get <ticket-id> Mode`）、Research・Approach もまだ承認されていない。Plan のゲートで 3 つをまとめて示し、どれへの意見でも、そのセクションをその場で直して同じゲートを出し直す（巻き戻しにしない）。それ以外で **Approach を自動で通過していたら**（`bash <scripts>/run-state.sh passed <ticket-id> approach` が `yes`）、Plan を始める前に採用案を 1〜2 行示す（方針を確かめる最初の機会）。方針を変える意見が来たら：
   - `## Plan` が空 → Approach のゲートへのフィードバックとして扱う（巻き戻しにしない）。`bash <scripts>/run-state.sh set <ticket-id> Status approach:in-progress` にし、`## Approach` を書き直して自動通過の行を消し、Approach のゲートで止まる（`gates` に無くても止まる）。
   - `## Plan` に書いた後（Plan のゲートを含む）→ `rewind.md` を Read し、Approach に戻る。
1. **Base**（分岐元かつ PR の向き先）：`bash <scripts>/branch.sh base <ticket-id> [<ユーザーがこの Plan で指定したブランチ>]` の `base:`。終了コード 3（origin に無い）か 1（設定にも origin の既定にも無い）なら、どれにするか尋ねる。
2. **ブランチ**：slug（英小文字・数字・ハイフンだけ。ドキュメント言語によらず英語）を決め、`bash <scripts>/branch.sh name <ticket-id> <slug>` の `name:` にする（ローカルにもリモートにも無い名前、またはこの run の `Branch`）。
3. **受け入れ条件 → 確かめ方の対応表**：受け入れ条件の**全項目**に 1 行ずつ、何で・誰が確かめるかを決める。決まったら、表を一時ファイル（共通規約の一時ファイルの決まりで）に書き、`bash <scripts>/checks.sh put <ticket-id> <ファイル>` で取り込む（`## Plan` に表が描かれる。表は手で Edit しない。直すときは書き直して `put` し直す）。終了コード 3 なら、出力の問題を直して `put` し直す。終了コード 4 は手動確認が記録済みのとき：表を変えるなら `--reset` を付ける（記録は消えるので、確かめ直す）。
   ```markdown
   | # | 受け入れ条件 | 確かめ方 | 種別 |
   |---|--------------|----------|------|
   | 1 | 正しいパスワードでログインできる | `tests/login.test.ts`「正しいパスワードでログインできる」 | auto |
   | 2 | 誤ったパスワードでエラーが表示される | ログイン画面で誤ったパスワードを入れ、エラー表示を確認 | browser |
   | 3 | 登録メールが届く | 実際のメールボックスで受信を確認 | user |
   ```
   - **種別は 4 つ**（表には英語の固定の語で書く）：`auto`（テスト。`verify.sh` で実行される。テスト名まで書く）・`browser`（Claude がブラウザで）・`api`（Claude が API で）・`user`（ユーザーが確かめる）。できるだけ `auto` にする。ユーザーには個人の言語の言葉（自動・Claude（ブラウザ）・Claude（API）・ユーザー）で示す。
   - **種別は項目ごとにユーザーが選ぶ**：推奨と確かめ方の案を付け、AskUserQuestion で尋ねる（1 問 1 項目、選択肢は 4 つで推奨を先頭、1 回に 4 項目まで）。`Mode` が `small` なら、推奨の一覧を示して「推奨どおり」「個別に選ぶ」を 1 問だけ尋ね、個別に選ぶときだけ項目ごとに尋ねる。Claude（ブラウザ）・Claude（API）は、このセッションでその手段（ブラウザを操作するツール、アプリを起動するスキル、API を呼べる環境）が使えるかを先に確かめ、使えなければ選択肢の説明にそう書く。
   - 確かめ方を決められない条件は、止まってユーザーと決める（条件が曖昧なら `/tixforge:ticket edit` を提案）。
4. **順序付きの commit 分割**（各 commit の目的とおおまかな範囲）を決める。1 ブランチに収まらなければ、指摘して一緒にチケットを絞る。自動で分割しない。
5. Base・ブランチ・commit 一覧を `## Plan` に書き（対応表は手順 3 で描かれている）、`bash <scripts>/run-state.sh set <ticket-id> Branch <ブランチ>`・`bash <scripts>/run-state.sh set <ticket-id> Base <Base>` でヘッダを埋める。ゲート（`plan`）へ。要約では、`Mode` が `small` なら Research の要点・採用案と理由・Plan をまとめて示す（ここで 3 つを承認してもらう）。それ以外で Approach を自動で通過していれば採用案を 1〜2 行で先に示す。どちらでも最後に「承認の前に `/compact` してよい。その後『続けて』などで Implement に進む」と 1 行（個人の言語）添える（他のゲートには添えない）。
6. ブランチは Implement の「ブランチの準備」で作る。
