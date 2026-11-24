# /tixforge:dev — Implement

`run.md` の起動・状態ファイル・承認ゲートの決まりの中で行う。

## Phase 4 — Implement

目的：承認済みの方針と計画に沿って実装する。

1. **ブランチの準備**：git リポジトリであることを確かめ、このチケットと無関係な未コミット変更があれば警告する。ブランチが無ければ `git fetch origin <Base>` の後、`git switch --no-track -c <ブランチ> origin/<Base>` で作る（upstream を Base にしない）。ローカルの Base が `origin/<Base>` より進んでいれば（`git rev-list --count origin/<Base>..<Base>` が 0 でない）、その commit はブランチに入らないと伝え、push するか尋ねる。あれば切り替えるだけ。
2. 承認済みの commit 分割に従って実装・commit する。
   - **テストは対応表に沿う。** `自動` の行のテストを表のテスト名で作る。名前や場所を変えたら `## Implementation Log` に記録する。
   - **commit メッセージは `docs/context/commit.md` に従う**（最初の commit の前に読み、`Language:` の言語で書く）。`Source:` にパスがあればそのファイルを規約とし、本文は補足。**`Source:` のファイルが読めなければ、黙って別の書式にしない。** 止まって伝え、`/tixforge:project update` で直すか、今回は `commit.md` の本文と直近の `git log` の書式で進めるかを尋ねる。`commit.md` が無ければ直近の `git log` に合わせ、`/tixforge:project init` の再実行で作れると伝える。
   - 最初の commit には、`references/github/pr.md` を Read し、その「commit と PR 本文」のとおり紐付けを入れる。
3. commit ごとに `## Implementation Log`（hash とメッセージ、実装中の重要な判断）を更新する。
4. 計画どおりに進められないと分かったら（ある commit を大きく変える、方針が誤っていた等）、止まって提起する。戻るなら `rewind.md` を Read する（きっかけは `implement`）。
5. 計画した commit を終えたら、**検証**・**手動確認**・**context の確認**（下記）を行う。通ったら `## Implementation Log` を更新し、ゲート（`implement`）へ。要約に検証と手動確認の結果を含める。

**Review からの差し戻し**（「修正」と決まった指摘がある）：直すのは、全ラウンドの `Decision: fix`・`Decision: fix (auto)` で `Fixed @` の無い指摘だけ（3.0 までの形式は `<plugin>/skills/dev/phase/review.md` の手順 2 の下の扱い。未読なら Read する）。それ以外に手を広げない。指摘は `Round N <番号>`（例：`Round 1 Q2`）で指す。
- 1 つ直したら、その指摘の下に `Fixed @ <短い commit hash>` を足す。commit の要らない修正は `Fixed @ <HEAD の短い hash> (no commit)`。修正の commit は `## Implementation Log` にも「Review の修正：Round 1 Q2」（個人の言語）と記録する。
- 中断から戻ったら、最新ラウンドの `Verification @` の後の commit を `git log` で確かめ、直したのに `Fixed @` の無い指摘に補ってから続ける。
- `○` の指摘を直せないと分かったら（合意の外に出る・1 つに決まらない・誤検知）、直さずに `Auto-fix:` を `△` にして `Decision:` の行を消し、理由を 1 行足す。
- 修正後に検証と、影響する手動確認のうち Claude が行うものをやり直す。影響する `ユーザー` の手動確認は、自動修正なら止まらずに `## Implementation Log` に `Manual re-check: #N` と書き、Review の手順 9 でまとめて行う（後に `#N` の手動確認の行を書けば済み。今の対応表で `#N` が `ユーザー` でなければ不要）。ユーザーが選んだ修正なら、ここで行う。
- Implement のゲートを挟まずに `Status: review:in-progress` にして Review の手順 2 へ。

### 検証

`bash <scripts>/verify.sh` を実行する。途中で個別のテストを実行するのは自由だが、ゲートの前には必ずこれを実行する。

- **出力の 1 行目（`Verification @ <hash>: <キー> pass | fail …`）を、そのまま `## Implementation Log` に書き写す。** 要約・言い換え・翻訳をしない。
- hash の後の `+dirty` は未コミットの変更を検証したということ。commit してから実行し直す。検証コマンドがファイルを書き換えたときも `+dirty` が付き、変わったファイルが続けて出る。確かめて commit し、実行し直す。
- **終了コード 1**：失敗したコマンドのログを Read し、チケットの範囲内で直して commit し（Log に記録）、再実行する。全て通るまでゲートに進まない。
- 次の場合は直さずに止まり、判断を求める：
  - `Base` でも同じく失敗する（既存の失敗）。確かめるには `git switch --detach origin/<Base>` で `verify.sh` を実行し、元のブランチに戻る。
  - 直すのにチケットの範囲外の変更や、方針・計画の変更が要る
  - 環境の問題（依存が無い、サービスが起動していない等）で実行できない
- **テストを通すために、テストの削除・スキップ・期待値の書き換え・lint の無効化をしない。** 本当に正しいなら、理由を示して承認を得る。
- `commands: {}` なら、終了コード 0 で pass・fail の無い 1 行が出る。そのまま記録して進む。終了コード 3（`commands` が無い）なら、`/tixforge:project init` で足せると伝えて止まる。

### 手動確認

対応表の `Claude（ブラウザ）`・`Claude（API）`・`ユーザー` の行を、検証が通った後に確かめる。誰が確かめるかは Plan で決まっている（尋ね直さない）。

- `Claude（…）`：その手段で確かめる。このセッションで使えなくなっていたときだけ、「自分で確認する」「今回は確認しない（理由を記録）」を尋ねる。
- `ユーザー`：手順（起動方法・操作・期待する結果）を示して確かめてもらう。残っている間は Implement のゲートで止まる。
- `## Implementation Log` に記録する（個人の言語）。1 行目に `手動確認 @ <短い commit hash>: #2 ok（Claude（ブラウザ））`・`#3 ok（ユーザー）`・`#4 未確認（理由：…）`のように書き、確かめた行ごとに、その下へ操作の手順（開いた URL・押したもの・入れた値）と見えた結果を短く書く（PR の検証のコメントにそのまま写すため）。ユーザーが確かめた行は、示した手順と、ユーザーが答えた結果を書く。
- 問題が見つかったら、検証の失敗と同じく直してから、検証からやり直す。

### context の確認

この変更が `docs/context/**` と**矛盾する**か（ディレクトリ構成・アーキテクチャ・用語・技術スタックを変えた、`frontend.md` の置き場所の規則から外れた、トークンのファイルを作ったのに `Tokens: none` のまま等）を 1 回だけ軽く確かめる。矛盾があれば、直す箇所を示し、最小限の修正 commit を足すか尋ねる（足すなら検証をやり直し、`## Plan` の commit 一覧の末尾に「context の更新（Implement で合意）：`docs/context/<ファイル>` の <直した点>」と 1 行足す。Review と PR の対象になる）。無ければ「context の更新は不要」と一行伝える。網羅的に書き足す提案はしない。
