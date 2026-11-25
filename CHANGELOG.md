# Changelog

## [3.6.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.5.0...tixforge--v3.6.0) (2026-11-25)


### Features

* decide where Review goes on from with run-state.sh review-next ([#90](https://github.com/kmjak/tixforge-plugin/issues/90)) ([a0fcd35](https://github.com/kmjak/tixforge-plugin/commit/a0fcd35ed76ec5030aa6a5544280868928813a86))
* decide where the PR phase resumes with pr-resume.sh ([#91](https://github.com/kmjak/tixforge-plugin/issues/91)) ([2c30bde](https://github.com/kmjak/tixforge-plugin/commit/2c30bde9fce5ffdc57d3097fd36ca670d352fb0c))
* pass a gate automatically with run-state.sh pass ([#94](https://github.com/kmjak/tixforge-plugin/issues/94)) ([c220827](https://github.com/kmjak/tixforge-plugin/commit/c2208272116c2b9d161765d187aafcd85bada840))
* pick the Base and the branch name with branch.sh ([#92](https://github.com/kmjak/tixforge-plugin/issues/92)) ([000e2a6](https://github.com/kmjak/tixforge-plugin/commit/000e2a6fcf38d58ddabe3f96112e5d864030fbba))
* reuse a fresh verification with verify.sh --reuse ([#93](https://github.com/kmjak/tixforge-plugin/issues/93)) ([9b5bca5](https://github.com/kmjak/tixforge-plugin/commit/9b5bca5c48fbc1f69c6aeed5e8ce7fd942a3e649))


### Bug Fixes

* allow ticket-id.sh in project and test each skill's allowed-tools ([#95](https://github.com/kmjak/tixforge-plugin/issues/95)) ([2d914fb](https://github.com/kmjak/tixforge-plugin/commit/2d914fb5539447460146640d90213fe5225cde35))
* move the event log spec and the v2 migration out of the README ([#98](https://github.com/kmjak/tixforge-plugin/issues/98)) ([996c30f](https://github.com/kmjak/tixforge-plugin/commit/996c30f1cd5d94a81b645400f9591dcee3c15f6e))
* post how each check was done and what it showed as a PR comment ([#83](https://github.com/kmjak/tixforge-plugin/issues/83)) ([bf81e8a](https://github.com/kmjak/tixforge-plugin/commit/bf81e8abfff437e74382a1e5bc56c0fd44944827))
* read only the current phase's steps in /tixforge:dev ([#87](https://github.com/kmjak/tixforge-plugin/issues/87)) ([901bd1e](https://github.com/kmjak/tixforge-plugin/commit/901bd1ee525ade70db46cdb08ba6e5a17af4e4a0))
* read only the current phase's steps in /tixforge:project init ([#97](https://github.com/kmjak/tixforge-plugin/issues/97)) ([873f6dd](https://github.com/kmjak/tixforge-plugin/commit/873f6ddb0532aee6627b7633fdc6272c3ec91320))
* read only the PR steps of the current step in /tixforge:dev ([#88](https://github.com/kmjak/tixforge-plugin/issues/88)) ([fe7dc3f](https://github.com/kmjak/tixforge-plugin/commit/fe7dc3f980d682025691492887db5100ca27ebb3))
* small slips seen in a live /tixforge:dev run ([#96](https://github.com/kmjak/tixforge-plugin/issues/96)) ([b39cc19](https://github.com/kmjak/tixforge-plugin/commit/b39cc196edbc610610266290c0a81e549b3f925c))
* trim the PR steps and finish a PR creation cut short ([#89](https://github.com/kmjak/tixforge-plugin/issues/89)) ([a0aa85f](https://github.com/kmjak/tixforge-plugin/commit/a0aa85fed0958008404298157af80bb8dbe3c4be))
* trim the wording of dev's run.md without changing its steps ([#84](https://github.com/kmjak/tixforge-plugin/issues/84)) ([f7d2bc9](https://github.com/kmjak/tixforge-plugin/commit/f7d2bc933d9fabbc3fe2211684558c41a46f38a1))
* trim the wording of the common rules without changing them ([#86](https://github.com/kmjak/tixforge-plugin/issues/86)) ([b41b951](https://github.com/kmjak/tixforge-plugin/commit/b41b951f837db6915473412b645ce674bef33fa6))

## [3.5.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.4.0...tixforge--v3.5.0) (2026-11-23)


### Features

* send the event log to the team's endpoint ([#81](https://github.com/kmjak/tixforge-plugin/issues/81)) ([857c990](https://github.com/kmjak/tixforge-plugin/commit/857c9900f7b05698680cd49114ac995911056bd6))

## [3.4.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.3.0...tixforge--v3.4.0) (2026-11-21)


### Features

* let each person choose where the event log is kept ([#79](https://github.com/kmjak/tixforge-plugin/issues/79)) ([3c24aac](https://github.com/kmjak/tixforge-plugin/commit/3c24aacd7b37b85300d7c1858710b99b273ffcf0))

## [3.3.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.2.0...tixforge--v3.3.0) (2026-11-21)


### Features

* log each Review round when a run leaves Review ([#76](https://github.com/kmjak/tixforge-plugin/issues/76)) ([f85bab1](https://github.com/kmjak/tixforge-plugin/commit/f85bab1524d4464a0baa9edaa031e326d4435ba8))
* log run events to .tixforge/events.jsonl ([#74](https://github.com/kmjak/tixforge-plugin/issues/74)) ([a8a2826](https://github.com/kmjak/tixforge-plugin/commit/a8a28265fb8982eb7238579c0e5e2e6a2511d952))
* log when the person is waited on ([#77](https://github.com/kmjak/tixforge-plugin/issues/77)) ([565992e](https://github.com/kmjak/tixforge-plugin/commit/565992e7099358a784be1816aab1d76168c9796a))
* record why runs are rewound, canceled or released ([#75](https://github.com/kmjak/tixforge-plugin/issues/75)) ([7e559a7](https://github.com/kmjak/tixforge-plugin/commit/7e559a7a3732ecdd438acdbcb84976ab8dbe2805))

## [3.2.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.1.0...tixforge--v3.2.0) (2026-11-21)


### Features

* decide the frontend design and hold the implementation to it ([#71](https://github.com/kmjak/tixforge-plugin/issues/71)) ([d684fa4](https://github.com/kmjak/tixforge-plugin/commit/d684fa4581186ec272aa4d290fa7b50908027a56))

## [3.1.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v3.0.0...tixforge--v3.1.0) (2026-11-21)


### Features

* fix agreed review findings on their own for up to three rounds ([#67](https://github.com/kmjak/tixforge-plugin/issues/67)) ([4b54841](https://github.com/kmjak/tixforge-plugin/commit/4b548416f07aa74355fb3e15fdeb828f1aa417bf))
* let users hand over a whole description and get a filled draft ([#69](https://github.com/kmjak/tixforge-plugin/issues/69)) ([1148068](https://github.com/kmjak/tixforge-plugin/commit/114806813178a9ffda03aa9d86d8d0d5b8cd83d5))
* stop at the Plan and PR gates by default ([#66](https://github.com/kmjak/tixforge-plugin/issues/66)) ([e23c3c3](https://github.com/kmjak/tixforge-plugin/commit/e23c3c31fae11c674664104733e97bc0d5280d38))


### Bug Fixes

* let Research read a few known files without Explore ([#65](https://github.com/kmjak/tixforge-plugin/issues/65)) ([c438217](https://github.com/kmjak/tixforge-plugin/commit/c438217924e082ed390ad02f7ab390b806b92477))

## [3.0.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v2.2.0...tixforge--v3.0.0) (2026-11-19)


### ⚠ BREAKING CHANGES

* tixforge now keeps tickets in GitHub issues only. Local tickets (LT-) and repository.host: none are gone: run /tixforge:project update to move LT tickets to issues, or stay on v2 if you do not use GitHub. See "v2 からの移行" in the README: https://github.com/kmjak/tixforge-plugin#v2-からの移行
* repository.close_issues is gone; an issue closes when it is released. In a develop flow that used close_issues: merge (or tixforge-issue-sync without the key), a merge into develop now leaves the issue open as tixforge:merged until the release. Update the copied workflow to tixforge-issue-sync (v6) with /tixforge:project update ("テンプレートと Actions を最新にする") before removing the key.

### Features

* add personal settings in .tixforge/config.local.yml ([#49](https://github.com/kmjak/tixforge-plugin/issues/49)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* close issues when they are released and drop close_issues ([#57](https://github.com/kmjak/tixforge-plugin/issues/57)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* define the labels once and describe them per language ([#43](https://github.com/kmjak/tixforge-plugin/issues/43)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* give the Review agents one input folder and shared rules ([#53](https://github.com/kmjak/tixforge-plugin/issues/53)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* migrate a run's state.md to the current format ([#33](https://github.com/kmjak/tixforge-plugin/issues/33)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* put the verification in every PR and comment it after each fix ([#55](https://github.com/kmjak/tixforge-plugin/issues/55)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* replace the ticket working copy with a dev snapshot ([#37](https://github.com/kmjak/tixforge-plugin/issues/37)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* require GitHub and drop local tickets ([#34](https://github.com/kmjak/tixforge-plugin/issues/34)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* show my PRs and the tickets in a side pane with /tixforge-panel ([#56](https://github.com/kmjak/tixforge-plugin/issues/56)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* split every skill's steps into named phases ([#51](https://github.com/kmjak/tixforge-plugin/issues/51)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* stop skipped git hooks and confirm check-config edits in a run ([#54](https://github.com/kmjak/tixforge-plugin/issues/54)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* suggest /compact at the Plan gate ([#52](https://github.com/kmjak/tixforge-plugin/issues/52)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* write the script messages in state.md in the personal language ([#50](https://github.com/kmjak/tixforge-plugin/issues/50)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))


### Bug Fixes

* call ticket operations by name in dev and ticket ([#36](https://github.com/kmjak/tixforge-plugin/issues/36)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* clear up the instructions the v3 benchmark found ambiguous ([#60](https://github.com/kmjak/tixforge-plugin/issues/60)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* describe every config key in references/config.md ([#48](https://github.com/kmjak/tixforge-plugin/issues/48)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* describe v3's commands in plugin.json and the statusline path ([#61](https://github.com/kmjak/tixforge-plugin/issues/61)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* keep each shared definition in one place ([#41](https://github.com/kmjak/tixforge-plugin/issues/41)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* keep the ticket template in templates/docs ([#42](https://github.com/kmjak/tixforge-plugin/issues/42)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* mend the v2 migration table and the marketplace description ([#63](https://github.com/kmjak/tixforge-plugin/issues/63)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* move messages.yml to the GitHub templates ([#40](https://github.com/kmjak/tixforge-plugin/issues/40)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* share the skills' common parts and trim the common rules ([#44](https://github.com/kmjak/tixforge-plugin/issues/44)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/dev to what changes what Claude does ([#45](https://github.com/kmjak/tixforge-plugin/issues/45)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/project to what changes what Claude does ([#46](https://github.com/kmjak/tixforge-plugin/issues/46)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* trim skills/ticket to what changes what Claude does ([#47](https://github.com/kmjak/tixforge-plugin/issues/47)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))
* write closing comments in the document language behind a mark ([#58](https://github.com/kmjak/tixforge-plugin/issues/58)) ([dcb5c2e](https://github.com/kmjak/tixforge-plugin/commit/dcb5c2e37e4fae8cfd8b28008f4508ab87478424))

## [2.2.0](https://github.com/kmjak/tixforge-plugin/compare/tixforge--v2.1.0...tixforge--v2.2.0) (2026-10-30)


### Features

* show the current run and its Status in the status line ([#27](https://github.com/kmjak/tixforge-plugin/issues/27)) ([6513209](https://github.com/kmjak/tixforge-plugin/commit/6513209fe47dcd4b7bbd27001f8f7ba3e5fb8fab))


### Bug Fixes

* keep no token after checkout in the workflow templates ([#25](https://github.com/kmjak/tixforge-plugin/issues/25)) ([6513209](https://github.com/kmjak/tixforge-plugin/commit/6513209fe47dcd4b7bbd27001f8f7ba3e5fb8fab))
