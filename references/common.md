# tixforge 共通規約

`project`・`ticket`・`dev` に共通する規約。

手順ファイルの表記：

- `<plugin>` — plugin のディレクトリ（実際のパスは上の「置き場所」）
- `<scripts>` — `<plugin>/scripts`。`bash <scripts>/<名前>.sh …` で実行する
- `references/<名前>.md` — `<plugin>/references/<名前>.md`

**会話の言語**：質問・説明・選択肢（AskUserQuestion を含む）は個人の言語（「現在の状態」の「この人が使う値」の `language`）。設定が無ければ（init で決める前を含む）日本語。ユーザーが明らかに別の言語の文章で書いてきたときだけ、その言語に合わせる。スラッシュコマンドや選択肢の回答だけでは判断しない（英語に切り替えない）。

**会話が要約された後**は、続ける前に今の手順ファイルと（dev なら）`.tixforge/<ticket-id>/state.md` を Read し直す。要約には手順の細部が残らないため。

## 共通規約

チケット id を全ての基点にする：チケットと状態のフォルダ名・ブランチ接頭辞。

**チケット id の形式：** チケットは GitHub issue で、id は `GT-<issue 番号>`。番号は 6 桁に 0 埋めする（`GT-000123` は issue #123）。6 桁を超えたらそのまま。issue が正本（`references/github/`）で、番号は create で issue を作って得る。

**v2 からの移行**：「現在の状態」に「移行が要る」があれば、`/tixforge:project update` 以外は、その内容を伝えて止まる。

**チケットの操作**：手順はチケットへの操作を次の名前で呼ぶ。行う前に、表の手順ファイルを（このセッションで未読なら）Read し、その手順で行う。

| 操作 | すること | 手順 |
|------|----------|------|
| 作る | チケットを作って id を決める・GitHub 上で作られたものを取り込む | `references/github/create.md` |
| 取ってくる | 手元のコピーを作り直し、変わったかとチケットの状態を返す | `references/github/fetch.md` |
| 探す | 似たチケット・着手できるチケットの候補を出す | `references/github/fetch.md`「探す」 |
| 書き戻す | 書き換えたチケットを送る | `references/github/sync.md` |
| 状態を変える | 着手・レビュー中・マージ済み・手放す | `references/github/labels.md` |
| 閉じる | 完了・キャンセル | `references/github/close.md` |
| PR と紐づける | commit と PR 本文で紐づけ、確かめる | `references/github/pr.md` |
| 記録を残す | やめた方針と理由を残す | `references/github/record.md` |

**チケットの状態**（「取ってくる」が返す）：`open`（着手前・進行中）・`in-review`（PR が出ている）・`merged`（Base にマージ済みでリリース待ち）・`completed`（完了）・`canceled`（キャンセル済み）・`closed-completed`／`closed-not-planned`／`closed`（tixforge 以外で閉じられた。完了・予定なし・理由なし）。

**id は必ず `<scripts>/ticket-id.sh` で扱う**（手で 0 埋め・変換・解釈しない。0 埋めの数字はシェルの算術で 8 進数になる）。出力はそのまま使う：

| 用途 | コマンド |
|------|----------|
| 引数からチケット id を取り出す | `bash <scripts>/ticket-id.sh detect "<引数>"` → `id: <id>`（無ければ `id: none`、形が不正なら `invalid: <語>`）と `rest: <残り>`、番号が v2 の LT と重なれば `note: …`。明示的な形（`GT-…`・`#123`）は文中でも拾い、裸の数字は引数全体が数字のときだけ拾う |
| 指定された id の正規化 | `bash <scripts>/ticket-id.sh normalize <引数>`（`GT-000123`（大文字小文字は問わない）・`#123`・`123`。どれも issue 番号） |
| チケットが実在するか | `bash <scripts>/ticket-id.sh exists <id>` → `issue`・`pull-request`（その番号は PR）・`none` |
| id → issue 番号 | `bash <scripts>/ticket-id.sh number <GT-id>` |

- **id のエラーを自分で直さない。** `normalize` の終了コード 2（桁数違い・形が不正）や `detect` の `invalid:` に、0 を補う・接頭辞を付けるなどして再実行しない。エラーをそのまま示し、正しい id を尋ねる（打ち間違いで別のチケットを指すのを防ぐ）。`detect` の `invalid: <語>` は、`bash <scripts>/ticket-id.sh normalize <語>` を実行してそのエラーを示す。`LT-` のエラーが移した先の `GT-` の id を示していれば、それで進めるか尋ねる。`normalize` の `注意:` と `detect` の `note:` は、示してその issue でよいか尋ねる。
- dev・edit・cancel は始めるときに「`<id>`：<チケットのタイトル>」を必ず示す（取り違えを防ぐ）。

| 用途 | パス |
|------|------|
| サービス／ドメイン知識 | `docs/context/**`（必要な分だけ読む） |
| tixforge 設定 | `.tixforge/config.yml`（チーム共通）・`.tixforge/config.local.yml`（個人の `language`・`gates`） |
| チケット | `.tixforge/<ticket-id>/snapshot.md` — dev が issue から取った版（「取ってくる」）。edit は `.tixforge/<ticket-id>/editing.md` で書き換え、書き戻したら消す |
| run の状態 | `.tixforge/<ticket-id>/state.md`（`<scripts>/run-state.sh` で作り、ヘッダを更新する） |
| ブランチ名 | `<ticket-id>-<slug>`（slug は英小文字・数字・ハイフン） |

- 上のパスは固定規約。`init` はこの規約どおりの雛形を作るだけで、パスを選ばない。
- プロジェクトの `.gitignore` は触らない（`.tixforge/` の中は `.tixforge/.gitignore` が外す）。
- PR 本文に書く方針（Approach）は、合意した**結論と理由**（2〜3 行）だけ。チケットや検討の過程にレビュアーが引っ張られず、実装そのものを見るため。
- **言語**：チームで共有するものはドキュメント言語、本人だけが読むものは個人の言語。どちらも無ければ日本語。
  - **ドキュメント言語**（`.tixforge/config.yml` の `language`）：チケット・`docs/context/**`・PR の本文とコメント（検証の結果）・issue のコメント（判断の記録・閉じるときのコメント）・GitHub に出る決まった文言。チケットと context は見出しもこの言語。PR のタイトルは commit の件名と同じ決まり（`skills/dev/pr/create.md`）。
  - **個人の言語**（「この人が使う値」の `language`）：会話（質問・説明・ゲートでの要約）・`state.md` の本文・Review の reviewer の報告。`state.md` の見出し・ヘッダ表のキー・`Verification @`・`PR comment @`・`PR head @` は英語の固定キーのまま。
  - `state.md` の内容を GitHub に出すとき（PR 本文の方針・受け入れ条件、判断の記録）は、そのまま貼らずにドキュメント言語で書き直す。
- **設定**（`.tixforge/config.yml`）のキー・値・無いときの扱い・書き方は `references/config.md`。キーを説明するとき、設定を書く・直すとき、キーが無いときに Read する。無いときの既定：`gates` は `[plan, pr]`、`review.required` は `true`、`language` は日本語。「現在の状態」に「init が途中」があれば、`/tixforge:project init` 以外は、init で続けるよう案内して止まる（「移行が要る」もあれば update が先）。
- 既存ファイルを黙って上書きしない（`snapshot.md`・`editing.md` は issue から作り直すので例外。作り直すときは差分を示す）。
- **キャンセル済みのチケット**（チケットの状態か `state.md` の `Status` が `canceled`）は、どのサブコマンドでも操作しない。そう伝えて止まる。

### スクリプト（`<scripts>/`）

結果が 1 つに決まる処理と、一字も変えずに写すべき処理はスクリプトに任せ、手で同じことをしない。出力は要約せずにそのまま使う。

| スクリプト | 用途 |
|------------|------|
| `ticket-id.sh` | id の取り出し・正規化・実在の確認・issue 番号への変換（上記） |
| `run-state.sh` | 状態ファイルの作成（`init`）、ヘッダの読み書き（`get` / `set`。`Status` を検査し、`Updated` も更新）、巻き戻し（`rewind`）・キャンセル（`cancel`）・手放す（`release`）、前の形式からの更新（`migrate`）、Review をどこから進めるか（`review-next`）、ゲートの自動通過（`pass`）。状態を変えるものはどれもイベントログを書くので、手で同じことをしない |
| `branch.sh` | Plan の Base（ユーザー・チケットの `## Base`・設定・origin の既定の順）とブランチ名（空いている名前）の決定 |
| `verify.sh` | 検証コマンドの実行と `Verification @ <hash>: …` の行の出力（`--reuse`：今の commit で全て通った結果があれば、実行せずにその行） |
| `review.sh` | Review のデータ（`review.tsv`）の読み書きと `## Review` の描き直し：ラウンド・報告の取り込み・推奨と自動修正（○×△ の表）・決定・修正済み・一覧 |
| `checks.sh` | 受け入れ条件 → 確かめ方の対応表と手動確認の結果をデータ（`checks.tsv`）として持ち、`## Plan`・`## Implementation Log` に描く。PR の受け入れ条件と検証のコメントの手動確認の部分を組み立てる |
| `review-input.sh` | Review の agent が読む入力（差分・commit 一覧・チケット・Approach・Plan・フロントエンドの設計と、共通の規則をつけた `index.md`）の書き出し |
| `pr-status.sh` | PR の状況（レビュー・CI・コンフリクト）の判定 |
| `pr-resume.sh` | PR フェーズをどこから再開するか（PR の有無・push していない commit・検証のコメント）の判定 |
| `issue-sync.sh` / `issue-label.sh` / `github-preflight.sh` | GitHub issue との同期・ラベルと担当者・事前チェック（`references/github/`） |
| `project-status.sh` | 設定と進行中の run の一覧（起動時に「現在の状態」へ入る） |

## チケットを書く対話

チケットを作る・書き換える・取り込んだ issue を埋める・dev でチケットに書き戻すときの決まり。

- **中身はユーザーが書く。** Claude は項目ごとに質問し、答えを項目の形に整える。ticket の create・edit と project init では、説明の文をまとめて渡す方法も選べる（その手順が `references/bulk-draft.md` を読ませる。言い換えは `（推測）` の印を付けて確かめ、文に無いことは書き足さない）。要件・受け入れ条件などの案を出すのは、「考えて」「案を出して」と頼まれたときだけ。そのときも案として示し、合意したものだけ書く。ただし dev の Research で未決事項を片付けるときは、頼まれなくても調査結果と推奨を示す（`skills/dev/phase/research.md`。決めるのはユーザー）。
- 抜けている観点（エラー・権限・空のとき・境界の値など）は、答えを書かずに「〜のときはどうしますか？」と**質問として**指摘してよい。答えは要件に書き、判定できる受け入れ条件にもする（ユーザーが挙げていない受け入れ条件を足したら、下書きでその項目を示す）。「対象外」「まだ決めない」なら、対象外・未決事項に書く。
- **要件を捏造しない。** 言われていないことは書かない。決まらない点は削らず「未決事項」に残す。
- 必要なら `docs/context/**` やコードを読んで、質問を具体的にする。

## 行動原則

- 情報が不足・曖昧なら**質問する**。存在しないファイルを勝手に作らない（チケットの中身は「チケットを書く対話」）。
- 1 回の Bash の呼び出しでは 1 つのコマンドを実行する。`;`・`&&`・`|`（`| tail` など）でつなげたり、`$(...)` を使ったりすると、確認画面が出る。終了コードは Bash ツールの結果に出るので、`; echo "exit=$?"` を足さない。ファイルの中身は Read で読む。
- 一時ファイル（PR 本文・コメント・issue の下書きなど）は、`mktemp -d` で作ったディレクトリ（リポジトリの外）に新しく書き、コマンドには絶対パスをそのまま書く（変数で渡さない。guard が本文を読めるように）。使い終えたらディレクトリごと消す。
- 仮定を置いて進めるときは**仮定を明示**し、ユーザーが直せるようにする（該当セクションにも記録する）。
- 不要な手順や成果物だと感じたら、黙ってやらず、黙って省きもせず**指摘する**。
- 懸念や反対は**理由付きで率直に**言う。ユーザーの提案というだけで同意しない。

## ガードレール

- dev の 1 run につき 1 チケット。別チケットの範囲に広がりそうなら指摘する。
- 明示的な確認なしに push・PR 作成・マージをしない。tixforge は PR をマージしない。
- **hook（guard）が push・PR 作成・一部の git / gh 操作・Plan 承認前のコード編集に確認画面を出す、またはブロックする。ブロックや確認画面での拒否を、コマンドの言い換えなどで回避・再実行しない。** 理由（拒否なら拒否されたこと）を伝えて指示を待つ。確認画面はチャットでの承認の代わりではない（PR フェーズではチャットで確認を得てから実行する）。
- 外部システムの操作は、チケットの GitHub issue に対する `references/github/` の操作だけ。issue へのコメントもそこに定めたものだけを、定めた形で投稿する（確認を求めるものは確認を得てから）。コメントを編集・削除しない。他の外部システム（Jira など）にチケットを作らない。

## 扱わないもの

- GitHub issue 以外のチケット管理（Jira など）・複数ブランチにまたがる 1 チケット・バックログの管理（分解・優先度）。求められたら扱わないと伝え、1 チケット 1 ブランチの範囲でできることを行う（大きいチケットは分けることを提案する）。
