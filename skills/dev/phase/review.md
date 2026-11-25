# /tixforge:dev — Review

`run.md` の起動・状態ファイル・承認ゲートの決まりの中で行う。

## Phase 5 — Review

目的：作ったものを、合意とのズレと品質の両面から調べる。**検出は 2 つの reviewer agent**、このセッションは各指摘に推奨と自動修正を添える。合意の中で直せるものは聞かずに直して回し（Round 3 まで）、判断が要るものだけを最後にまとめて尋ねる。

1. **agent の確認**：`tixforge:reviewer` と `tixforge:quality-reviewer` が使えるか確かめる。無ければ止まり、tixforge plugin が有効か（`/plugin`）を確かめるよう案内する。**別の agent で代用しない**。
2. **どこから進めるか**：Review に入るたび（最初・差し戻しから・再開）、`bash <scripts>/run-state.sh review-next <ticket-id>` を実行し、`step:` に従う。自分で `## Review` を読んで判定し直さない。
   - `3` → 手順 3。`drop: Round N` があれば、先に `bash <scripts>/review.sh drop <ticket-id> <N>` でそのラウンド（書きかけ）を消す。
   - `6`・`7`・`9`・`10` → その手順。`recheck: #N …` は手順 9 でやり直す手動確認の候補（今の `## Plan` の対応表で `#N` が `ユーザー` でなければ要らない）。
   - `implement` → `Status: implement:in-progress` にして `implement.md` の「Review からの差し戻し」へ（「未実行の修正」は `fix`・`fix (auto)` と決まり、`Fixed @` の無い指摘）。
   - `rewind` → 手順 9 の見直しの分岐（`rewind.md`）。

   **`## Review` はデータ（`.tixforge/<ticket-id>/review.tsv`）から `review.sh` が書く。手で Edit しない。** 指摘の一覧は `bash <scripts>/review.sh list <ticket-id> [ask|auto|all]`（1 行 1 指摘。最後の列が本文のファイル）で見る。
3. **検証**：`bash <scripts>/verify.sh --reuse` を実行する（今の commit で全て通った結果があれば、実行せずにその行を出す）。1 行目が Log の最新の `Verification @` と違えば Log に書き写す。失敗か `+dirty` があれば `Status: implement:in-progress` に戻し、`implement.md` の「検証」で扱う。通ったら `bash <scripts>/review.sh round <ticket-id> "<その 1 行目>"` でラウンドを始める（ラウンドの番号が出る）。
4. **レビューの入力を書き出す**：`bash <scripts>/review-input.sh <ticket-id> <Base>`。2 ラウンド目以降は `--since <前のラウンドの Verification の hash>` を付ける（前のラウンドからの `delta.patch` も出る）。`.git/tixforge/review/<ticket-id>/` に差分・チケット・`## Approach`・`## Plan`・`frontend.md`（あれば）と `index.md` が書き出され、`index.md` のパスが出力される。このセッションで読む必要はない。終了コード 3（`snapshot.md` が無い）なら、チケットを「取ってくる」からやり直す。4（state.md が無い、または `## Approach`・`## Plan` が空）なら、原因を伝えて止まる（書き直すなら `rewind.md` で戻る）。
5. **2 つの reviewer を並列に起動する**（1 つのメッセージで 2 つの Agent 呼び出し。ラウンドごとに新しく起動）。渡すのは次だけ：
   - 両方に（指摘は `review.sh list` で選び、本文のファイルから写す）：`index.md` のあるディレクトリのパス、報告の言語（個人の言語）、その agent の `accept`（自動を含む）と決まった指摘と理由、その agent の決定の無い `△` の指摘（同じ指摘を繰り返させないため）、前のラウンドの後に直した指摘（`Fixed @` の commit が前のラウンドの `Verification @` より後）：その agent の指摘は全文、他方と実装者の追加の指摘は「何をどう直すか」の 1 行（自分の指摘が直ったかを確かめさせ、他の修正を「合意外の変更」と言わせないため。合意の引用は他方に渡さない）。指摘は `Round N <番号>` で示す
   - `tixforge:reviewer` にだけ：`## Implementation Log` の手動確認の行（全て。無ければ「無し」）。済んでいない `Manual re-check:` は「#N：Review の後にやり直す予定」と添える

   **`## Research`・`## Implementation Log` の判断・経緯・検証の行は渡さない**（実装者の意図に引きずられず、合意と成果物だけで判定させるため）。`.tixforge/` 配下のパスは渡さない。
6. **結果を記録する**：各 reviewer の報告を、そのまま一時ファイルに書き、`bash <scripts>/review.sh add <ticket-id> <N> reviewer|quality <ファイル>` で取り込む（指摘なしもそのまま）。終了コード 3（報告が形式に合わない）なら、出力に並ぶ問題を示してその reviewer を起動し直し、形式どおりに報告させる。直すのが `Kind:`・`Severity:`・`Confidence:`・`Refers:` の行の欠けや綴りだけなら、その行だけを足し・直して取り込んでよい（本文は変えない）。
   - **指摘を削除・統合・言い換え・並べ替えしない。** 誤検知と思っても消さず、推奨でそう述べる。
   - 指摘ごとに、**推奨**（`fix`・`accept`・`replan`・`reapproach`）を決め、個人の言語で書いたメモを一時ファイルにして `bash <scripts>/review.sh judge <ticket-id> <N> <id> <推奨> <yes|no> <メモ>` を実行する。出力が自動修正（`○` は聞かずに直す、`×` は聞かずに直さない、`△` は最後に尋ねる。`△` はチャットでは「検討」）。`○`・`×` には `Decision` も付く。
     - `yes|no`：直し方が合意（チケット・`## Approach`・`## Plan`）の中で 1 つに決まり、受け入れ条件・Approach・対応表を変えないなら `yes`。ここだけが Claude の判断で、ほかの条件（`Kind`・`Severity`・`Confidence`・Round）はスクリプトが当てはめる。
     - メモ（`- ` の箇条で）：**推奨**と**根拠**（`## Implementation Log` の判断や経緯を使ってよい。reviewer が知らない情報を補う）。推奨が `accept` 以外なら**直し方**（どのファイルの何をどう変えるか。見直しなら戻った先で何を変えるか）。**受け入れた場合**に何が残るか（どんな入力・状態で何が起きるか。何も起きないならそう書く）を 1 行。
   - このセッションが別の問題に気づいたら、報告と同じ形（`Kind`・`Severity`・`Confidence` の行付き）で一時ファイルに書き、`bash <scripts>/review.sh own <ticket-id> <N> <ファイル>` で足す（`I<番号>` になる）。その後 `judge` する。
7. チャットにはラウンドを 1 行で伝える（例：「Round 1：合意とのズレ 3 件・品質 2 件。自動で直す 2・直さない 2・検討 1」）。
8. 手順 2 に戻る（`○` があれば Implement で直し、次のラウンドで確かめる。`○` を全て見送って commit が無ければ、新しいラウンドを起こさずに進む）。`△` は決めずに残す。`○` が無くなれば周回を終え、`△` か手動確認のやり直しがあれば手順 9、無ければ手順 10。
9. **ユーザーに尋ねる**（`Status` は `review:in-progress` のまま）：手動確認のやり直しがあれば先に済ませる（`<plugin>/skills/dev/phase/implement.md` の「手動確認」のとおり。未読なら Read する。問題が見つかれば、`review.sh own` で最新ラウンドに足して `judge` する）。次に、**決定の無い `△` の一覧（`review.sh list <ticket-id> ask`）をチャットに示してから**（下の「最後の一覧の示し方」）、項目ごとに対処を選んでもらう（勝手に決めない）。示した後なら、「推奨どおり」でまとめて決めるか個別に決めるかを尋ねてよい：
   - **修正** — 合意と違う／未実装／合意外の変更を除く／品質の問題を直す。Implement に戻る。
   - **計画の見直し** — 対応表の確かめ方や commit 分割が誤っていた。Plan に戻る。
   - **方針の見直し** — Approach 自体が誤っていた。Approach に戻る。
   - **受け入れ** — 実装が妥当、誤検知、または今回は直さない。理由を記録する。

   決めるたびに `bash <scripts>/review.sh decide <ticket-id> <N> <id> fix|accept|replan|reapproach [<受け入れの理由>]` で書く（中断しても続きから尋ねられる）。全て決まったら：
   - 見直しがある → `rewind.md` を Read し、Approach（両方あれば Approach）か Plan に戻る（きっかけは `review`）。以降のゲートも通り直す。
   - 未実行の修正がある（見直しは無い。今回決めたものに限らない）→ `Status: implement:in-progress` にして Implement へ。直したら Review の次のラウンドへ進み、手順 6〜8 のとおり回す（Round 3 以降の「修正」は `△` なので、聞かずに直すことはない）。
   - どちらも無い → 手順 10。
10. 全ての指摘が決まり、未実行の修正が無い → 全ラウンドの自動で決めた指摘（`○`・`×`。`review.sh list <ticket-id> auto`）を、「最後の一覧の示し方」の 1 行の形で全件示す（聞かずに決めたものを隠さない）。続けてゲート（`review`）へ。`gates` に無ければ `bash <scripts>/run-state.sh pass <ticket-id> review` で自動で通過し、`pr.md` へ。あれば `Status: review:awaiting-approval` にして要約を出し、止まる。

`review.sh` が描く `## Review` の形（見出しは個人の言語。reviewer の報告をそのまま、その下にメモ・`Auto-fix:`・`Decision:`・`Fixed @`。日本語の例）：

```markdown
### Round 1
Verification @ a1b2c3d: test pass, lint pass

#### 合意とのズレ（tixforge:reviewer）
- **R1 [未実装]** …（reviewer の報告をそのまま）
  - Kind: missing
  - Severity: high
  - Confidence: high
  - 推奨：修正 — <根拠>。直し方：…
  - 受け入れた場合：…
  - Auto-fix: ○
  - Decision: fix (auto)
  - Fixed @ b2c3d4e

#### 品質（tixforge:quality-reviewer）
指摘なし
```

### 最後の一覧の示し方

手順 9 で尋ねる前に、決定の無い `△`（`review.sh list <ticket-id> ask`。重大度・確度の高い順）を全ラウンドからチャットに示す（個人の言語。`## Review` を開かずに判断できるように）。示す前に、各指摘が今の HEAD でも当てはまるかを確かめ、解消していればそう添えて推奨を「受け入れ」にする。

- 最初に周回の結果を 1 行（例：「Round 3 で終了。自動で直した 4 件・直さなかった 3 件・検討 2 件」）。
- 重大度・確度は、指摘の `Severity`・`Confidence` を個人の言語の言葉にして示す（例：`high` → 高）。
- `△` は R・Q・I をまとめて、`list` の順に全て**詳しく**示し（本文とメモのファイルを Read する）、推奨（修正・計画の見直し・方針の見直し・受け入れ）と根拠を付ける。
- `○`・`×` は **1 行**ずつ続けて示す。省かない。
- Round 3 まで回り、`△` に推奨「修正」があれば、一覧の直後に 1 段落で、Approach か Plan の見直しを勧めることと、指摘の傾向（同じファイル・同じ種類が繰り返しているか）を添える（`## Review` には書かない。決めるのはユーザー）。見直すなら、どれかの指摘を「方針の見直し」か「計画の見直し」にする。

日本語の例：

```markdown
**R1 [未実装] 受け入れ条件「…」に対応する処理が無い**
- 何が起きるか：<Q は `起きること`。R は `合意側` の記述と、実装がどうズレているか>
- 場所：<Q は `場所`、R は `実装側`>
- 重大度：高 / 確度：高 / 自動修正：検討
- 推奨：修正 — <根拠>
- 直し方：<手順 6 の直し方>
- 受け入れた場合：<手順 6 の受け入れた場合>

**Q1 [バグ] …**
…

自動で直したもの・直さなかったもの（1 行）：
- Round 1 Q3 [エラー処理] … — 重大度：中 / 確度：高 — 自動修正：○（直した）
- Round 1 R5 [合意外の変更] … — 重大度：低 / 確度：高 — 自動修正：×（<受け入れの理由の要約>）
```
