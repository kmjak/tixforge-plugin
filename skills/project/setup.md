# /tixforge:project setup — 個人の設定

自分だけが使う設定を `.tixforge/config.local.yml` に書く。チームの設定（`config.yml`）は変えない。`config.local.yml` は `.tixforge/.gitignore` で git に載らない。キーの意味は `references/config.md` の「個人の設定」にある（Read する）。

## Phase 1 — 確認

目的：チームの値と、今この人が使う値を示す。

1. `.tixforge/config.yml` が無ければ、`/tixforge:project init` を案内して止まる。
2. 「現在の状態」の「設定」（チームの値）と「この人が使う値」を示す。

## Phase 2 — 選択

目的：変えるキーと値を決める。

3. 何を変えるかを AskUserQuestion で尋ねる：language・gates・両方・個人の設定を消す（チームの設定に戻す）。選ばなかったキーは今の値のまま残す。
4. 変えるキーを、1 つずつ AskUserQuestion で尋ねる。最初の選択肢は「チームの設定のままにする（<config.yml の値。キーが無ければ references/config.md の既定値>）」。チームの値と同じ選択肢は出さない。
   - **language**（会話・`state.md`・reviewer の報告の言語）：チームの設定のまま・日本語（`ja`）・English（`en`）（その他は自由入力。書く値は `ja`・`en` などの言語コードか言語名）
   - **gates**（必ず止まるゲート）：チームの設定のまま・`[plan, pr]`・`[approach, plan, pr]`・`[]`（`pr` は書かなくても必ず止まる。その他は自由入力。`references/config.md` の `gates` の値にない名前が入ったら尋ね直す）

## Phase 3 — 書く（ゲート）

目的：差分を示し、確認を得てから `config.local.yml` に書く。

5. `git check-ignore -q .tixforge/config.local.yml` が失敗したら（`.tixforge/.gitignore` が無いか書き換えられている）、git に載ってしまうことを伝えて止まる。
6. 変わる内容を差分で示し、確認を得てから `.tixforge/config.local.yml` に書く。「チームの設定のままにする」を選んだキーは、書かない（既にあれば消す）。2 つとも消えたら、ファイルごと消す。形は `config.yml` と同じ（`references/config.md` の「書き方」）。
7. `bash <scripts>/project-status.sh` を実行し、「この人が使う値」が変わったことを示す。commit はしない。language を変えたときは、進行中の run の `state.md` は訳し直さないことを伝える。
