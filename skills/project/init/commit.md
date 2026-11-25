# /tixforge:project init — commit

`init.md` の決まりの中で行う。

## Phase 5 — commit（ゲート）

目的：作ったものを示し、確認を得てから commit する。

17. **まとめ**：作ったものを要約する。対話で作った場合・まとめて渡した場合は未決事項を示す。自分で作る場合は、`docs/context/overview.md` を埋めてから `/tixforge:ticket create` に進むよう促す。画面の下に run と Status を出したければ、README の「statusline」の設定を足せることを 1 行で伝える（ユーザーの設定ファイルは書き換えない）。`.tixforge/config.local.yml` が無ければ、自分だけの言語・ゲートを `/tixforge:project setup` で決められることを 1 行で伝える。
18. **commit**：init で作ったもの・変えたもの（`.tixforge/.gitignore`・`.tixforge/config.yml`・`docs/context/**`・`LICENSE`・`CLAUDE.md`・PR テンプレート・`.github/ISSUE_TEMPLATE/tixforge-ticket.yml`・`.github/workflows/tixforge-*.yml`・`.github/tixforge/*`）をまとめて commit する。対象ファイルと commit メッセージ（`docs/context/commit.md` の規約に従う）を提示し、確認を得てから commit する。init が作ったもの以外の変更は含めない。
    - **commit が 1 つも無いリポジトリ**では、必ずこの時点で commit する（後回しにする選択肢を出さない。commit が無いと dev が `base_branch` からブランチを切れない）。context が雛形のままでもよい。
    - **既存のリポジトリ**なら、「ブランチを切って PR にする（ブランチ保護や PR 必須の運用向け）」「`base_branch` に直接 commit する」を尋ねる。PR にするなら、Base がリモートに無ければ（`git ls-remote --heads origin <base_branch>`）先に Base を push し（コマンドを示して確認を得る）、それからブランチを切って commit し、push と PR 作成はコマンドを示して確認を得てから行う。
    - 新しく作ったリポジトリで context を自分で書く場合も、上のとおり今 commit する（書き終えた後の変更は、ユーザーが別に commit する）。
    - **main + develop を選んだ場合**：commit の後に `git branch develop`。
    - 「リポジトリを作る場合」で「push する」を選んだ場合は、commit の後に push する（main + develop なら `git push -u origin main develop`、それ以外は `git push -u origin <base_branch>`。実行前にコマンドを示して確認を得る）。「push しない」を選んだ場合は push しない。
    - それ以外なら、commit（と develop の作成）の後に、`git ls-remote --heads origin` でリモートに `base_branch`（main + develop なら main も）があるか確かめる。無いものがあれば、push するか尋ねる（`git push -u origin <無いブランチ…>` を示して確認を得てから行う。無いままだと、dev の Plan（Base がリモートにあるかの確認）と Implement（`git fetch origin <Base>`）で止まる）。あっても、`base_branch` に直接 commit したなら、`git push origin <base_branch>` を示して push するか尋ねる（push しないと、dev が `origin/<Base>` から切るブランチに init の commit が入らず、設定のファイルが作業ツリーから消える。他のメンバーにも届かない）。push が拒否されたら（リモートが先に進んでいる）force せず、状況を示して止まる。
19. 次の一手として `/tixforge:ticket create` を案内する。
