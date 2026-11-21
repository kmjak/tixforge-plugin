# /tixforge:project update — 設定とテンプレートの更新

`.tixforge/config.yml` が無ければ、`/tixforge:project init` を案内して止まる。

## Phase 1 — 選択

目的：何を更新するかを決める。

1. **何を更新するか**を AskUserQuestion で尋ねる（単一選択。引数で指定されていればそれに従う）。SKILL.md の「現在の状態」に「移行が要る」があれば、引数に関係なく、尋ねずに「v2 の LT を issue に移す」を行う：
   - **設定の値を変える**
   - **v2 の LT を issue に移す**
   - **テンプレートと Actions を最新にする**
   - **フロントエンドの設計を決める・見直す**
2. 選んだものの手順（Phase 2 の下記）に進む。書いたファイルは commit しない（一覧で示し、commit するかはユーザーに任せる。commit するなら `docs/context/commit.md` の規約に従う）。

## Phase 2 — 変更（ゲート）

目的：選んだものを、差分を示して確認を得てから書く。

### フロントエンドの設計を決める・見直す

- `references/frontend-design.md` を Read し、その手順で決める（`docs/context/frontend.md` があれば、変える軸だけを尋ねる）。合意を得たら `docs/context/frontend.md` に書く。
- 進行中の run があれば、その Approach は前の設計のままなので、合わせるなら `/tixforge:dev rewind <id>` で Approach に戻せることを伝える。

### 設定の値を変える

- 今の `.tixforge/config.yml` を示し、何を変えたいか尋ねる。キーの意味は `references/config.md` を Read して説明する。
- 値の決め方と確かめ方は init の同じ手順に揃える（init の手順ファイル `<plugin>/skills/project/init.md` の該当手順を Read する）：
  - `repository.base_branch` → 「ブランチ運用」。develop に変えるのに develop が無ければ、作るか尋ねる（`git fetch origin <今の base_branch>` の後に `git branch develop origin/<今の base_branch>`）。リモートに develop が無ければ push を勧める（コマンドを示して確認を得てから。push しないと dev の Plan で止まる）。進行中の run（`state.md` の `Base`）は変わらないことを伝える。
  - `commands` → 「検証コマンド」（値は全体を囲むか囲まないか）。
  - `review.required` → 人数に合わせる（1 人なら `false`）。
  - `language`・`gates` → そのまま書き換える。これはチームの値で、「この人が使う値」が `config.local.yml` から来ているなら本人の dev には効かないことと、自分だけ変えるなら `/tixforge:project setup` を使うことを伝える。`language` を変えたら、前の言語で作ったもの（issue フォーム `.github/ISSUE_TEMPLATE/tixforge-ticket.yml`・PR テンプレート・`docs/context/**`、フォームから取り込んだチケットの見出し）は前の言語のまま残ることを伝える（訳し直しはしない）。
- `ticket.tracker` は `github` のままにする。`repository.host` のキーがあれば、使われていないことを伝えて消すか尋ねる。
- `repository.close_issues` のキーがあれば（v3 で廃止）、issue はリリースで閉じるようになったこと（`merge` だった develop 運用では、develop へのマージでは閉じなくなる）を伝える。`.github/workflows/tixforge-issue-sync.yml` の版が `(v6)` より前なら、先に「テンプレートと Actions を最新にする」を勧める（古い版はこのキーで閉じ方を決めるため）。そのうえでキーを消すか尋ねる。
- 変わる内容を差分で示し、確認を得てから `config.yml` に書く。

### v2 の LT を issue に移す

v2 の `LT-` のチケット・`tracker: local`・`repository.host: none` を移す。

3. `git remote -v` で remote があるか確かめる。無ければ、init の「リポジトリ」の「自分で作る」の手順を示し、済んだらこの手順をやり直す。あれば `bash <scripts>/github-preflight.sh` を実行する。終了コード 5（gh が知らないホスト）なら、tixforge は GitHub が必須であることと、tixforge v2 に留まれることを伝えて止まる。それ以外で `ok:` でなければ、出力を示し、済ませてもらってから確かめ直す。GitHub のリポジトリを使わないなら、tixforge v2 に留まるよう伝えて止まる。
4. `tracker: local` か `host: none` だったなら、init の「チケット管理」のラベル・issue フォームと「GitHub Actions」を行う（事前チェックは手順 3 で済んでいる。`tracker` はここでは書かない）。`host: none` だったなら、その前に次を行う：init の「commit」の最後の、リモートに `base_branch` があるかの確認。
5. `bash <scripts>/project-status.sh lt` で移すものを取る（1 行に 1 つ、`<LT-id>`・`<run の Status>`（run が無ければ `-`、`Status` の行が無いか空なら `?`）・`<ticket.md>`（`open`・`canceled`・`none`）・`<Reason>` がタブで並ぶ）。一覧で示し、1 つずつ、出せる選択肢から尋ねる。ticket.md が `canceled` なら「移行の続き」に、そうでなく run が `pr:*` で PR が見つかれば（下の「手で終える」の探し方）「手で終える」に推奨を付ける。run が進行中のものは、issue にすると新しい `GT-` の id で dev を始め直すことになると添える。
   - **issue にする**（ticket.md が `open` のときだけ）— 同じタイトルの issue を探す（`gh issue list --state all --search "<タイトル> in:title" --json number,title`）。あれば示し、「それに移した」「別のチケット」を尋ねる。「別のチケット」か、見つからなければ、`references/github/create.md` を Read し、その「作成」の確認一覧を示して確認を得てから、`bash <scripts>/issue-sync.sh create .tixforge/<LT-id>/ticket.md` を実行する（一時ファイルにせず、そのまま渡す）。移した先の `GT-` の id が決まったら、元の `ticket.md` のタイトル行の下に `Status: canceled` と `Reason: <GT-id> に移した` の 2 行を足す。
   - **やめる**（ticket.md が `open` か `none` のとき）— 理由を 1 行で尋ね、ticket.md が `open` なら、タイトル行の下に `Status: canceled` と `Reason: <理由>` の 2 行を足す。
   - **移行の続き：run を閉じる**（ticket.md が `canceled` のとき）— 理由は尋ねない（Reason に `GT-` の id があれば示す）。
   - **手で終える**（run が `pr:*` のとき）— PR を探す：`## PR` に URL があれば `gh pr view <URL> --json state`、無ければ `gh pr list --head <Branch> --state all --json number,state,url`。PR があれば、`MERGED` なら `done`、`CLOSED` なら `canceled`。`OPEN` なら、この先 tixforge はこの PR を追わないことと、マージかクローズは GitHub で行うことを伝え、「マージする」（`done`）「やめる」（`canceled`）を尋ねる。PR が無く `host: none` だったなら、`Base` へのマージと、その後の `Base` の push は手で行うことを伝え、「マージした（する）」（`done`）「やめる」（`canceled`）を尋ねる。PR が無く `host: none` でなければ、「PR を手で出す」（`done`。`<Branch>` から PR を出すのはユーザーで、この先 tixforge は追わないことを伝える）「やめる」（`canceled`）を尋ねる。
   - run があれば（`-` 以外）、選んだものに応じて `bash <scripts>/run-state.sh set <LT-id> Status <canceled か done>` を実行する（「手で終える」は決まった値、ほかは `canceled`）。run が `?` なら set できないので、`.tixforge/<LT-id>/state.md` を消すか尋ね、確認を得てから消す。消さないなら、`Status` の行を手で直してから update をやり直すよう伝える。
   - 「issue にする」「やめる」「移行の続き」で、`state.md` の `Branch` にブランチがあれば、ブランチは消さずに残すことを伝え、開いている PR（`gh pr list --head <Branch> --state open`）があれば閉じるか尋ねる（閉じるなら `gh pr close <PR>`）。
6. `ticket.tracker` が `local` なら `github` に書き換える。`host: none` だったなら、init の「レビューの要否」（人数を尋ねる）・「PR テンプレート」・「CI」を行う。最後に、`repository.host` のキーがあれば消す。
7. `bash <scripts>/project-status.sh` を実行し、「移行が要る」が出なくなったことを確かめる。残っていれば、残ったものと、それが片付くまで update 以外のスキルは止まることを伝える。終わったら止まる（他の更新は、もう一度 `/tixforge:project update` を起動して行う）。

### テンプレートと Actions を最新にする

plugin 側と比べて、古いものを更新する。

| プロジェクトのファイル | plugin 側 | 比べ方 |
|------------------------|-----------|--------|
| `.github/workflows/tixforge-issue-sync.yml`・`tixforge-pr-link.yml`・`tixforge-issue-guard.yml` | `<plugin>/templates/github/` の同名ファイル | 先頭のコメントのバージョン（`(v2)` など）と内容 |
| `.github/tixforge/ticket-hash.sh`・`messages.yml` | `<scripts>/ticket-hash.sh`・`<plugin>/templates/github/tixforge/messages.yml` | 内容（ハッシュの計算方法がずれると、直接編集の誤検知になる） |
| `.github/ISSUE_TEMPLATE/tixforge-ticket.yml` | `<plugin>/templates/github/ISSUE_TEMPLATE/` | バージョン（訳した見出しはプロジェクト側を保つ） |
| `.github/workflows/tixforge-ci.yml` | `<plugin>/templates/github/tixforge-ci.yml` | バージョンだけ。中身はプロジェクトに合わせて埋めたものなので置き換えない。雛形の変更点（差分）を示し、取り込むか尋ねる |

- 違うものを一覧で示し（ファイルごとに差分）、置き換えるものを選んでもらってから書く。同じものは「最新」と伝える。
- 足りないラベルを作る：init の「チケット管理」と同じく `bash <scripts>/issue-label.sh setup --dry-run` で無いラベルとその説明（何も出なければ全てある）を示して確認を得てから、`bash <scripts>/issue-label.sh setup` を実行する。
- プロジェクトに無いファイルは作らない（入れたいなら init の「GitHub Actions」を案内する）。
