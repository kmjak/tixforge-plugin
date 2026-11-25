# v2 からの移行

**更新する前に**：GitHub を使わない（v2 で `host: none` だった）なら、v3 に上げずに v2 に留まる（README の「導入」の更新コマンドを実行しない）。v3 は GitHub が必須。

README の「導入」の更新コマンド（`claude plugin marketplace update tixforge` → `claude plugin update tixforge@tixforge`）を実行し、新しいセッションを始めた後に、当てはまるものを上から順に行う。

| すること | 対象 |
|---|---|
| `/tixforge:project update` で、LT のチケットを issue に移す。進行中の LT の run は、新しい GT の id で始め直す。済むまで update 以外のスキルは止まる（Actions の更新などは、もう一度 update を起動して行う） | `tracker: local` か `host: none` だった人で、GitHub を使う人 |
| 進行中の run は続けられる。`/tixforge:dev <id>` で再開すると、state.md を「更新する」「run を消して最初から」「中断する」から選ぶよう聞かれる。「更新する」の後、v2 の `ticket.md` を `snapshot.md` に移してよいかも聞かれる。「run を消して最初から」でも、前のブランチと commit は残る（新しい run は別の名前のブランチを作る。要らなければ自分で消す） | 進行中の GT の run がある人 |
| `/tixforge:project update` の「テンプレートと Actions を最新にする」で、コピーした workflow を上げる（上げないと v2 の閉じ方のまま。issue はリリースではなく develop へのマージで閉じる） | Actions を入れた人 |
| `.tixforge/config.yml` の `repository.close_issues` を消す（Actions を先に上げてから。`/tixforge:project update` の「設定の値を変える」で尋ねる） | `close_issues` を書いていた人 |
| 動きの変化を知る：develop へのマージでは issue は閉じず `tixforge:merged` になり、main に入ったときに閉じて `tixforge:done` になる（README の「GitHub 連携」の「issue が閉じる時点」） | develop 運用で、`close_issues: merge` だった人か、キーを書かずに `tixforge-issue-sync` を使っていた人 |
| 任意：自分だけの言語・ゲートを `/tixforge:project setup` で決める。自分の PR とチケットを `/tixforge-panel` で横に出す | 全員 |

`base_branch` が GitHub の default branch（main など）だった人は、issue が閉じる時点は変わらない。上の表の対象に当たらなければ、更新の後にすることは無い（残った `host`・`close_issues` のキーは読まれないだけで、`/tixforge:project update` の「設定の値を変える」で消せる）。
