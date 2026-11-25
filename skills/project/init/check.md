# /tixforge:project init — 確認

`init.md` の決まりの中で行う。

## Phase 1 — 確認

目的：今の状態を調べ、決まっている値を読む。

1. **現状の確認**：`docs/context/`・`.tixforge/` の有無と中身、git リポジトリかどうか、commit が 1 つでもあるか（`git rev-parse --verify -q HEAD`）、remote（`git remote -v`）。
   `.tixforge/config.yml` が既にある場合（再実行）は読み込み、**値があるキーは尋ねずにそのまま使う**。キーに書く手順は値が無いときだけ行い、キーの無い手順（作るもの・連携・commit）は毎回、済んでいるかを確かめる。
