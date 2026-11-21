# tixforge

チケット駆動でアプリ開発を回す Claude Code の plugin。チケットを作り、1 つのチケットを **Research → Approach → Plan → Implement → Review → PR** の 6 フェーズで実装から PR まで進める。進捗は 1 つのファイルに集約するので、どのフェーズで止めても後から再開できる。

| コマンド | 内容 |
|--------|------|
| `/tixforge:project` | `init`：プロジェクトを tixforge で使える状態にする。`update`：設定を変える・v2 の LT を issue に移す・テンプレートを最新にする。`setup`：自分だけの言語・ゲートを決める |
| `/tixforge:ticket` | `create`：チケットを対話で作る。`edit`：書き換える。`cancel`：キャンセル済みにする |
| `/tixforge:dev` | `<id>`：6 フェーズで進める（再開も同じ）。`rewind <id>`：前のフェーズに戻す |
| `/tixforge-panel` | 自分の PR とチケットを右側のパネルに出す（下記「パネル」） |

典型的な流れ：`/tixforge:project init` → `/tixforge:ticket ログイン画面を作りたい` → `/tixforge:dev GT-000001`

3 つのスキルは明示起動専用（Claude が勝手に起動しない）。引数なしで起動すると、選択肢を出す。`/tixforge-panel` はスキルではなく、plugin の mod のコマンド。

**GitHub が必須**：チケットは GitHub issue に、変更は PR にする。GitHub を使わないなら tixforge v2 のまま使う。v2 から上げるときは下記「v2 からの移行」。

## 導入

```sh
claude plugin marketplace add kmjak/tixforge-plugin
claude plugin install tixforge@tixforge
```

セッションの中なら `/plugin marketplace add kmjak/tixforge-plugin` → `/plugin install tixforge@tixforge`。次に起動するセッションから使える。更新は `claude plugin marketplace update tixforge` → `claude plugin update tixforge@tixforge`（`version` を上げたリリースだけが届く）。

plugin には、スキル 3 つ・Review 用の agent 2 つ（`tixforge:reviewer`・`tixforge:quality-reviewer`）・hook 2 つ（下記「hook」）・パネルの mod が入っている。個別に導入・登録するものは無い。

## v2 からの移行

**更新する前に**：GitHub を使わない（v2 で `host: none` だった）なら、v3 に上げずに v2 に留まる（導入の節の更新コマンドを実行しない）。v3 は GitHub が必須。

導入の節の更新コマンド（`claude plugin marketplace update tixforge` → `claude plugin update tixforge@tixforge`）を実行し、新しいセッションを始めた後に、当てはまるものを上から順に行う。

| すること | 対象 |
|---|---|
| `/tixforge:project update` で、LT のチケットを issue に移す。進行中の LT の run は、新しい GT の id で始め直す。済むまで update 以外のスキルは止まる（Actions の更新などは、もう一度 update を起動して行う） | `tracker: local` か `host: none` だった人で、GitHub を使う人 |
| 進行中の run は続けられる。`/tixforge:dev <id>` で再開すると、state.md を「更新する」「run を消して最初から」「中断する」から選ぶよう聞かれる。「更新する」の後、v2 の `ticket.md` を `snapshot.md` に移してよいかも聞かれる。「run を消して最初から」でも、前のブランチと commit は残る（新しい run は別の名前のブランチを作る。要らなければ自分で消す） | 進行中の GT の run がある人 |
| `/tixforge:project update` の「テンプレートと Actions を最新にする」で、コピーした workflow を上げる（上げないと v2 の閉じ方のまま。issue はリリースではなく develop へのマージで閉じる） | Actions を入れた人 |
| `.tixforge/config.yml` の `repository.close_issues` を消す（Actions を先に上げてから。`/tixforge:project update` の「設定の値を変える」で尋ねる） | `close_issues` を書いていた人 |
| 動きの変化を知る：develop へのマージでは issue は閉じず `tixforge:merged` になり、main に入ったときに閉じて `tixforge:done` になる（下記「issue が閉じる時点」） | develop 運用で、`close_issues: merge` だった人か、キーを書かずに `tixforge-issue-sync` を使っていた人 |
| 任意：自分だけの言語・ゲートを `/tixforge:project setup` で決める。自分の PR とチケットを `/tixforge-panel` で横に出す | 全員 |

`base_branch` が GitHub の default branch（main など）だった人は、issue が閉じる時点は変わらない。上の表の対象に当たらなければ、更新の後にすることは無い（残った `host`・`close_issues` のキーは読まれないだけで、`/tixforge:project update` の「設定の値を変える」で消せる）。

## 置き場所

| パス | 内容 | git |
|------|------|-----|
| `.tixforge/config.yml` | 設定（下記） | 管理する（チームで共有） |
| `.tixforge/config.local.yml` | 個人の `language`・`gates`（`/tixforge:project setup` が書く） | 管理しない |
| `.tixforge/.gitignore` | `*`・`!.gitignore`・`!config.yml`。それ以外を git から外す（プロジェクトの `.gitignore` は触らない） | 管理する |
| `.tixforge/<id>/snapshot.md` | dev がチケットの issue から取った版（edit は `editing.md` で書き換え、書き戻したら消す） | 管理しない |
| `.tixforge/<id>/state.md` | run の状態（Status・ブランチ・各フェーズの記録） | 管理しない |
| `.tixforge/<id>/history/` | 前のフェーズに戻したときの古い記録 | 管理しない |
| `.tixforge/events.jsonl` | run の過程のイベントログ（下記「イベントログ」） | 管理しない |
| `docs/context/**` | サービス・ドメインの知識、commit 規約（`commit.md`）、フロントエンドの設計（`frontend.md`） | 管理する |

チケットと run の状態は各個人の作業場所なので git に載せない。PR に載せるとレビュアーが検討過程に引っ張られるため。PR 本文には、合意した方針の結論と理由だけを書く。

## 設定（`.tixforge/config.yml`）

```yaml
language: ja            # チケット・context・PR の本文・issue を書く言語（PR のタイトルは commit 規約に合わせる）。会話と run の記録の言語の既定
commands:               # dev が検証で書いた順に実行する（無ければ {}）
  test: npm test
repository:
  base_branch: main     # dev がブランチを切る元・PR の向き先
gates: [plan, pr]       # 必ず止まるゲート（pr は常に止まる）
```

`/tixforge:project init` が答えのたびにキーを書き、終わった時点で全てのキーがそろう（途中で止まっても、再実行で続きから進む）。値を変えるのは `/tixforge:project update`。自分だけの `language`・`gates` は `/tixforge:project setup` で `.tixforge/config.local.yml` に書く（git に載らない）。全てのキーと意味・値・書き方は [`references/config.md`](references/config.md) にある。

## フロントエンドの設計

フロントエンドがあるプロジェクトでは、デザインパターン（コンポーネントとディレクトリの構成）・メインカラーとサブカラー・状態管理を、作るものに合わせた推奨 3 つか自由入力から選び、`docs/context/frontend.md` に保存する。パターンは名前だけでなく tree と置き場所・依存の規則で書き、色は値を写さずトークンのファイル（CSS 変数・Tailwind の theme など）の場所を書く（まだ無ければ初期値を書き、最初に画面を作るチケットでトークンのファイルにする）。

- 決めるのは `project init`（context の後）か `project update` の「フロントエンドの設計を決める・見直す」。init では、今決めるか後にするかを選べる。設計が無いうちは、dev は近くの既存のコードに合わせる（`frontend.md` はあるのに触るパッケージの節が無ければ、Approach で今決めるか尋ねる）。既存の散らかったコードに目指す形を決めたときは、今のディレクトリを移すまで規則の対象外にする（置き場所も色の直書きも）。Review が指摘するのは、その差分で足した・変えた部分だけ。
- dev の Approach は作るファイルの置き場所と使うトークンを設計と照らし、Review では `tixforge:reviewer` が規則やトークンの違反を指摘する。

## チケット

- **id**：`GT-000123`（issue #123）。`gt-000123`（大文字小文字は問わない）・`#123`・`123` でも指せる。桁数が違う id（`GT-00123`）はエラーになる（決まりの全体は `scripts/ticket-id.sh` の冒頭）。
- **create**：中身はユーザーが書き、Claude は質問で引き出す（案を出すのは「考えて」と頼んだときだけ）。埋め方は 2 つ：項目を 1 つずつ聞く方法と、作りたいものの説明をまとめて渡す方法（Claude が説明を全項目に振り分けた下書きを作り、言い換えた所は（推測）として示して確かめ、説明に無い所だけを尋ねる。説明に無いことは書き足さない）。`/tixforge:ticket <作りたいもの>` のように文を渡すと、背景・要件・受け入れ条件・対象外のうち 2 つ以上に当たる説明なら、まとめて渡す方法で始まる。edit で変更をまとめて渡すことも、`project init` で context やリポジトリの設定をまとめて渡すこともできる。似たチケットがあれば示し、大きすぎれば分割を提案する。作った後は「開発を始める／別のチケットを作る／終わる」を選べる。
- **既定と違うブランチから作る**チケット（hotfix など）は、チケットに `## Base` の節を書く。

## dev の 6 フェーズ

| # | フェーズ | 内容 |
|---|----------|------|
| 1 | Research | チケットと `docs/context/**` を読み、コードの調査は原則 Explore agent に任せる（触るファイルが決まっていて数ファイルで済むときは自分で読む）。チケットの未決事項を 1 項目ずつ片付ける（何を作るかの決定はチケットに書き戻し、どう作るかの決定は Approach の表へ） |
| 2 | Approach | 実装方針（選択肢・採用案・トレードオフ）を決める。画面を触るなら、フロントエンドの設計（`frontend.md`）に沿って置き場所と使うトークンを書く。判断が要るときや `gates` にあるときは止まって合意し、それ以外は Plan の最初に採用案を示す |
| 3 | Plan | Base・ブランチ・**受け入れ条件 → 確かめ方の対応表**・commit 分割。確かめ方の種別（自動／Claude（ブラウザ）／Claude（API）／ユーザー）は項目ごとにユーザーが選ぶ。Plan は常に止まる（承認の前に `/compact` してよい） |
| 4 | Implement | 計画どおりに実装・commit し、検証コマンド（`verify.sh`）と手動確認を通す。context と矛盾しないかもここで確かめる |
| 5 | Review | 2 つの reviewer agent を並列に起動する。`tixforge:reviewer` は合意とのズレ（相違・未実装・合意外の変更・決定の無い未決事項）、`tixforge:quality-reviewer` は品質を見る。指摘ごとに自動修正（○：聞かずに直す・×：直さない・検討：後で尋ねる）を付け、○ があれば Implement に戻って直し、次のラウンドを回す（Round 3 まで。2 ラウンド目からは前のラウンドからの差分と、直した指摘が直ったかを見る）。周回を終えたら、検討の指摘を推奨と一緒にまとめて示し、修正・計画の見直し・方針の見直し・受け入れをユーザーが選ぶ |
| 6 | PR | 明示的な確認の後にだけ push して PR を出し、レビュー・CI を見届ける（tixforge はマージしない）。PR 本文に受け入れ条件と検証の結果を載せ、PR を出した後の修正のたびに検証の結果を PR にコメントする |

- **ゲート**：`gates` にあるフェーズでは必ず止まる。無いフェーズは、止まる条件（未決事項・ユーザーの判断・Review で検討とした指摘など）が無ければ自動で通過する。PR の前は常に止まる。止まった所が再開点になる。
- **Status**：`<phase>:in-progress`・`<phase>:awaiting-approval`、PR 後は `pr:awaiting-review`・`pr:ready-to-merge`（Approve・CI・コンフリクトの条件を満たしマージ待ち）。`done` はマージされたときだけ。
- **巻き戻し**：`/tixforge:dev rewind <id>`（または dev の最中に「Plan からやり直したい」と頼む）で、前のフェーズに戻す。後のフェーズの記録は `history/` に移る。ブランチに commit があれば、そのブランチの上で続けるか作り直すかを選ぶ。チケットは、ここから他の人に渡せる（手放す）。

## GitHub 連携

- issue が正本。チケットの全文と、tixforge が書いたことを確かめるハッシュを本文に載せる。本文とタイトルは GitHub 上で直接編集せず、`/tixforge:ticket edit` で変える（直接編集されると検知して、取り込むか尋ねる）。2 人が同時に edit しても、後から書き戻す人の古いコピーは拒否される。
- GitHub の画面で作られた issue も、`/tixforge:ticket create #<番号>` で取り込める（`project init` で issue フォームを入れておくと、見出しがそろう）。
- tixforge が issue に投稿するコメントは、キャンセル・巻き戻し・手放すときの判断の記録と、クローズのときの一言だけ（PR には、修正のたびに検証の結果をコメントする）。コメントを編集・削除しない。

状態ラベル（`tixforge:todo`・`in-progress`・`in-review`・`merged`・`done`・`canceled`）は常に 1 つだけ付く。それぞれの意味は、GitHub のラベルの説明（`project init` がドキュメント言語で作る。すでにあるラベルの説明は変えない）にある。直接編集を知らせる `tixforge:out-of-sync` は、状態とは別に付く。

**issue が閉じる時点**：issue はリリースされたとき（GitHub の default branch に入ったとき）に閉じる。Base が default branch なら、PR のマージで閉じる。develop などの場合は、develop にマージした時点では開いたまま `tixforge:merged` になり、main に入った時点で閉じる。Actions の `tixforge-issue-sync` を入れていれば、リリース PR のマージで（squash の設定に関係なく）閉じて `tixforge:done` になる。入れていなければ、最初の commit の `Closes #N` が main に入ったときに GitHub が閉じる（squash でそれが消えると閉じない。ラベルは `tixforge:merged` のまま）。リリースでは、commit を develop に入れた PR の本文まで読むことがあるので、commit が数百を超えると API の呼び出しの上限に当たることがある。

**PR 本文の `Closes #N`**：PR 本文には `Closes #<番号>` が必須。guard（PR 作成のとき）・`tixforge-pr-link`（サーバー側）・dev の PR フェーズ（作成後）の 3 段で確かめる。本文の決まりは [`references/github/pr.md`](references/github/pr.md)。

**2 つの「done」**：run の `Status: done` は Base にマージされた（開発者の作業が終わった）こと、issue の `tixforge:done` はリリースされた（世に出た）こと。develop 運用では、この 2 つの時点がずれるのが正しい動き。

**Actions**（`project init` で任意に入れる。雛形は `templates/github/`）：

| workflow | 内容 |
|----------|------|
| `tixforge-issue-sync` | PR の作成・マージと issue のクローズに合わせて、状態ラベルを付け替え、issue を閉じる |
| `tixforge-pr-link` | `GT-<番号>-` ブランチの PR 本文に `Closes #<番号>` があるかを検査する（ブランチ保護で必須にできる） |
| `tixforge-issue-guard` | issue が GitHub 上で直接編集されたら `tixforge:out-of-sync` とコメントを付ける |

フォークからの PR には対応しない（Actions のトークンが読み取り専用になるため）。必要なら workflow を各自で改造する（`pull_request_target` にし、PR の作者がメンバーかを確かめる処理を足す。PR のコードは checkout しない）。

## hook

plugin を有効にしていれば、スキルを起動していないセッションや `--resume` で再開したセッションでも効く。tixforge の run が関わる場所でだけ判定し、それ以外は素通しする。

| hook | イベント | 内容 |
|------|----------|------|
| `scripts/guard.sh` | PreToolUse（`Bash\|Edit\|Write\|MultiEdit\|NotebookEdit` と、名前に git を含む MCP） | push・PR 作成・許可リスト外の git / gh 操作に確認画面を出し、force push・hook を飛ばす操作・`Closes` の無い PR をブロックする。Plan の承認前の run があるときのコード編集と、Implement 中の lint などの設定の編集にも確認画面を出す |
| `scripts/session-start.sh` | SessionStart（`compact\|resume`） | 会話の要約・再開の後、進行中の run と、読み直す手順ファイルを Claude に伝える |

`guard.sh` が止めるもの（判定の全体は `scripts/guard.sh` の冒頭）：

- **拒否**：run のブランチと進行中の run の Base での force push と、git の hook を飛ばす commit・push など（`HUSKY=0`・`SKIP=` などの道具ごとの変数は確認画面）。`Closes #<番号>` の無い PR 作成。本当に必要なら、ユーザーが `!` で自分で実行する（例：`! git push --force-with-lease`）。
- **確認画面**：それ以外の push・PR 作成（Status・ブランチ・Base・PR の状況が出る）、許可リストに無い git / gh 操作（merge・rebase・reset・`gh pr merge` など。dev が修正のたびに投稿する `gh pr comment` も）と GitHub / git の MCP の書き込み、Base への commit。
- **確認画面**：Plan の承認前の run があるときの `docs/`・`.tixforge/` 以外の編集（Implement 以降の run のブランチの上では出さない）。Implement 中・`pr:in-progress` の run のブランチでの、lint・formatter・型チェック・git hook の設定ファイルの編集。

- `permissionDecision: "ask"` は、`permissions.allow` に `git push` を入れていても、auto モードでも確認画面を出す。
- 検知はあえて広めにしている（引用符を外して `git` と `push` の組み合わせを拾うなど）。誤検知しても確認画面が出るだけ。commit メッセージに「push -f」と書いただけならブロックしない（確認画面に注記が付く）。
- **事故防止の仕組みであって、完全な防御ではない。** Claude が実行できるコマンドは、どんな検知もすり抜ける書き方ができる。サーバー側で確実に守りたいことは、Actions（`tixforge-pr-link`）とブランチ保護で守る。

## statusline

Claude Code の画面の下に、今いる場所の run と Status を出せる（任意。plugin を入れただけでは出ない）。

```
GT-000001 · plan:awaiting-approval
```

今のブランチの run を出す。どの run のブランチでもなければ、Plan の承認前の run（まだブランチが無い）を出し、複数あれば先頭の 1 つに `(+<残りの数>)` を付ける。run が無い場所では何も出さない。

下の例のパスは marketplace の clone（`~/.claude/plugins/marketplaces/tixforge`）を指す。インストールした版の置き場所（`~/.claude/plugins/cache/tixforge/tixforge/<version>`）は更新のたびに変わるので使わない。clone は `claude plugin marketplace update tixforge` のときに最新の main になり、インストールした版より新しいことがある（statusline.sh は state.md を読むだけなので、ずれても困らない）。

statusline を使っていなければ、`~/.claude/settings.json` に足す：

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/plugins/marketplaces/tixforge/scripts/statusline.sh"
}
```

自分の statusline のスクリプトがあれば、受け取った入力をそのまま渡して、出力を好きな位置に入れる：

```sh
input=$(cat)
tf=$(printf '%s' "$input" | bash ~/.claude/plugins/marketplaces/tixforge/scripts/statusline.sh)
```

## パネル（`/tixforge-panel`）

`/tixforge-panel` で、自分の open の PR（`pr-status.sh` と同じ判定）と、tixforge の状態ラベルが付いた open のチケット（自分の担当 → 未割り当て → 他の人の順、`●` が自分の担当）を右側のパネルに出す。もう一度打つと閉じる。

- チケットを押すと詳細を取り直して出し、`tixforge:todo` で未割り当てか自分の担当なら **開始** で `/tixforge:dev <id>` を送る（作業中なら、手が空いてから始まる）。
- 開いている間は 3 分ごとに取り直す。**更新** ですぐ取り直す。閉じている間は取らない。区画の開閉は次のセッションにも残る。
- Claude Code の mod（plugin の `hooks/panel.tsx`）で出す。mod が使える Claude Code が要る（2.1.327 の `claude plugin test` で確かめた）。mod が使えない環境（`claude -p` など）や、端末が狭いとき（110 列未満）は横に並ばない。
- コマンド名に `:` を使えないので、`/tixforge:panel` ではなく `/tixforge-panel`。

## イベントログ（`.tixforge/events.jsonl`）

run の過程を、ほかのツール（tixforge の GUI など）が読めるように、1 行 1 イベントの JSON で追記する。`run-state.sh` が state.md を書き換えるときに書くので、Claude の書き方に左右されない。手元だけに置き（git に載せない）、run を消しても残る。書けなくても、本来の操作は止めない。

各行に必ずあるキー：`v`（形式の版数。今は `1`）・`at`（秒までの時刻と UTC からのずれ。`2026-11-21T10:15:00+09:00`）・`ticket`（チケット id）・`type`。並びはファイルの順（同じ秒のイベントもこの順に起きた）。

| `type` | いつ | ほかのキー |
|---|---|---|
| `run_started` | `/tixforge:dev` が run を始めた | `status` |
| `status` | `Status` が変わった（同じ値の `set` では書かない） | `from`・`to`・`via` |
| `rewind` | 前のフェーズに戻した | `from`（戻す前の `Status`）・`to`・`reason`（無ければ `null`）・`history`（古い記録のファイル）・`keep_log` |

`via` は変化の種類：`gate`（ゲートで止まった）・`approve`（ゲートの承認で次のフェーズへ）・`forward`（止まらずに次のフェーズへ。ゲートの自動通過か、Review の指摘を直して Review に戻った）・`back`（巻き戻しを使わずに前のフェーズへ。Review の指摘を直しに Implement へ、など）・`pr`（PR のフェーズの中）・`done`・`cancel`・`other`。

```json
{"v":1,"at":"2026-11-21T10:15:00+09:00","ticket":"GT-000123","type":"run_started","status":"research:in-progress"}
{"v":1,"at":"2026-11-21T10:31:12+09:00","ticket":"GT-000123","type":"status","from":"research:in-progress","to":"approach:in-progress","via":"forward"}
{"v":1,"at":"2026-11-21T10:48:40+09:00","ticket":"GT-000123","type":"status","from":"approach:in-progress","to":"approach:awaiting-approval","via":"gate"}
{"v":1,"at":"2026-11-21T11:02:05+09:00","ticket":"GT-000123","type":"rewind","from":"review:in-progress","to":"plan:in-progress","reason":"commit の分け方を変える","history":".tixforge/GT-000123/history/20261121-110205.md","keep_log":false}
```

読む側は、知らない `type` とキーを読み飛ばす（版数を上げずに足すことがある）。キーの意味を変える・消すときは `v` を上げる。

## 困ったとき

- **run の状態ファイルが壊れた**：`.tixforge/<id>/state.md` を消せば、`/tixforge:dev <id>` で最初から始まる（チケットは残る）。
- **確認画面が出すぎる**：スキルの `allowed-tools` の事前承認は、起動したターンにだけ有効。常に許可したいスクリプトは `.claude/settings.json` の `permissions.allow` に足す。
- 起動時の `` !`bash …/project-status.sh` `` などは、`deny` に `Bash(bash:*)` のような広いルールがあるとスキルの起動自体が失敗する。

## tixforge 自体を開発する

準備・構成・ルールは [CLAUDE.md](CLAUDE.md) にある。

## License

[MIT](LICENSE)
