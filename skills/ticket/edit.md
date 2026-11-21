# /tixforge:ticket edit — チケットの編集

## Phase 1 — 準備

目的：チケットを取ってきて、編集できる状態か確かめる。

1. **準備**：`references/github/fetch.md` と `references/github/sync.md` を Read する。引数のチケット id を `bash <scripts>/ticket-id.sh normalize <引数>` で正規化する（無ければ尋ねる。「探す」の開いているチケットを候補として示す）。
2. **チケットを読む**：
   - `fetch.md` の手順で、issue から `.tixforge/<ticket-id>/editing.md` に取ってきて読む。取り込んだ変更は、「フェーズを戻す」の影響判断に含める。
   - ただし `editing.md` が既にあれば（前の edit が書き戻す前に止まった）、`fetch.md` の「編集の続き」を行う。「続きとして使う」なら取ってこずに、「`<ticket-id>`：<タイトル>」を示し（タイトルは `check` の `title:`）、下の確認（止まる場合・`in-review`）を行ってから手順 3 へ進む。
   - **編集しないで止まる場合**：`.tixforge/<ticket-id>/state.md` の `Status` が `done` か `canceled`／チケットの状態が `open`・`in-review` 以外（完了・キャンセル済み・手で閉じられた・`merged`＝Base にマージ済みでリリース待ち）。変えたいことがあるなら、新しいチケットを `/tixforge:ticket create` で作るよう勧める。
   - 状態が `in-review`（PR が出ている）なら、そのことを示し、編集を続けるか尋ねる。

## Phase 2 — 対話

目的：何をどう変えるかを決める。

3. **対話で決める**：今の内容を示し、何を変えたいかを尋ねる。共通規約の「チケットを書く対話」に従う。変えたい内容を文でまとめて渡されたら（複数の項目にまたがる、または全体の書き直し）、`references/bulk-draft.md` を Read し、その手順で今の内容と渡された文から変更後の下書きを作り、決まらない所だけを尋ねる（渡された文に無い項目は今の内容のまま残し、推測や質問は渡された文が触れた項目に限る。ただし、変えた項目と今の内容との食い違い（要件に足したものが対象外にある、など）は尋ねる。合意は手順 4 で得る）。Base を変えるなら `## Base` の節を足す・直す・消す（既定に戻すなら節ごと消す）。
   - 追加がチケットの範囲を大きく広げる（別の機能・別の受け入れ条件の塊になる）なら、このチケットに足さず、別のチケットに分けることを提案する。

## Phase 3 — 差分（ゲート）

目的：変更に合意を得る。

4. 変更後の全文と差分を示して合意を得る。issue のタイトル・本文がどう変わるかも示す。

## Phase 4 — 書き戻し

目的：issue に書き戻す。

5. **書き換える**：`editing.md` を書き換え、すぐに「書き戻す」（`sync.md`）を行う。書き戻せたら、`editing.md` と `.editing.md.hash` を消す。`.tixforge/<ticket-id>/snapshot.md` か v2 の `ticket.md` があれば、続けて `fetch.md` の手順 2 と 4 で `snapshot.md` に取ってくる（`<ファイル>` は `snapshot.md`。`base: changed` なら手順 4 のとおり尋ねる。出た差分は手順 6 の判断に含め、dev では尋ね直さない）。書き換える前に止まるとき（手順 2 で止まる・手順 4 で合意しない）は `editing.md` と `.editing.md.hash` を消す。書き換えた後、書き戻す前に止まるとき（「続き」で手順 4 に合意しなかったときを含む）は、残すか尋ねる（残せば次の edit で続きに使える）。

## Phase 5 — 影響

目的：進行中の run への影響を扱う。

6. **フェーズを戻す**：進行中の run がある場合（`.tixforge/<ticket-id>/state.md` があり、`Status` が `done`・`canceled` 以外）は、`references/ticket-changed.md` を Read し、その手順でフェーズを戻すか決める。
7. 行ったことと issue の URL を伝える。
