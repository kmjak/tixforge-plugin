// The /tixforge-panel pane: it draws what scripts/panel-data.sh prints (that
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

const RUN = {
  command: 'tixforge-panel',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: true, columns: 160 },
} as const

const list = (lang: string) =>
  [
    `lang\t${lang}`,
    'me\tme',
    'pr\t7\tconflict\t-\thttps://github.com/o/r/pull/7\tFix it',
    'ticket\tGT-000009\tin-review\tme\tmine\tMine',
    'ticket\tGT-000003\ttodo\t-\t-\tFree',
    'ticket\tGT-000005\ttodo\tann\t-\tTaken',
    'more\t2',
  ].join('\n')

const ISSUES: Record<string, string> = {
  'GT-000003': ['lang\tja', 'issue\tGT-000003\ttodo\t-\tyes\tFree', '## 背景', '', '段落'].join('\n'),
  'GT-000005': ['lang\tja', 'issue\tGT-000005\ttodo\tann\tassigned\tTaken', '## 背景'].join('\n'),
}

type Answer = { exitCode: number; stdout: string } | Error

// The world beneath the pane: one pane, panel-data.sh answering `answer`.
function world(on: any, answer: (argv: readonly string[]) => Answer) {
  let panes: string[] = []
  const runs: string[] = []
  on('command.register', () => ({ value: { command: 'tixforge-panel' } }))
  on('ui.open', (_: unknown, e: { id: string }) => {
    panes = [e.id]
    return { value: { isPlaced: true } }
  })
  on('ui.close', () => {
    panes = []
    return { value: undefined }
  })
  on('ui.panes', () => ({
    value: panes.map(id => ({ id, title: 'tixforge', isShown: true, isFocused: false, isPlaced: true })),
  }))
  on('ui.toast', () => ({ value: undefined }))
  on('process.run', (_: unknown, e: { argv: readonly string[] }) => {
    const a = answer(e.argv)
    if (a instanceof Error) throw a
    return { value: { ...a, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('command.run', { command: 'tixforge:dev' }, (_: unknown, e: { command: string; args: string }) => {
    runs.push(`/${e.command} ${e.args}`)
    return { text: '' }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  mock.clock(on)
  mock.store(on)
  on('session.root', () => ({ value: '/repo' }))

  return { runs, panes: () => panes }
}

const ok =
  (lang = 'ja') =>
  (argv: readonly string[]): Answer =>
    argv.includes('issue')
      ? { exitCode: 0, stdout: ISSUES[argv[argv.length - 1] ?? ''] ?? '' }
      : { exitCode: 0, stdout: list(lang) }

test('the command opens the pane, which lists the PRs and the tickets', async ($, on) => {
  const w = world(on, ok())
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run(RUN)

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    await ui.press({ key: 'refresh' })
    expect(await ui.find({ type: 'Link', text: /#7 Fix it conflict/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /● GT-000009/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /ほか 2 件/ })).toBeDefined()
    await ui.unmount()
  }

  // A ticket opens its detail, fetched again, the body's blank line kept;
  // Start queues /tixforge:dev once and goes back to the list.
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'refresh' })
  await ui.press({ key: 't-GT-000003' })
  expect(await ui.find({ type: 'Text', text: /GT-000003 Free/ })).toBeDefined()
  expect((await ui.find({ type: 'Markdown' }))?.text).toBe('## 背景\n\n段落')
  await ui.press({ key: 'start' })
  expect(w.runs).toEqual(['/tixforge:dev GT-000003'])
  expect(await ui.find({ type: 'Text', text: /ほか 2 件/ })).toBeDefined()

  // Someone else's todo cannot be started.
  await ui.press({ key: 't-GT-000005' })
  expect(await ui.find({ type: 'Text', text: /他の人が担当/ })).toBeDefined()
  await ui.press({ key: 'back' })
  await ui.unmount()

  // The command again closes it.
  await $.command.run(RUN)
  expect(w.panes()).toEqual([])
})

test('the words follow the language panel-data.sh names', async ($, on) => {
  world(on, ok('en'))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run(RUN)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'refresh' })
  expect(await ui.find({ type: 'Text', text: /2 more/ })).toBeDefined()
  await ui.unmount()
})

test('a failed fetch keeps the list and says so', async ($, on) => {
  let fail = false
  world(on, argv => (fail ? new Error('timed out') : ok()(argv)))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run(RUN)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'refresh' })
  fail = true
  await ui.press({ key: 'refresh' })
  expect(await ui.find({ type: 'Text', text: /取得に失敗/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /ほか 2 件/ })).toBeDefined()
  await ui.unmount()
})

test('outside a tixforge repository the pane says so', async ($, on) => {
  world(on, () => ({ exitCode: 3, stdout: 'lang\tja\nerror\tnot-tixforge\n' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run(RUN)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'refresh' })
  expect(await ui.find({ type: 'Text', text: /tixforge のリポジトリではありません/ })).toBeDefined()
  await ui.unmount()
})
