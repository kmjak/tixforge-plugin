# /tixforge:project setup — 個人の設定

自分だけが使う設定を `.tixforge/config.local.yml` に書く。チームの設定（`config.yml`）は変えない。`config.local.yml` は `.tixforge/.gitignore` で git に載らない。キーの意味は `references/config.md` の「個人の設定」にある（Read する）。

1. `.tixforge/config.yml` が無ければ、`/tixforge:project init` を案内して止まる。
2. 「現在の状態」の「設定」（チームの値）と「この人が使う値」を示す。
3. 次の 2 つを、1 つずつ AskUserQuestion で尋ねる。どちらも最初の選択肢は「チームの設定のままにする（<config.yml の値>）」。
   - **language**（会話・`state.md`・reviewer の報告の言語）：チームの設定のまま・日本語（`ja`）・English（`en`）（その他は自由入力。書く値は `ja`・`en` などの言語コードか言語名）
   - **gates**（必ず止まるゲート）：チームの設定のまま・`[approach, plan, pr]`・`[plan, pr]`・`[]`（`pr` は書かなくても必ず止まる。その他は自由入力）
4. 変わる内容を差分で示し、確認を得てから `.tixforge/config.local.yml` に書く。「チームの設定のままにする」を選んだキーは、書かない（既にあれば消す）。2 つとも消えたら、ファイルごと消す。形は `config.yml` と同じ（`references/config.md` の「書き方」）。
5. `bash <scripts>/project-status.sh` を実行し、「この人が使う値」が変わったことを示す。commit はしない。
