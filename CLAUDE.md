# tixforge の開発

Claude Code の plugin。利用者向けの説明は README と `docs/`（イベントログの仕様・v2 からの移行）にある。

## 準備と確かめ方

```sh
brew install shellcheck shfmt actionlint zizmor editorconfig-checker jq   # 初回だけ
git config blame.ignoreRevsFile .git-blame-ignore-revs   # 初回だけ。整形だけの commit を blame から外す
claude --plugin-dir .                     # 作業ツリーをそのまま読み込む
make check                                # PR の前に。lint・4 つのテスト・macOS の bash 3.2 でのテスト・claude plugin validate と test（mod）
make fmt                                  # shfmt で整形（設定は .editorconfig）
```

- CI（`.github/workflows/test.yml`）は、lint と 4 つのテストを回し、テストは gawk・mawk・macOS（bash 3.2 と BWK awk）のそれぞれで動かす。ブランチルールで必須にするのは `result` だけ。
- `scripts.test.sh` には jq が要る。`json-get.test.sh` は jq があれば、`json_get` を jq の結果とも突き合わせる。

## 構成

- `skills/<名前>/SKILL.md` が起動時に読まれ、共通規約（`references/common.md`）を `scripts/common-rules.sh` で差し込む。
- 手順は `skills/<名前>/*.md` と `references/github/*.md` に分け、使う場面で読む。

## ルール

ルールを足すときは、機械的に確かめられるものはテストにして「テストで守るもの」に、判断を要するものは理由と一緒に「判断を要するもの」に書く。

### 判断を要するもの

- 結果が 1 つに決まる処理と、一字も変えずに写すべき処理は `scripts/` に置き、`tests/` で確かめる。gh はスタブに置き換える。手順ファイルの文章は、守られるとは限らないため。
- 手順ファイルは使う場面で Read させ、SKILL.md と共通規約は短く保つ。毎回読まれるため。
- スクリプトや Claude が読み取りに使う見出し・キー（state.md の見出しとヘッダ表のキー、`history/`、チケットの `## Base`、`Verification @`・`PR comment @`、`## Review` の `### Round N`・`Auto-fix:`・`Decision:`・`Fixed @`、印 `<!-- tixforge:closed -->` など）は英語で固定し、中身は言語の設定（`language`）で書く。チケットと `docs/context/**` は見出しもドキュメント言語。言語を変えても、スクリプトが同じように読めるため。
- `skills/` の手順ファイルは phase 形式で書く：手順を `## Phase N — 名前` に分け、見出しの次の段落に `目的：` を 1 行で書き、ファイルや GitHub に書く前にゲート（必ず止まって確認を得る）を置く。手順の中で 1 つの操作の確認を取るもの（init のリポジトリ作成など）、答えそのものが確認になる init の config の書き込み、git 管理外の作業ファイル（`.tixforge/.gitignore`・`editing.md`・`snapshot.md`）は、その手順の中で済ませてよい。手順の番号はフェーズをまたいで通しにする（他のファイルが番号で参照するため）。フェーズの代わりに行う分岐（rewind の「手放す」）は番号を振らない。dev は、起動・再開・状態ファイル・ゲートを `run.md` に、各フェーズの手順を `skills/dev/phase/<フェーズ>.md` に 1 ファイルずつ置き、フェーズに入るときにそのファイルだけを Read させる（使う人の文脈に今のフェーズの手順だけを載せ、取り違えと compact を減らすため）。フェーズのファイルの手順の番号はフェーズごとに 1 から振る（`Status` がフェーズを示すため）。project の init も同じく、`init.md` に共通の決まりとフェーズの表を、`skills/project/init/<名前>.md` にフェーズを 1 ファイルずつ置く（手順の番号はファイルをまたいで通し。別のファイルの手順を番号で指すときはファイル名を添える）。PR フェーズも、`pr.md`（再開・PR の存在確認）から、PR を出すまで（`pr/create.md`）と出した後（`pr/follow.md`）のファイルを読ませる。別のファイルの手順を使うときは、ファイル名と「未読なら Read する」を書く。質問やフェーズが多く、途中で中断・compact が起きうるスキル（dev・init）は、さらに途中の状態を残して再開できるようにする（dev は state.md から同じ場所で、init は答えのたびに書く config.yml から再実行で）。中断しても続きが分かり、どこで止まるかが読み取れるため。
- `templates/github/` を変えたら、先頭のコメントの版数（`(v3)` など）を上げる。`/tixforge:project update` は版数で更新の有無を判断する。`templates/github/tixforge/messages.yml` は版数を持たない（update が内容で比べる）。`templates/github/pull_request_template.md` も持たない（init が無い見出しを足すだけで、update は比べない）。
- 共有するものは、種類で置き場所を決める。2 か所に書くと片方だけ直してずれるため：

  | 共有するもの | 置き場所 |
  |---|---|
  | 結果が 1 つに決まる事実・判定、検査にも使う値（Status の一覧など） | `scripts/`（手順ファイルは出力を使う） |
  | プロジェクトにコピーするファイル（workflow・issue フォーム・PR テンプレート・Actions の文言） | `templates/github/` |
  | state.md に書く決まった文言（コピーしない） | `scripts/messages.yml` |
  | Claude が読んで埋める雛形 | `templates/docs/` |
  | 複数のスキルが従う規則・定義・手続き | `references/` |
  | 1 つのスキルの手続き | そのスキルの手順ファイル |

- 手順ファイルが別の手順ファイルを参照するのは、手続きを任せるときだけにし、呼ぶ側と呼ばれる側を書く。一部の手順だけを使うなら、その手順の番号を書く（例：`references/ticket-changed.md` が `rewind.md` の手順 2・3・5・7 を使う）。番号で参照されている手順の番号を変えたら、参照している側も直す（`grep -rn '<ファイル名>' skills references` で探す。テストでは守っていない）。2 つのスキルから呼ばれる手続きは `references/` に置く。他のスキルの手順ファイルを丸ごと読ませると、要らない手順が文脈に混ざるため。
- パネル（`hooks/panel.tsx` の mod）のデータは `scripts/panel-data.sh` で作り、mod は描画とボタンだけにする。mod は CI で確かめられない（`claude plugin test` は claude CLI のある手元の `make check` だけで回る）ため。
- イベントログ（`.tixforge/events.jsonl`）は、state.md を書き換えるスクリプトの中で `lib.sh` の `event` で書き、手順ファイルから Claude に書かせない。キーの意味を変える・消すときは `lib.sh` の `EVENTS_SCHEMA` を上げ、`docs/events.md` を直す（キーや種類を足すだけなら上げない）。GUI などの外のツールが読む約束で、Claude の書き方で揺れると読めないため。書き込みや送信（`events-sync.sh`）の失敗で本来の操作を止めず、終了コードと出力も変えない。送信のトークン（`TIXFORGE_EVENTS_TOKEN`）は環境変数だけから読み、ファイル・出力・コマンドラインに出さない。
- state.md の形を変えたら、`run-state.sh` の `STATE_FORMAT` を上げ、`migrate` に前の形式から移す段を足す。plugin を更新しても、利用者の手元の state.md は書き換わらないため。

### テストで守るもの

| ルール | 守るもの |
|---|---|
| macOS の bash 3.2 と BWK awk、Linux の gawk・mawk のどれでも動かす。連想配列・`mapfile`・`${var,,}`、gawk だけの関数は使わない | `make test-bash32`・CI の gawk・mawk・macOS の行列 |
| guard と wait-hook（hook）は jq に頼らない。`lib.sh` の `json_get` で読む | `tests/guard.test.sh`・`tests/scripts.test.sh` の wait-hook.sh の節（jq の無い PATH で動かす）・`tests/json-get.test.sh` |
| スクリプトの中で、`$var` の直後に全角文字を続けない（`${var}` と書く） | `tests/scripts.test.sh` の「all scripts」 |
| `skills/`・`references/`・`agents/` でファイルの名前を変えたら、参照している側も直す | `tests/plugin.test.sh` |
| issue フォームの見出しは、チケットのテンプレート（`templates/docs/ticket.md`、`## Base` を除く）の見出しと同じ順で揃える | `tests/scripts.test.sh` の「ticket template」 |
| `references/config.md` の見本のキーと表のキーを揃える | `tests/plugin.test.sh` の「config sample」 |
| `hooks/hooks.json` の guard の matcher は、guard が判定するツールだけで起動する | `tests/plugin.test.sh` の「guard matcher」 |
| スキルの手順（そのスキルの手順ファイルと `references/`）が `bash <scripts>/X.sh` で呼ぶスクリプトは、SKILL.md の `allowed-tools` に入れる（引数を渡すなら ` *` か同じ引数で） | `tests/plugin.test.sh` の「allowed tools」 |
| Review の agent は `references/review.md` の節の名前（受け取るもの・進め方・守ること・報告の規則）で共通の規則を指す | `tests/plugin.test.sh` の「review rules」 |
| パネルが出すチケットの状態（`panel-data.sh` の `PANEL_STATES`）は、`label_defs` の open な状態と同じにする | `tests/scripts.test.sh` の panel-data.sh の節 |
| パネルの mod（`hooks/panel.tsx`）に型エラーを残さない | `make validate`（claude CLI があるときだけ） |
| `skills/` の手順ファイル（SKILL.md・dev の `run.md` と Phase 6 の `pr.md`・`pr/`・project の `init.md` を除く）は `## Phase 1 — ` から順に番号を振ったフェーズに分け、各見出しの次の段落に `目的：` を書き、手順の番号を通しにする。dev の `skills/dev/phase/` は 1 ファイル 1 フェーズで、`run.md` の「フェーズの手順」の順に Phase 1〜5、手順はフェーズごとに 1 から（`0.` で始めてよい）。project の `skills/project/init/` は `init.md` の表の順に Phase 1〜5 を 1 ファイルずつ、手順はファイルをまたいで通し | `tests/plugin.test.sh` の「phases」 |
| 巻き戻し・キャンセルの分類（`run-state.sh categories`）は、尋ねる手順（`rewind.md`・`cancel.md`）の一覧と同じにし、きっかけ（`run-state.sh triggers`）は全て `rewind.md` に書く | `tests/scripts.test.sh` の「run-state.sh events」 |
| スクリプトは `make fmt` で整形する。手で整えない | `make lint` の `shfmt -d` |
| PR のタイトルは Conventional Commits の形にする（下の「commit と PR」） | CI の `pr-title` |
| ラベルの一覧と色は `issue-label.sh` の `label_defs` だけに書き、説明は `templates/github/tixforge/messages.yml` の `label_<名前>` に各言語で書く。Actions の雛形が使うラベル名は `label_defs` にあるものだけにする | `tests/scripts.test.sh` の issue-label.sh の節 |
| `scripts/messages.yml` と `templates/github/tixforge/messages.yml` に同じキーを書かない（`msg` はキーを先に見つけた方から引く） | `tests/scripts.test.sh` の「lib.sh cfg」 |
| dev・ticket の手順は、チケットへの操作を共通規約の「チケットの操作」の名前で呼び、状態は `issue-sync.sh check` の `status:` の言葉で扱う。issue の具体（`gh issue`・ラベル名・`closed_as`・`Closes`・issue の目印）は `references/github/` にだけ書く（`issue-sync.sh check` の呼び出しはよい） | `tests/plugin.test.sh` の「tracker operations」・`tests/scripts.test.sh` の issue-sync.sh の節 |
| v2 が残した state.md を `migrate` で移せる（テストの中の v2 の state.md は直さない）。v2 が英語のコメントで閉じた issue を読める。v2 の GT の `ticket.md` と `.issue-hash` を、`pull` が `snapshot.md` に移す。v2 の `LT-`・`tracker: local`・`host: none` は「移行が要る」と示し、`LT-` の id は移行を案内するエラーにする | `tests/scripts.test.sh` の「v2 data」・issue-sync.sh・project-status.sh・ticket-id.sh の節 |

## commit と PR

- 1 ブランチ 1 PR、squash でマージする。`main` に直接 push しない。
- **PR のタイトル**が main の commit になり、release-please が次の version と CHANGELOG を決める。Conventional Commits の形で英語で書く：`<type>[(scope)][!]: <命令形の 1 文>`。
  - `feat`：利用者に届く機能の追加（スキル・サブコマンド・設定項目・hook・スクリプトの機能）→ マイナー
  - `fix`：利用者に届く不具合の修正・手順書の改善 → パッチ
  - `feat!` / `fix!`：`config.yml` のキーや `.tixforge/` の構造が変わり、移行が要る → メジャー
  - `docs`（README・`docs/`・CLAUDE.md だけ）・`test`・`ci`・`build`・`chore`・`refactor`：リリースにならない
  - **`skills/`・`references/`・`agents/`・`templates/` の md や yml の変更は `docs` にしない。** 手順書は tixforge の振る舞いそのものなので `feat` か `fix` にする。`docs` にすると利用者に届かない。
- PR の中の commit は英語。件名は命令形の 1 文、本文に「なぜ」を書く（squash の本文に並ぶ）。
- 整形だけの変更は単独の PR にし、マージ後の commit を `.git-blame-ignore-revs` に足す。
- **リリース**：利用者に届くのは、`.claude-plugin/plugin.json` の `version` を上げたものだけ。version は手で上げない。main に入るたびに release-please（`.github/workflows/release-please.yml`）がリリース PR（`chore(main): release tixforge x.y.z`）を更新し、それをマージすると version・CHANGELOG・`tixforge--v<version>` のタグ・GitHub Release・Discord 通知が揃う。

## `.local/`（git の外）

- 検証で見つけた問題は、頼まれない限りコードを直さず `.local/idea/` に書く。消すときはユーザーの承認を得る。
