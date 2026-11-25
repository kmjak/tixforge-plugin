# /tixforge:project init — プロジェクト初期化

目的：このプロジェクトで tixforge を使える状態にする。最初に 1 回実行する想定だが、**何度実行しても安全**にする（済んでいる項目は飛ばし、足りない設定だけを足す）。**既にある設定の値は変えない**（変えるのは `/tixforge:project update`）。引数は取らない（チケット id が渡されたら無視せず、`/tixforge:ticket create` を案内する）。

各手順は太字の名前で参照する（例：「チケット管理」）。質問は AskUserQuestion で、選択肢に推奨を付けて出す。

## フェーズの手順

フェーズに入るとき（再実行で途中から続けるときを含む）、そのフェーズのファイルを、このセッションでまだ読んでいなければ Read し、その手順で行う。手順の番号はフェーズをまたいで通し。

| フェーズ | 手順 | ファイル |
|------|------|------|
| Phase 1 — 確認 | 1 | `<plugin>/skills/project/init/check.md` |
| Phase 2 — 設定 | 2〜9（開発の人数・リポジトリ・ブランチ運用・ドキュメント言語・検証コマンド・commit 規約・レビューの要否・ゲート） | `<plugin>/skills/project/init/config.md` |
| Phase 3 — 作成（ゲート） | 10〜12（作るもの・context・CLAUDE.md） | `<plugin>/skills/project/init/create.md` |
| Phase 4 — 連携（ゲート） | 13〜16（チケット管理・PR テンプレート・GitHub Actions・CI） | `<plugin>/skills/project/init/link.md` |
| Phase 5 — commit（ゲート） | 17〜19（まとめ・commit） | `<plugin>/skills/project/init/commit.md` |
