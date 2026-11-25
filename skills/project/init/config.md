# /tixforge:project init — 設定

`init.md` の決まりの中で行う。

## Phase 2 — 設定

目的：設定の値を 1 つずつ決め、決まるたびに `.tixforge/config.yml` に書く。

書くときは `references/config.md` を Read し、その形とキーの順に合わせる（後から書くキーも、見本の位置に差し込む。既にあるキーは変えない。入れ子のキーは、既にある親（`repository:` など）の下に足す）。最初に書く前に、`.tixforge/.gitignore`（`*`・`!.gitignore`・`!config.yml` の 3 行）が無ければ作る。答えそのものが確認なので、config を書く前には止まらない（commit は Phase 5）。途中で止まっても、再実行すれば値のあるキーは尋ねないので続きから進む（config に書かない答え（開発の人数・commit 規約）は尋ね直す）。

2. **開発の人数**：「1 人で開発しますか？」と尋ねる（答えを使うキー `repository.base_branch`・`review.required` が全てあれば尋ねない）。答えは「ブランチ運用」「レビューの要否」の推奨に使い回す（同じことを 2 度尋ねない）。
3. **リポジトリ**：tixforge は GitHub のリポジトリを使う（チケットは issue、変更は PR）。
   - **git リポジトリでない**：`git init` するか尋ねる。するなら `git init -b main` で作る（ブランチ名は「ブランチ運用」で決め、違えばそこで合わせる）。しないなら、tixforge は使えないことを伝えて中止する。
   - **remote がある**：`bash <scripts>/github-preflight.sh` を実行する。
     - `ok: <owner>/<repo>` → 次へ進む。
     - 終了コード 3・4（gh が無い・未ログイン）→ `git remote get-url origin` が `github.com` を含めば GitHub の可能性が高い。出力の案内（インストール、`! gh auth login`）を示し、済ませてもらってから確かめ直す。
     - 終了コード 5（gh が知らないホスト。GitLab など）→ tixforge は GitHub が必須であることを伝えて中止する。GitHub を使わないなら tixforge v2 に留まれることも伝える。
   - **remote が無い**：GitHub リポジトリが要るか尋ねる：
     - **AI と対話して作る** — 下記「リポジトリを作る場合」。
     - **自分で作る** — `gh repo create` か GitHub の画面で作って `git remote add origin <URL>` する手順を示し、済ませてもらってから、この手順をもう一度行う。
     - **作らない** — tixforge は GitHub が必須であることを伝えて中止する。

   **リポジトリを作る場合**：先に `bash <scripts>/github-preflight.sh` の終了コードが 3・4 でないことを確かめる（3・4 なら案内して待つ）。次の項目を、「1 つずつ聞く」か「まとめて渡す」（項目と、作るアプリの説明を 1 つの文で書いてもらう。`references/bulk-draft.md` の手順で振り分け、書かれていない項目は下の既定を入れて示す。既定の無い LICENSE は、書かれていなければ尋ねる。「説明」（`--description`）は、リポジトリの説明として書かれたものだけを使い、アプリの説明から作らない（無ければ下の候補）。下の各項目に書いた確かめは、どちらの方法でも全て行う）かを尋ねて決め、全部決まったら、実行するコマンド（`gh repo create <owner>/<name> --<visibility> --source=. --remote=origin [--description "<説明>"]`）と作るもの（LICENSE を含む）を一覧で示して確認を得てから、リポジトリと LICENSE を作る。push は「commit」の後に行う。
   - **オーナー** — 既定は個人アカウント（`gh api user --jq .login`）。所属 organization（`gh api user/orgs --jq '.[].login'`）を選択肢に加える。そのどちらでもない名前なら、そう伝えて選び直してもらう。
   - **リポジトリ名** — 既定はリポジトリのルートディレクトリ名。GitHub で使えない文字（英数字・`-`・`_`・`.` 以外）は `-` に置き換えた案を示す。`gh repo view <owner>/<name>` で同名のものが既にあれば、先に伝えて別の名前を尋ねる。
   - **公開範囲** — 既定は **private**。public・（organization なら）internal から選ぶ。public を選んだら、コードが誰でも見られるようになることを念押しする。
   - **説明** — 省略可。README の 1 行目があれば候補にする。
   - **LICENSE**（public のときだけ。既に LICENSE ファイルがあれば尋ねない）— MIT・Apache-2.0・GPL-3.0・付けない、から選ぶ（その他は自由入力）。「付けない」には、他の人は法的に使えない（全著作権を保持する）ことを添える。著作権者は `git config user.name`、年は今年を既定にして確認する。本文は記憶から書かず、`gh api licenses/<キー>`（例：`mit`）の `body` を使い、年と著作権者の欄を埋める。
   - **push するか** — 既定は「する」。public のときは、先に `.env`・鍵ファイルなどの秘密情報が git で追跡されていないか確かめ、あれば示して止まる。

   config にはオーナー・リポジトリ名・公開範囲は書かない。「まとめて渡す」でアプリの説明をもらったら、手順 11（`init/create.md`）の context の「まとめて渡す」とフロントエンドの設計（説明に色やデザインパターンがあれば使う）で使うので、この会話の中で覚えておく（どこにも書かない）。中断や compact で原文が手元に無ければ、手順 11（`init/create.md`）でもう一度書いてもらう（要約したものを原文として扱わない）。context の「まとめて渡す」でもらった説明も、フロントエンドの設計で同じように使う。
4. **ブランチ運用**（`repository.base_branch`）：`base_branch` は、dev がブランチを切る元であり、PR の向き先。
   - **新しく作るリポジトリ**（`git init` した・「リポジトリを作る場合」・commit がまだ 1 つも無い）：運用を尋ねる。ブランチ名は自由入力で変えられる。
     - **main だけ**（1 人なら推奨）— `base_branch: main`。
     - **main + develop**（develop で開発し、main はリリース用）— `base_branch: develop`。GitHub の default branch は main のままにする。
     - **ブランチ名を合わせる**：commit がまだ無く、今のブランチ名（`git symbolic-ref --short HEAD`）が合わせる名前（main だけなら `base_branch`、main + develop なら main 側の名前）と違えば、「今のブランチは `<今の名前>`、`base_branch` は `<名前>`。`git branch -m <名前>` で名前を変えますか」と尋ねてから行う（`base_branch` を config に書く前に行う）。変えないと、commit は今のブランチに入り、`base_branch` のブランチが存在しないまま残る。
   - **既存のリポジトリ**：GitHub の default branch（`gh repo view --json defaultBranchRef`、取れなければ `git symbolic-ref --short refs/remotes/origin/HEAD`）を既定にする。ローカル（`git show-ref`）とリモート（`git ls-remote --heads origin`）に `develop`・`dev`・`development` があり、default と違えば、どちらを `base_branch` にするか尋ねる。見つからなければ尋ねない。
   - `base_branch` が GitHub の default branch と違う（develop など）なら、issue は develop へのマージでは閉じず、リリース（main に入ったとき）で閉じることを伝え、「GitHub Actions」で `tixforge-issue-sync` を強く勧める。入れないなら、squash の設定を確かめる：`gh api repos/{owner}/{repo} --jq '.squash_merge_commit_title + " " + .squash_merge_commit_message'` が `PR_TITLE BLANK`（squash の commit メッセージが PR タイトルだけ）なら、squash マージで `Closes` が消えてリリースでも issue が閉じないことを伝え、Actions を入れるか設定を変えるか尋ねる。
5. **ドキュメント言語**（`language`）：「日本語（推奨・既定）」「English」を選択肢にして尋ねる（その他は自由入力）。以降のチケットと `docs/context/**` はこの言語で書き、個人の設定（`config.local.yml`）が無ければ、この後の会話（質問・説明）もこの言語で行う。
6. **検証コマンド**（`commands`）：dev の Implement・Review で Claude が実行する、テスト・lint・型チェックなどのコマンド。
   - 先にプロジェクトから候補を読み取る（`package.json` の scripts、`Makefile`、`justfile`、`Taskfile.yml`、`pyproject.toml`、`Cargo.toml`、`go.mod`、CI 設定（`.github/workflows/*`）など）。CI で実行しているコマンドがあれば優先して候補にする。
   - 候補を出典のファイル付きで示し、どれを使うかをユーザーに確定してもらう。**確認なしに推測のコマンドを書かない。**
   - キー名は用途を表す短い名前（`test`・`lint`・`typecheck` など）にする。書いた順に実行する。値は、**全体を `"…"` で囲むか、まったく囲まないかのどちらか**にする（一部だけを囲まない）。` #` を含むなら全体を囲む。
   - 検証コマンドが無い（テストが無い等）場合は `commands: {}` と書き、その旨を伝える（dev は検証を省き、記録に残す）。
   - 新たにラッパー（Makefile 等）は作らない。既存のコマンドをそのまま書く。
7. **commit 規約**（`docs/context/commit.md`）：dev の commit はこのファイルに従う。ここでは中身を決めるだけにし、ファイルは Phase 3 の「作るもの」の確認の後に書く。
   - **既にある場合**：尋ねずに使う。ただし `Source:` にパスがあれば、下の 3 点を確かめ直す（再実行のたびに）。満たさなければ示して、選び直すか本文に書くかを尋ねる。
   - **無い場合**：「既存の規約ファイルがある」「無いので作る」を尋ねる。先に `CONTRIBUTING.md`・`commitlint.config.*`・`.gitmessage`・`.github/` 配下などを見て、候補があれば選択肢の説明に含める。
     - **ある** → パスを確定する。**そのパスが ① 存在する ② リポジトリの中にある ③ git で追跡されている（`git ls-files --error-unmatch <パス>`。未追跡のファイルは他のメンバーの手元に無い）**ことを確かめてから、リポジトリのルートからの相対パスで `Source:` に書く。本文はコピーしない。本文欄には、tixforge 固有の補足（あれば）だけを書く。
     - **無い** → `Source:` は空欄にし、同じファイルの本文に規約を書く。直近の `git log` の書式を読んで下書きを提案し、合意したものだけを書く（履歴が無ければ、件名の形式・言語・本文の書き方の最低限を対話で決める）。
   - どちらの場合も、commit メッセージの言語を `Language:` に書く（既存の規約に書かれていればそれに合わせる）。

   テンプレート（見出しと本文はドキュメント言語、`Source:`・`Language:` は英語の固定キー）：

   ```markdown
   # commit 規約

   Source: <既存の規約ファイルのパス。無ければ空欄>
   Language: <commit メッセージの言語>

   <!-- Source が空欄なら、ここに規約本文を書く。
        Source があれば、ここには tixforge 固有の補足だけを書く（Source と矛盾したら Source を優先する）。 -->
   ```
8. **レビューの要否**（`review.required`）：「開発の人数」の答えから決める（尋ね直さない）。
   - **1 人** — `required: false`。GitHub では自分の PR を Approve できないため、`true` のままだと PR が完了にならない。
   - **複数人** — `required: true`。
   - 人数が変わったら `/tixforge:project update` で変えられることを伝える。
9. **ゲート**（`gates`）：`gates: [plan, pr]` を書く（尋ねない）。書いたゲートでは必ず止まり、書いていないフェーズは、止まる条件（未解決の疑問・方針を決めるのに要る判断・レビュー指摘など）が無ければ自動で通過すること、`pr` は書かなくても必ず止まることを伝える。方針（Approach）でも必ず止めたければ `[approach, plan, pr]`、全フェーズで止めたければ `[research, approach, plan, implement, review, pr]` にできる。
