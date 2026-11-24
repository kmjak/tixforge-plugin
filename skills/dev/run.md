# /tixforge:dev — 6 フェーズで進める

起動・再開・状態ファイル・承認ゲートの決まり。各フェーズの手順は「フェーズの手順」のファイルにある。

## 起動と再開

`.tixforge/config.yml` の値は SKILL.md の「現在の状態」にある。`state.md` の本文と固定の文言（「手動確認」「Round」の見出しなど）は個人の言語（共通規約）で書く。読み取りに使うキー `Verification @`・`PR comment @`・`PR head @`・`Auto-fix:`・`Decision:`・`Fixed @`・`Manual re-check:` は英語のまま。id は `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する。

**状態ファイルの形式**（最初に行う）：`.tixforge/<ticket-id>/state.md` があれば `bash <scripts>/run-state.sh migrate --check <ticket-id>` を実行する。何か出たら、変わる内容を示し、AskUserQuestion で選ばせる。今の形式でないまま先に進めない。

- **更新する**（説明：書いた本文と `Status` はそのまま）— `bash <scripts>/run-state.sh migrate <ticket-id>`
- **run を消して最初から** — `state.md` と `history/` を削除し、新規として進める。チケット・ブランチ・commit は消さない。
- **中断する** — 何も変えずに止まる。

終了コード 5 なら、選ばせずに plugin の更新を伝えて止まる。他のエラーなら出力を示して止まる。

**チケットの準備**（新規・再開とも）：

- `references/github/fetch.md` を Read し、チケットを「取ってくる」（`<ファイル>` は `.tixforge/<ticket-id>/snapshot.md`。v2 の `ticket.md` は `pull` が `snapshot.md` に移す）。「変更あり」で進行中の run（状態ファイルがあり、`Status` が `done`・`canceled` 以外）があれば、`references/ticket-changed.md` を Read し、フェーズを戻すか決めてから再開する。チケットの状態が `canceled` なら下の 0.。`completed` なら：
  - `Status` が `pr:*` → 下の 1. の `pr:*` へ（マージで閉じた後の再開。pr.md の「再開」で `done` にする）。
  - 状態ファイルが無い・`done` → 完了済みと伝えて止まる。
  - それより前のフェーズ → チケットが閉じていることと `Status` を示し、どうするか尋ねる。

続けて：

0. **キャンセル済み**（チケットの状態か `Status` が `canceled`）→ 理由を示して止まる。やり直すなら `/tixforge:ticket create` で新しいチケットを作るよう伝える。
1. **`state.md` がある** → `Status` から再開する。
   - `<phase>:awaiting-approval`（`pr` 以外）→ 要約とゲートを再提示して待つ。compact の後にユーザーの発言があれば、再提示せずにゲートへの応答として扱う（承認なら次へ、フィードバックなら「承認ゲート」のとおり、質問なら答えて待つ）。
   - `<phase>:in-progress`（`pr` 以外）→ 書かれたセクションを読み直し（Implement ならブランチの `git log`・`git status` も）、続ける。途中成果を捨ててやり直すなら、**その前に**捨てるもの（commit の一覧など）を示して尋ねる。フェーズを戻すなら `rewind.md` を Read する。
   - `pr:*` → `<plugin>/skills/dev/pr.md` を Read し、その「再開」に従う。
   - `done` → 完了済み（`## PR` の結果付き）と伝え、どうしたいか尋ねる。勝手にやり直さない（やり直すなら新しいチケット）。PR がマージ済みでチケットが `open`・`in-review` なら、`references/github/close.md` を Read し、その「完了」を確かめる。
2. **`state.md` が無い**：
   - `references/github/labels.md` を Read し、その「dev の開始」で着手にする。
   - `bash <scripts>/run-state.sh init <ticket-id>` で状態ファイルを作り、Phase 1 を始める。

**いつでも**：ユーザーが前のフェーズに戻りたいと言ったら、`<plugin>/skills/dev/rewind.md` を Read し、その手順で戻す。

## 状態ファイル `.tixforge/<ticket-id>/state.md`

run の単一の真実。

- **ヘッダ表**（`Status`・`Branch`・`Base`・`Updated`・`Format`）は `bash <scripts>/run-state.sh set <ticket-id> <Status|Branch|Base> <値>` だけで変える。手で編集しない。
- **セクション**（`## Research`・`## Approach`・`## Plan`・`## Implementation Log`・`## Review`・`## PR`）は各フェーズが Edit で書く。見出しは英語のまま。
- セクションを書いたら、続けて `Status` を更新する。
- 次のフェーズへ進むときは、作業の前に `Status` を `<次のphase>:in-progress` にする。
- 戻る前の古い内容は `history/` にある（`rewind.md`）。参考にしてよいが、承認済みとして扱わない。

**Status のフォーマット：** 取りうる値は `bash <scripts>/run-state.sh statuses` が出すものだけ。意味：
- `<phase>:in-progress`：そのフェーズの作業中。`<phase>` は `research`・`approach`・`plan`・`implement`・`review`・`pr`
- `<phase>:awaiting-approval`：フェーズを終え、ゲートで承認待ち
- `pr:awaiting-review`：PR を出してレビュー待ち
- `pr:ready-to-merge`：Approve・CI・コンフリクトの条件を満たし、マージ待ち
- `done`：マージされて完了
- `canceled`：`/tixforge:ticket cancel` でキャンセル済み

## 承認ゲート

各フェーズの終わりがゲート。止まるかは `gates`（「この人が使う値」）と下の「止まる条件」で決まる。

- **`gates` にあるフェーズ**：セクションを書く → `Status` を `<phase>:awaiting-approval` → 短い要約を出して**止まる**。「続けて」等で次へ。
- **`gates` に無いフェーズ**：止まる条件が無ければ**自動で通過**する。セクションの末尾に `> ` と `<scripts>/messages.yml` の `gate_auto_pass`（個人の言語。無ければ `en`）をそのまま書き、`Status` を `<次のphase>:in-progress` にし、一行伝えて続ける（要約は次に止まるゲートでまとめる）。止まる条件があれば、`gates` にあるときと同じく止まる。
- **`pr` は常に止まる**。

| フェーズ | `gates` に無くても止まる条件 |
|----------|------------------------------|
| research | 決定の無い未決事項、未解決の疑問、要件・受け入れ条件の解釈や範囲を左右する未確認の仮定がある |
| approach | 採用案にユーザーの判断が要る（拮抗する選択肢、チケットの解釈、置いた仮定、`frontend.md` にパッケージの節が無い・設計の規則から外れる） |
| plan | **常に止まる**（確かめ方をユーザーが項目ごとに選ぶため） |
| implement | ユーザーの手動確認が残っている（Review の自動修正後のやり直しは Review の手順 9 で） |
| review | 周回を終えて、決定の無い `△` か手動確認のやり直しが残っている（手順 9 で `review:in-progress` のまま尋ね、全て決まるまでゲートに進まない） |

- **フェーズ内で小刻みに止めない。** Implement は commit ごとに確認しない（分割は Plan で承認済み）。
- ゲートでフィードバックが来たら、現フェーズを直し、セクションを書き直して同じゲートを再提示する。

## フェーズの手順

フェーズに入るとき（次のフェーズへ進む・再開・差し戻し・巻き戻しを含む）、そのフェーズのファイルを、このセッションでまだ読んでいなければ Read し、その手順で行う。

| フェーズ（`Status` の `<phase>`） | ファイル |
|------|------|
| research | `<plugin>/skills/dev/phase/research.md` |
| approach | `<plugin>/skills/dev/phase/approach.md` |
| plan | `<plugin>/skills/dev/phase/plan.md` |
| implement | `<plugin>/skills/dev/phase/implement.md` |
| review | `<plugin>/skills/dev/phase/review.md` |
| pr | `<plugin>/skills/dev/pr.md` |
