# Changelog

## [3.1.0](https://github.com/kmjak/tixforge/compare/tixforge--v3.0.0...tixforge--v3.1.0) (2026-11-21)


### Features

* fix agreed review findings on their own for up to three rounds ([#67](https://github.com/kmjak/tixforge/issues/67)) ([4b54841](https://github.com/kmjak/tixforge/commit/4b548416f07aa74355fb3e15fdeb828f1aa417bf))
* let users hand over a whole description and get a filled draft ([#69](https://github.com/kmjak/tixforge/issues/69)) ([1148068](https://github.com/kmjak/tixforge/commit/114806813178a9ffda03aa9d86d8d0d5b8cd83d5))
* stop at the Plan and PR gates by default ([#66](https://github.com/kmjak/tixforge/issues/66)) ([e23c3c3](https://github.com/kmjak/tixforge/commit/e23c3c31fae11c674664104733e97bc0d5280d38))


### Bug Fixes

* let Research read a few known files without Explore ([#65](https://github.com/kmjak/tixforge/issues/65)) ([c438217](https://github.com/kmjak/tixforge/commit/c438217924e082ed390ad02f7ab390b806b92477))

## [3.0.0](https://github.com/kmjak/tixforge/compare/tixforge--v2.2.0...tixforge--v3.0.0) (2026-11-19)


### ⚠ BREAKING CHANGES

* tixforge now keeps tickets in GitHub issues only. Local tickets (LT-) and repository.host: none are gone: run /tixforge:project update to move LT tickets to issues, or stay on v2 if you do not use GitHub. See "v2 からの移行" in the README: https://github.com/kmjak/tixforge#v2-からの移行
* repository.close_issues is gone; an issue closes when it is released. In a develop flow that used close_issues: merge (or tixforge-issue-sync without the key), a merge into develop now leaves the issue open as tixforge:merged until the release. Update the copied workflow to tixforge-issue-sync (v6) with /tixforge:project update ("テンプレートと Actions を最新にする") before removing the key.

### Features

* add personal settings in .tixforge/config.local.yml ([#49](https://github.com/kmjak/tixforge/issues/49)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* close issues when they are released and drop close_issues ([#57](https://github.com/kmjak/tixforge/issues/57)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* define the labels once and describe them per language ([#43](https://github.com/kmjak/tixforge/issues/43)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* give the Review agents one input folder and shared rules ([#53](https://github.com/kmjak/tixforge/issues/53)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* migrate a run's state.md to the current format ([#33](https://github.com/kmjak/tixforge/issues/33)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* put the verification in every PR and comment it after each fix ([#55](https://github.com/kmjak/tixforge/issues/55)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* replace the ticket working copy with a dev snapshot ([#37](https://github.com/kmjak/tixforge/issues/37)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* require GitHub and drop local tickets ([#34](https://github.com/kmjak/tixforge/issues/34)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* show my PRs and the tickets in a side pane with /tixforge-panel ([#56](https://github.com/kmjak/tixforge/issues/56)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* split every skill's steps into named phases ([#51](https://github.com/kmjak/tixforge/issues/51)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* stop skipped git hooks and confirm check-config edits in a run ([#54](https://github.com/kmjak/tixforge/issues/54)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* suggest /compact at the Plan gate ([#52](https://github.com/kmjak/tixforge/issues/52)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* write the script messages in state.md in the personal language ([#50](https://github.com/kmjak/tixforge/issues/50)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))


### Bug Fixes

* call ticket operations by name in dev and ticket ([#36](https://github.com/kmjak/tixforge/issues/36)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* clear up the instructions the v3 benchmark found ambiguous ([#60](https://github.com/kmjak/tixforge/issues/60)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* describe every config key in references/config.md ([#48](https://github.com/kmjak/tixforge/issues/48)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* describe v3's commands in plugin.json and the statusline path ([#61](https://github.com/kmjak/tixforge/issues/61)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* keep each shared definition in one place ([#41](https://github.com/kmjak/tixforge/issues/41)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* keep the ticket template in templates/docs ([#42](https://github.com/kmjak/tixforge/issues/42)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* mend the v2 migration table and the marketplace description ([#63](https://github.com/kmjak/tixforge/issues/63)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* move messages.yml to the GitHub templates ([#40](https://github.com/kmjak/tixforge/issues/40)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* share the skills' common parts and trim the common rules ([#44](https://github.com/kmjak/tixforge/issues/44)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/dev to what changes what Claude does ([#45](https://github.com/kmjak/tixforge/issues/45)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/project to what changes what Claude does ([#46](https://github.com/kmjak/tixforge/issues/46)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/ticket to what changes what Claude does ([#47](https://github.com/kmjak/tixforge/issues/47)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* write closing comments in the document language behind a mark ([#58](https://github.com/kmjak/tixforge/issues/58)) ([dcb5c2e](https://github.com/kmjak/tixforge/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))

## [2.2.0](https://github.com/kmjak/tixforge/compare/tixforge--v2.1.0...tixforge--v2.2.0) (2026-10-30)


### Features

* show the current run and its Status in the status line ([#27](https://github.com/kmjak/tixforge/issues/27)) ([6513209](https://github.com/kmjak/tixforge/commit/6513209fe47dcd4b7bbd27001f8f7ba3e5fb8fab))


### Bug Fixes

* keep no token after checkout in the workflow templates ([#25](https://github.com/kmjak/tixforge/issues/25)) ([6513209](https://github.com/kmjak/tixforge/commit/6513209fe47dcd4b7bbd27001f8f7ba3e5fb8fab))
