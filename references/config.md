# 設定 `.tixforge/config.yml`

`/tixforge:project init` が答えのたびにキーを書き、終わった時点で全てのキーがそろう。値を変えるのは `/tixforge:project update`。git 管理する（チームで共有）。キーは init が尋ねる順に並べる。

```yaml
# tixforge settings (shared, committed)
repository:
  base_branch: main     # dev がブランチを切る元・PR の向き先
  close_issues: merge   # base_branch が GitHub の default branch でないときだけ：merge | release
language: ja            # ja | en | その他の言語名
commands:               # dev の検証で書いた順に実行する。無ければ {}
  test: npm test
  lint: npm run lint
ticket:
  tracker: github       # チケットの置き場：github
review:
  required: true        # PR の Approve を必須にするか
gates: [approach, plan, pr]  # 必ず止まるゲート
```

| キー | 意味 | 値 | 決める手順（init） | 無いとき | 読むもの |
|---|---|---|---|---|---|
| `repository.base_branch` | dev がブランチを切る元で、PR の向き先 | ブランチ名 | 「ブランチ運用」（新しいリポジトリなら「main だけ」か「main + develop」、既存なら GitHub の default branch か、develop などのどちらか） | dev の Plan は `origin/HEAD` を使う。init の再実行を案内する | dev の Plan（Base の既定値）、ticket の create、init の「CI」（`tixforge-ci.yml` に埋める） |
| `repository.close_issues` | `base_branch` が default branch でないとき、issue を閉じる時点 | `merge`（Base へのマージで閉じる）・`release`（default branch へのリリースで閉じる） | 「ブランチ運用」（`base_branch` が default branch と違うときだけ尋ねる。同じなら尋ねずに `merge`） | `merge` | `references/github/close.md`、`tixforge-issue-sync.yml`、init の「GitHub Actions」 |
| `language` | ドキュメント言語（チケット・`docs/context/**`・PR・issue）。個人の設定に `language` が無ければ、会話と `state.md` の言語にもなる | `ja`・`en`・その他の言語名（`ja`・`en` 以外は、スクリプトが書く決まった文言が英語になる） | 「ドキュメント言語」 | 日本語（`ja`） | 共通規約、`msg`（`templates/github/tixforge/messages.yml`。`issue-label.sh setup` など）、`verify.sh`・`run-state.sh rewind`（`user_lang`。個人の設定が優先）、`tixforge-pr-link.yml`・`tixforge-issue-guard.yml` |
| `commands` | dev の検証で実行するコマンド。名前: コマンド | 1 行 1 つ。無ければ `{}` | 「検証コマンド」（`package.json`・`Makefile` などから候補を作って確かめる） | `verify.sh` が終了コード 3 で止まる。init の再実行を案内する | `verify.sh`、init の「CI」（`tixforge-ci.yml` に埋める） |
| `ticket.tracker` | チケットの置き場 | `github` | 「チケット管理」（尋ねずに書く） | init の再実行を案内する | `project-status.sh`（v2 の `local` を見つける） |
| `review.required` | PR の Approve を必須にするか | `true`・`false`（1 人なら `false`。GitHub では自分の PR を Approve できない） | 「レビューの要否」（「開発の人数」の答え） | `true` | dev の PR（`pr-status.sh` の判定と合わせる） |
| `gates` | 必ず止まるゲート。書いていないフェーズは、止まる条件があるときだけ止まる | `research`・`approach`・`plan`・`implement`・`review`・`pr` のリスト。`[]` も可（`pr` は書かなくても必ず止まる） | 「ゲート」（尋ねずに `[approach, plan, pr]`） | `[approach, plan, pr]` | dev の「承認ゲート」 |

- 表に無いキーの値を、推測で補わない。キーが無いときは、表の「無いとき」の扱いに従う。
- `project-status.sh` は `commands` 以外のキーを「現在の状態」に出す（無いキーは空か「未設定」）。`commands` は `config.yml` を読んで確かめる。
- **書き方**：スクリプトはこの形だけを読む。2 段までの入れ子・1 行 1 キー・`#` コメント。値は全体を `"…"` で囲むか、まったく囲まない（` #` を含むなら囲む）。改行は CRLF でもよい。

## 個人の設定 `.tixforge/config.local.yml`

自分だけが使う値。`/tixforge:project setup` が書き、git に載らない（`.tixforge/.gitignore`）。書けるのは次の 2 つだけで、書いたキーは `config.yml` の値より優先する。無ければ `config.yml` の値を使う。形は `config.yml` と同じ。

```yaml
language: en
gates: [plan, pr]
```

| キー | 意味 | 無いとき |
|---|---|---|
| `language` | 個人の言語：会話・`state.md` の本文・reviewer の報告（チケット・PR・issue はドキュメント言語のまま） | `config.yml` の `language` |
| `gates` | この人の dev で必ず止まるゲート | `config.yml` の `gates` |

「現在の状態」の「この人が使う値」に、使う値とそのファイルが出る（`project-status.sh`）。
