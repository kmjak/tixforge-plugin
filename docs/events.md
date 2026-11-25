# イベントログ（`.tixforge/events.jsonl`）

run の過程を、ほかのツール（tixforge の GUI など）が読めるように、1 行 1 イベントの JSON で追記する。`run-state.sh` が state.md を書き換えるときに書くので、Claude の書き方に左右されない。手元だけに置き（git に載せない）、run を消しても残る。書けなくても、本来の操作は止めない。

既定の置き場所は `.tixforge/events.jsonl`。git の外なので、`git clean -xdf` やクローンし直しで消える。残したいなら、`/tixforge:project setup` で個人の設定 `events_log` にリポジトリの外のパス（`~/tixforge-logs/myapp.jsonl` など）を書く（`references/config.md` の「個人の設定」）。今の置き場所は `/tixforge:project` の「現在の状態」の `events_log=` に出る。ほかのツールは、`.tixforge/config.local.yml` の `events_log`（`~/` はホーム、相対パスはリポジトリの最上位から）、無ければ `.tixforge/events.jsonl` を読む。

各行に必ずあるキー：`v`（形式の版数。今は `1`）・`id`（イベントごとの UUID。送り直しても 1 件にまとめるため。v3.5 より前に書いた行には無い）・`at`（秒までの時刻と UTC からのずれ。`2026-11-21T10:15:00+09:00`）・`ticket`（チケット id）・`type`。並びはファイルの順（同じ秒のイベントもこの順に起きた）。

| `type` | いつ | ほかのキー |
|---|---|---|
| `run_started` | `/tixforge:dev` が run を始めた | `status` |
| `status` | `Status` が変わった（同じ値の `set` では書かない） | `from`・`to`・`via` |
| `rewind` | 前のフェーズに戻した | `from`（戻す前の `Status`）・`to`・`category`・`trigger`・`reason`・`history`（古い記録のファイル）・`keep_log` |
| `canceled` | `/tixforge:ticket cancel` でやめた | `from`・`category`・`reason` |
| `released` | チケットを手放した（run を消した） | `from`・`reason` |
| `mode` | run の進め方が変わった：`small`（小さいチケット：Research・Approach・Plan を Plan のゲート 1 回で確かめる）か `normal`（巻き戻すと戻る） | `from`・`to` |
| `wait_start`・`wait_end` | 人を待ち始めた・人が答えた（hook が書く）。`turn`：Claude のターンが終わってから次の入力まで。`question`：AskUserQuestion の質問から答えまで | `cause`（`turn`・`question`）・`session` |
| `review_round` | `review:in-progress` から出た（指摘を直しに行く・ゲート・PR・巻き戻し）。Review のラウンドごとに 1 行 | `round`・`findings`・`unparsed` |

`rewind`・`canceled`・`released` は `status` を別に書かない（`Status` の変化はこれらの `from`・`to` で分かる）。`category`・`trigger`・`reason` は無ければ `null`。

- `category`（巻き戻し）：`misread`（要件の読み違い）・`constraint`（既存のコード・制約を知らなかった）・`infeasible`（技術的に無理・方針の誤り）・`spec_change`（仕様の変更）・`other`
- `category`（キャンセル）：`priority`（優先度が下がった）・`duplicate`（重複・統合）・`spec_change`・`infeasible`・`other`
- `trigger`（巻き戻しのきっかけ）：`human`（人が言い出した）・`review`（Review の見直し）・`implement`（Implement で計画どおりに進められない）・`pr`（PR の対応）・`ticket`（チケットの変更）

`review_round` の `findings` は指摘ごとの `{id, label, auto_fix, decision, fixed}`：`id` は `R1`・`Q2`（実装者が足した指摘は `""`）、`label` は `[未実装]` などの種類を書かれたとおり（Review の言語のまま）、`auto_fix` は `fix`（○）・`accept`（×）・`ask`（△）、`decision` は `fix`・`fix (auto)`・`accept`・`accept (auto)`・`replan`・`reapproach` か `null`、`fixed` は `Fixed @` の hash か `null`（3.0 の Review を移した、hash の無い修正済みも `null`）。`unparsed` は、`Auto-fix` がまだ付いていない（`review.sh judge` の前の）指摘の数。Review のデータ（`review.sh`）から書くので、Claude の書き方に左右されない。同じラウンドは Review を出るたびに書き直されるので、最後の行を使う（巻き戻すと Round 1 から数え直す）。

待ち時間は、同じ `session`・`cause` の `wait_start` から次の `wait_end` まで。Status が変わらずに人を待つ場面（Plan の確かめ方・Review の手順 9 の質問など）も入る。この作業ディレクトリの run が 1 つに決まらないとき（run のブランチの上になく、Plan の承認前の run が 2 つ以上ある）は書かない。Esc で止めたターンは Stop が来ないので、始まりの無い `wait_end` がありうる。離席した時間も待ち時間に入る。

`via` は変化の種類：`gate`（ゲートで止まった）・`approve`（ゲートの承認で次のフェーズへ）・`forward`（止まらずに次のフェーズへ。ゲートの自動通過か、Review の指摘を直して Review に戻った）・`back`（巻き戻しを使わずに前のフェーズへ。Review の指摘を直しに Implement へ、など）・`pr`（PR のフェーズの中）・`done`・`cancel`・`other`。

```json
{"v":1,"id":"6f1c2a8e-3b4d-4e5f-9a6b-7c8d9e0f1a2b","at":"2026-11-21T10:15:00+09:00","ticket":"GT-000123","type":"run_started","status":"research:in-progress"}
{"v":1,"id":"9a2e4c6d-8f01-4a23-b456-789abcdef012","at":"2026-11-21T10:31:12+09:00","ticket":"GT-000123","type":"status","from":"research:in-progress","to":"approach:in-progress","via":"forward"}
{"v":1,"at":"2026-11-21T10:48:40+09:00","ticket":"GT-000123","type":"status","from":"approach:in-progress","to":"approach:awaiting-approval","via":"gate"}
{"v":1,"at":"2026-11-21T11:02:05+09:00","ticket":"GT-000123","type":"rewind","from":"review:in-progress","to":"plan:in-progress","category":"misread","trigger":"review","reason":"commit の分け方を変える","history":".tixforge/GT-000123/history/20261121-110205.md","keep_log":false}
```

読む側は、知らない `type` とキーを読み飛ばす（版数を上げずに足すことがある）。キーの意味を変える・消すときは `v` を上げる。

## チームの受け口に送る

`.tixforge/config.yml` に `events.endpoint`（`/tixforge:project update` の「設定の値を変える」）があり、各自が環境変数 `TIXFORGE_EVENTS_TOKEN` にトークンを置いていれば、イベントを書くたびに、まだ送っていない行を裏で送る（`scripts/events-sync.sh`）。手元のログが控えで、送れなくても記録は消えず、次の機会に同じ行から送り直す。送る処理は、run-state.sh や hook を待たせず、終了コードと出力を変えない。トークンはどのファイルにも書かない（curl にも標準入力で渡す）。

- `POST <events.endpoint>`。ヘッダは `Content-Type: application/json` と `Authorization: Bearer <トークン>`。本文は `{"repo": "<owner/repo>", "events": [<ログの行をそのまま>]}`。`repo` は `git remote get-url origin` から求める（求められなければ送らない）。1 回に最大 500 行。
- `2xx` で送り済みにする。それ以外（`4xx`・`5xx`・接続 2 秒・全体 5 秒のタイムアウト）は送り済みにしない。受け口は `id` で重複を除くので、同じ行を送り直してよい。`id` の無い前の版の行には、行の文面（と、同じ文面の行の何番目か）から毎回同じ id を付けて送る（ログは書き換えない）。書きかけの行（まだ改行が無い）は送らない。途中で切れた書き込みに次のイベントがつながった行は、末尾のイベントだけを送る。JSON として読めない行と空行は飛ばす（1 行のせいで後の行が送れなくなるのを防ぐため）。
- 送り済みの行数はログの隣の `<ログ>.sent`、最後の失敗は `<ログ>.sync-error`（時刻と HTTP の状態、または応答なし。応答の本文は残さない）、同時に 2 つ送らないためのロックは `<ログ>.lock`（`events_log` でリポジトリの外に置いても、その隣）。
- `events.endpoint` は `https://` だけ。`http://` は、ホストがちょうど `localhost` か `127.0.0.1`（ポートは付けてよい）のときだけ受け付ける。`@`（ユーザー情報）・空白・`\` を含む URL は受け付けない（`http://localhost:80@別のホスト` はトークンを別のホストに平文で送るため）。
- `bash <plugin>/scripts/events-sync.sh status` で、送るかどうか・送り済みと未送信の行数・最後の失敗を見る。`flush` ですぐ送る。送るかどうかは `/tixforge:project` の「現在の状態」の `events_sync=on|off（理由）` にも出る。
- `reason` などの文章もそのまま送る（チームの中だけで見える受け口に送る前提）。
