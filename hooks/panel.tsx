// /tixforge-panel: the person's PRs and the tickets in a pane beside the chat.
// scripts/panel-data.sh fetches and decides everything (tests/scripts.test.sh
// checks it); this module only draws its lines and runs the buttons.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { PanelData, PanelIssue, PanelView } from '../types'

const PANE = 'tixforge-panel'
const COMMAND = 'tixforge-panel'
const FRESH_MS = 3 * 60 * 1000
const MAX_ROWS = 30

const data = atom({ plugin: 'tixforge', key: 'data' } as const, null, { shape: 'data-1' })
const error = atom({ plugin: 'tixforge', key: 'error' } as const, '')
const view = atom({ plugin: 'tixforge', key: 'view' } as const, { kind: 'list' }, { shape: 'view-1' })
const now = atom({ plugin: 'tixforge', key: 'now' } as const, 0)
const sections = atom({ plugin: 'tixforge', key: 'sections' } as const, { prs: true, tickets: true }, {
  shape: 'sections-1',
})

const WORDS = {
  ja: {
    title: 'tixforge',
    prs: 'PR',
    tickets: 'チケット',
    none: 'なし',
    more: (n: number) => `ほか ${n} 件`,
    ago: (m: number) => (m < 1 ? 'たった今' : `${m} 分前`),
    refresh: '更新',
    loading: '取得中',
    back: '戻る',
    start: '開始',
    assigned: '他の人が担当',
    started: 'すでに進行中',
    queued: '作業が終わったら始めます',
    notTixforge: 'tixforge のリポジトリではありません',
    noGh: 'gh を使えません。! gh auth login でログインしてください',
    failed: '取得に失敗',
    opened: 'パネルを開きました',
    closed: 'パネルを閉じました',
  },
  en: {
    title: 'tixforge',
    prs: 'PRs',
    tickets: 'Tickets',
    none: 'none',
    more: (n: number) => `${n} more`,
    ago: (m: number) => (m < 1 ? 'just now' : `${m} min ago`),
    refresh: 'Refresh',
    loading: 'Loading',
    back: 'Back',
    start: 'Start',
    assigned: 'Someone else has it',
    started: 'Already in progress',
    queued: 'Starts when the current work ends',
    notTixforge: 'Not a tixforge repository',
    noGh: 'gh is not available: sign in with ! gh auth login',
    failed: 'Fetch failed',
    opened: 'Opened the panel',
    closed: 'Closed the panel',
  },
}
type Words = (typeof WORDS)['ja']
const wordsFor = (lang: string | undefined): Words => (lang === 'en' ? WORDS.en : WORDS.ja)

// The module's own timers: dropped on a reload, started again at session.start.
let timers: Timer[] = []

// run panel-data.sh; its error line (exit 3 / 4) becomes the message.
async function run($: EngineInterface, args: string[]): Promise<{ lines: string[] | null; why: string }> {
  const cwd = await $.session.root()
  const out = await $.process.run(['bash', `${$.plugin.root}/scripts/panel-data.sh`, ...args], {
    cwd,
    timeoutMs: 60_000,
  })
  const lines = out.stdout.split('\n').filter(l => l !== '')
  const first = (lines[0] ?? '').split('\t')
  if (out.exitCode !== 0) {
    const w = wordsFor((await read($, data))?.lang)
    const why =
      first[0] === 'error' && first[1] === 'not-tixforge'
        ? w.notTixforge
        : first[0] === 'error' && first[1] === 'gh'
          ? `${w.noGh}${first[2] ? ` (${first[2]})` : ''}`
          : out.stderr.split('\n')[0] || `${w.failed} (${out.exitCode})`
    return { lines: null, why }
  }

  return { lines, why: '' }
}

async function refresh($: EngineInterface): Promise<void> {
  const got = await run($, ['list'])
  if (got.lines === null) {
    const why = got.why
    await update($, error, () => why)
    return
  }
  const fetchedAt = await $.clock.now()
  const next: PanelData = { me: '', lang: 'ja', prs: [], tickets: [], more: 0, fetchedAt }
  for (const line of got.lines) {
    const f = line.split('\t')
    if (f[0] === 'me') next.me = f[1] ?? ''
    else if (f[0] === 'lang') next.lang = f[1] ?? 'ja'
    else if (f[0] === 'pr')
      next.prs.push({ number: f[1] ?? '', verdict: f[2] ?? '', isDraft: f[3] === 'draft', url: f[4] ?? '', title: f.slice(5).join(' ') })
    else if (f[0] === 'ticket')
      next.tickets.push({ id: f[1] ?? '', state: f[2] ?? '', assignee: f[3] ?? '-', isMine: f[4] === 'mine', title: f.slice(5).join(' ') })
    else if (f[0] === 'more') next.more = Number(f[1]) || 0
  }
  await update($, data, () => next)
  await update($, error, () => '')
  await update($, now, () => fetchedAt)
}

async function showIssue($: EngineInterface, id: string): Promise<void> {
  await update($, view, () => ({ kind: 'detail', id }) as PanelView)
  const got = await run($, ['issue', id])
  if (got.lines === null) {
    const why = got.why
    await update($, view, v => (v.kind === 'detail' && v.id === id ? { ...v, error: why } : v))
    return
  }
  const f = (got.lines[0] ?? '').split('\t')
  const start = f[4] === 'yes' || f[4] === 'assigned' ? f[4] : 'started'
  const issue: PanelIssue = {
    id: f[1] ?? id,
    state: f[2] ?? '-',
    assignees: f[3] ?? '-',
    start,
    title: f.slice(5).join(' '),
    body: got.lines.slice(1).join('\n'),
  }
  const shown: PanelView = { kind: 'detail', id, issue }
  await update($, view, v => (v.kind === 'detail' && v.id === id ? shown : v))
}

function stop(): void {
  timers.forEach(t => t.cancel())
  timers = []
}

function startTimers($: EngineInterface): void {
  stop()
  timers = [
    $.clock.every(FRESH_MS, () => void refresh($)),
    $.clock.every(60_000, () => void tick($)),
  ]
}

async function tick($: EngineInterface): Promise<void> {
  const t = await $.clock.now()
  await update($, now, () => t)
}

async function isUp($: EngineInterface): Promise<boolean> {
  return (await $.ui.panes()).some(pane => pane.id === PANE)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: COMMAND,
      description: '自分の PR と tixforge のチケットを右側のパネルに出す・閉じる（tixforge）',
    })
    const saved = await $.store.get('panel.sections')
    if (saved && typeof saved === 'object') await update($, sections, () => saved as { prs: boolean; tickets: boolean })
    // A reload while the pane stayed up: keep it fed.
    if (await isUp($)) startTimers($)

    return next(e)
  })

  on('command.run', { command: COMMAND }, async $ => {
    const w = wordsFor((await read($, data))?.lang)
    if (await isUp($)) {
      stop()
      await $.ui.close({ id: PANE })
      return { text: w.closed }
    }
    await update($, view, () => ({ kind: 'list' }) as PanelView)
    await $.ui.open({ id: PANE, title: w.title })
    startTimers($)
    const old = await read($, data)
    if (!old || (await $.clock.now()) - old.fetchedAt > FRESH_MS) await refresh($)

    return { text: w.opened }
  })

  on('ui.close', ($, e, next) => {
    if ((e as { id?: string }).id === PANE) stop()
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button, Markdown, Link } = $.ui.resolve(e) as any
    const d = await read($, data)
    const err = await read($, error)
    const v = await read($, view)
    const at = await read($, now)
    const open = await read($, sections)
    const w = wordsFor(d?.lang)

    if (v.kind === 'detail') {
      const issue = v.issue
      return (
        <Box flexDirection="column">
          <Box flexDirection="row">
            <Button key="back" label={w.back} onPress={() => update($, view, () => ({ kind: 'list' }) as PanelView)} />
          </Box>
          {v.error && <Text color="error">{v.error}</Text>}
          {!issue && !v.error && <Text dimColor>{w.loading}…</Text>}
          {issue && (
            <Box flexDirection="column">
              <Text bold>
                {issue.id} {issue.title}
              </Text>
              <Text dimColor>
                {issue.state} · {issue.assignees}
              </Text>
              {issue.start === 'yes' ? (
                <Button
                  key="start"
                  variant="primary"
                  label={w.start}
                  onPress={async () => {
                    // Queued: it runs once the session is idle.
                    void $.command.run({ command: 'tixforge:dev', args: issue.id })
                    $.ui.toast(w.queued)
                  }}
                />
              ) : (
                <Text dimColor>
                  {w.start}: {issue.start === 'assigned' ? w.assigned : w.started}
                </Text>
              )}
              <Markdown text={issue.body} />
            </Box>
          )}
        </Box>
      )
    }

    const minutes = d ? Math.max(0, Math.floor(((at || d.fetchedAt) - d.fetchedAt) / 60_000)) : 0
    const toggle = (key: 'prs' | 'tickets') => async () => {
      const nextOpen = await update($, sections, s => ({ ...s, [key]: !s[key] }))
      await $.store.set('panel.sections', nextOpen)
    }

    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Text dimColor>{d ? w.ago(minutes) : err ? '' : `${w.loading}…`} </Text>
          {err && <Text color="error">{d ? `${w.failed}: ${err}` : err} </Text>}
          <Button key="refresh" label={w.refresh} onPress={() => refresh($)} />
        </Box>
        {d && (
          <Box flexDirection="column">
            <Button key="prs" plain onPress={toggle('prs')}>
              {open.prs ? '▾' : '▸'} {w.prs} <Text dimColor>({d.prs.length})</Text>
            </Button>
            {open.prs && d.prs.length === 0 && <Text dimColor>  {w.none}</Text>}
            {open.prs &&
              d.prs.map(pr => (
                <Link key={`pr-${pr.number}`} href={pr.url}>
                  {`  #${pr.number} ${pr.title} ${pr.verdict}${pr.isDraft ? ' draft' : ''}`}
                </Link>
              ))}
            <Button key="tickets" plain onPress={toggle('tickets')}>
              {open.tickets ? '▾' : '▸'} {w.tickets} <Text dimColor>({d.tickets.length + d.more})</Text>
            </Button>
            {open.tickets && d.tickets.length === 0 && <Text dimColor>  {w.none}</Text>}
            {open.tickets &&
              d.tickets.slice(0, MAX_ROWS).map(t => (
                <Button key={`t-${t.id}`} plain onPress={() => showIssue($, t.id)}>
                  <Text color={t.isMine ? 'suggestion' : undefined}>{t.isMine ? '● ' : '  '}{t.id}</Text> {t.title}{' '}
                  <Text dimColor>{t.assignee}</Text>
                </Button>
              ))}
            {open.tickets && d.more > 0 && <Text dimColor>  {w.more(d.more)}</Text>}
          </Box>
        )}
      </Box>
    )
  })
}
