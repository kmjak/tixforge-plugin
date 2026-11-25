# /tixforge:dev — Approach

`run.md` の起動・状態ファイル・承認ゲートの決まりの中で行う。

## Phase 2 — Approach

目的：*どう実装するか* を決めて確認する。

1. 実装方針を決める：検討した選択肢、採用案、主な設計判断とトレードオフ。
   - **画面を作る・変えるチケット**は、`docs/context/frontend.md` の、触るパッケージの `## Path:` の節（パスが最も長く一致するもの）で分ける：
     - **節がある** → 作る・変えるファイルと置き場所、使うトークンを採用案に書き、節の規則と照らす（`Legacy:` のディレクトリの既存ファイルは、移すまで対象外。新しいファイルは従う）。外れる必要があれば理由を示し、規則を直すか（直すなら新しい文面を採用案に書き、Plan の commit 一覧に `frontend.md` の更新を入れる）合わせるかを尋ねる。`Tokens: none` なら、初期値でトークンのファイルを作り `Tokens:` をその場所にすることを、初期値を書き写して採用案に入れる（Review の時点では `frontend.md` から初期値が消えているため）。
     - **`frontend.md` はあるがパッケージの節が無い** → 「今決める」（`references/frontend-design.md` を Read して決め、以後「節がある」と同じ）か「近くの既存のコードに合わせる」かを尋ねる。
     - **`frontend.md` が無い** → 止まらずに近くの既存のコードに合わせ、`/tixforge:project update` で設計を決められると 1 行伝える（今決めたいと言われたら「今決める」）。
2. Research で「どう作るかの決定」とした未決事項を「未決事項の解決」の表にする（`| 未決事項 | 決定 | 理由 |`）。無ければ書かない。
3. `## Approach` に書き、ゲート（`approach`）へ。要約では方針を示す。`Mode` が `small`（`bash <scripts>/run-state.sh get <ticket-id> Mode`）なら、採用案と理由を 2〜3 行で書き（手順 2 の表は要るときだけ）、Approach の止まる条件に当たらなければ `gates` に関係なく `run-state.sh pass <ticket-id> approach` で Plan へ進む（当たれば `bash <scripts>/run-state.sh set <ticket-id> Mode normal` にして、Research の要点も添えて通常どおりゲートへ）。
