// The /tixforge:panel pane: it draws what scripts/panel-data.sh prints (that
// script's own tests are in tests/scripts.test.sh). Run: claude plugin test .
import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'tixforge',
  component: 'Pane',
  requestId: 'tixforge-panel',
  props: {
    title: 'tixforge',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
} as const

const LIST = [
  'me\tme',
  'lang\tja',
  'pr\t7\tconflict\t-\thttps://github.com/o/r/pull/7\tFix it',
  'ticket\tGT-000009\tin-review\tme\tmine\tMine',
  'ticket\tGT-000003\ttodo\t-\t-\tFree',
  'more\t2',
].join('\n')

const ISSUE = ['issue\tGT-000003\ttodo\t-\tyes\tFree', '## 背景', '本文'].join('\n')

test('the command opens the pane, which lists the PRs and the tickets', async ($, on) => {
  let panes: string[] = []
  const submitted: string[] = []
  on('command.register', () => ({ value: { command: 'tixforge-panel' } }))
  on('ui.open', (_, e) => {
    panes = [e.id]
    return { value: { isPlaced: true } }
  })
  on('ui.panes', () => ({ value: panes.map(id => ({ id, title: 'tixforge', isShown: true, isFocused: false, isPlaced: true })) }))
  on('process.run', (_, e) => ({
    value: { exitCode: 0, stdout: e.argv.includes('issue') ? ISSUE : LIST, stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('command.run', { command: 'tixforge:dev' }, (_, e) => {
    submitted.push(`/${e.command} ${e.args}`)
    return { text: '' }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  mock.clock(on)
  mock.store(on)
  on('session.root', () => ({ value: '/repo' }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'tixforge-panel', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Link', text: /#7 Fix it conflict/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /● GT-000009/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /ほか 2 件/ })).toBeDefined()
    await ui.unmount()
  }

  // A ticket opens its detail, fetched again; Start sends /tixforge:dev.
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 't-GT-000003' })
  expect(await ui.find({ type: 'Text', text: /GT-000003 Free/ })).toBeDefined()
  await ui.press({ key: 'start' })
  expect(submitted).toEqual(['/tixforge:dev GT-000003'])
  await ui.press({ key: 'back' })
  expect(await ui.find({ type: 'Text', text: /ほか 2 件/ })).toBeDefined()
  await ui.unmount()
})

test('outside a tixforge repository the pane says so', async ($, on) => {
  on('command.register', () => ({ value: { command: 'tixforge-panel' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.panes', () => ({ value: [] }))
  on('process.run', () => ({
    value: { exitCode: 3, stdout: 'error\tnot-tixforge\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  mock.clock(on)
  mock.store(on)
  on('session.root', () => ({ value: '/repo' }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'tixforge-panel', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 160 } })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /tixforge のリポジトリではありません/ })).toBeDefined()
  await ui.unmount()
})
