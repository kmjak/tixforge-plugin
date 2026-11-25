# /tixforge:project init — 連携

`init.md` の決まりの中で行う。

## Phase 4 — 連携（ゲート）

目的：GitHub のラベル・issue フォーム・PR テンプレート・Actions・CI を、確認を得てから入れる。

13. **チケット管理**（`ticket.tracker`）：再実行のたびに次を行い、最後に（無ければ）尋ねずに `tracker: github` を書く（`tracker` があれば、ラベルまで済んだ印になる）。public リポジトリなら、チケットの背景や未決事項も公開されることを伝える。
   - **事前チェック**：`bash <scripts>/github-preflight.sh`（同じ実行の中で「リポジトリ」で既に `ok:` だったなら繰り返さない）。`ok:` 以外なら出力を示し、済ませてもらってから確かめ直す。
   - **ラベルを作る**：`bash <scripts>/issue-label.sh setup --dry-run` で、無いラベルとその説明（何も出なければ全てある）を示して確認を得てから、`bash <scripts>/issue-label.sh setup` で作る。
   - **issue フォーム**（任意）：tixforge を使わない人（PM など）も GitHub の画面から issue を作るなら、チケットと同じ見出しの issue フォームを入れるか尋ねる。入れるなら `<plugin>/templates/github/ISSUE_TEMPLATE/tixforge-ticket.yml` を `.github/ISSUE_TEMPLATE/` にコピーする（ドキュメント言語が日本語以外なら、ラベル・見出し・説明をその言語に訳す。見出しはチケットの見出しと同じにする）。フォームで作られた issue は `/tixforge:ticket create #<番号>` で取り込める。
14. **PR テンプレート**：`bash <scripts>/pr-template.sh` で既定のテンプレートを探す（`path: <パス>` か `path: none`）。`directory:` の行があれば、`.github/PULL_REQUEST_TEMPLATE/` の中のテンプレートは GitHub が自動では使わないことを伝える。
    - tixforge 用の項目を入れるか尋ねる（「入れる（推奨）」「入れない」）。項目は `<plugin>/templates/github/pull_request_template.md` の見出し（見出しとコメントはドキュメント言語に訳す）。
    - **入れる・既定のテンプレートが無い** — `.github/pull_request_template.md` として新しく作る。
    - **入れる・ある** — 既存の内容は一切変えず、既存のテンプレートに**無い見出しだけ**を末尾に追記する。追記する差分を示し、確認を得てから書く。
    - **入れない** — 何もしない。
15. **GitHub Actions**：`references/github/actions.md` を Read し、その手順で入れる。
16. **CI**（`commands` が `{}` でないときだけ）：`.github/workflows/` に、検証コマンドを実行している workflow が無ければ、作るか尋ねる（dev の検証と同じ内容を CI でも動かすため、と添える）。
    - 作るなら `<plugin>/templates/github/tixforge-ci.yml` を下敷きにして、ユーザーと一緒に埋める：`__BRANCHES__` は `base_branch`（GitHub の default branch と違えば両方。main + develop なら `main, develop`）、`__COMMANDS__` は `commands` を書いた順に 1 ステップずつ、`__SETUP__`（言語のセットアップ・依存のインストール）はプロジェクトのファイル（`package.json` のロックファイル・`.nvmrc`・`pyproject.toml`・`go.mod` など）から候補を作って確認する。**確認していないセットアップ手順を推測で書かない。**
    - 全文を示し、確認を得てから `.github/workflows/tixforge-ci.yml` に書く。
