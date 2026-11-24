<!--
tixforge のチケットの雛形（日本語版）。/tixforge:ticket create が Read して使う。
- この先頭のコメントは決まりなので、チケットには書き写さない。
- ドキュメント言語が日本語以外なら、見出しとコメントをその言語に訳して使う。`## Base` の見出しは英語の固定キー。
- 該当しない項目も削らず「なし」と書く（`## Base` は除く）。完成したチケットには記入ガイドのコメントを残さない。
- 見出しを変えるときは、次も合わせる：issue フォーム（templates/github/ISSUE_TEMPLATE/tixforge-ticket.yml。見出しの一致は tests/scripts.test.sh が確かめる）、見出しの名前で読んでいる所（agents/reviewer.md、skills/dev/phase/*.md、references/github/create.md、scripts/issue-sync.sh の adopt など。見出しの名前で grep して探す）。
-->
# <ticket-id>: <タイトル>

<!-- 最初の ## から下が全て issue の本文にそのまま載る。 -->

## 背景
<!-- なぜ必要か。解決したい問題や動機、誰が影響を受けるか。 -->

## 要件
<!-- 何をするか。1 項目 1 行の箇条書きで、実装方法ではなく振る舞いを書く。 -->

## 受け入れ条件
<!-- 何を満たせば完了か。各項目を「- [ ]」で、できた／できていないで判定できる形で書く。確かめ方は書かない（dev の Plan で決める）。 -->

## 対象外
<!-- このチケットでは扱わないこと。 -->

## 未決事項
<!-- まだ決まっていないこと。/tixforge:dev の Research で 1 項目ずつ片付ける。 -->

## Base
<!-- 既定（repository.base_branch）と違うブランチから作るときだけ、この節を入れてブランチ名を 1 行で書く（例：main）。既定なら節ごと書かない。 -->
