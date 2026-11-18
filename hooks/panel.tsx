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
const lang = atom({ plugin: 'tixforge', key: 'lang' } as const, 'ja')
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
    noGh: 'gh がありません（https://cli.github.com）',
    noAuth: 'gh にログインしていません。! gh auth login でログインしてください',
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
    noGh: 'gh is not installed (https://cli.github.com)',
    noAuth: 'gh is not signed in: run ! gh auth login',
    failed: 'Fetch failed',
    opened: 'Opened the panel',
    closed: 'Closed the panel',
  },
}
type Words = (typeof WORDS)['ja']
const wordsFor = (lang: string | undefined): Words => (lang === 'en' ? WORDS.en : WORDS.ja)

// The module's own timers: dropped on a reload, started again at session.start.
let timers: Timer[] = []

// run panel-data.sh: its lang line sets the pane's words, an error line
// (exit 3 / 4) or a run that failed becomes the message. The body after the
// first record is kept as printed (blank lines too).
async function run($: EngineInterface, args: string[]): Promise<{ lines: string[] | null; rest: string; why: string }> {
  let out
  try {
    const cwd = await $.session.root()
    out = await $.process.run(['bash', `${$.plugin.root}/scripts/panel-data.sh`, ...args], { cwd, timeoutMs: 60_000 })
  } catch (thrown) {
    const w = wordsFor(await read($, lang))
    return { lines: null, rest: '', why: `${w.failed}: ${String(thrown).split('\n')[0]}` }
  }
  const all = out.stdout.split('\n')
  if (all[0]?.startsWith('lang\t')) {
    const got = all.shift()?.split('\t')[1] ?? 'ja'
    await update($, lang, () => got)
  }
  const w = wordsFor(await read($, lang))
  const first = (all[0] ?? '').split('\t')
  if (out.exitCode !== 0) {
    const reason = first[2] ? ` (${first[2]})` : ''
    const why =
      first[0] !== 'error'
        ? out.stderr.split('\n')[0] || `${w.failed} (${out.exitCode})`
        : first[1] === 'not-tixforge'
          ? w.notTixforge
          : first[1] === 'gh-missing'
            ? w.noGh
            : first[1] === 'gh-auth'
              ? `${w.noAuth}${reason}`
              : `${w.failed}${reason}`
    return { lines: null, rest: '', why }
  }

  return { lines: all.filter(l => l !== ''), rest: all.slice(1).join('\n'), why: '' }
}

async function refresh($: EngineInterface): Promise<void> {
  const got = await run($, ['list'])
  if (got.lines === null) {
    const why = got.why
    await update($, error, () => why)
    return
  }
  const fetchedAt = await $.clock.now()
  const next: PanelData = { me: '', lang: await read($, lang), prs: [], tickets: [], more: 0, fetchedAt }
  for (const line of got.lines) {
    const f = line.split('\t')
    if (f[0] === 'me') next.me = f[1] ?? ''
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
    body: got.rest,
  }
  const shown: PanelView = { kind: 'detail', id, issue }
  await update($, view, v => (v.kind === 'detail' && v.id === id ? shown : v))
}

// Start: queue /tixforge:dev (it runs once the session is idle) and go back
// to the list, so a second press cannot queue it twice.
async function startTicket($: EngineInterface, id: string): Promise<void> {
  const w = wordsFor(await read($, lang))
  await update($, view, () => ({ kind: 'list' }) as PanelView)
  $.ui.toast(w.queued)
  $.command.run({ command: 'tixforge:dev', args: id }).catch(thrown => $.ui.toast(`${w.failed}: ${String(thrown)}`))
}

function stop(): void {
  timers.forEach(t => t.cancel())
  timers = []
}

function startTimers($: EngineInterface): void {
  stop()
  timers = [
    $.clock.every(FRESH_MS, () => void feed($)),
    $.clock.every(60_000, () => void tick($)),
  ]
}

// A timer whose pane is gone (closed in a way no close hook saw) stops.
async function feed($: EngineInterface): Promise<void> {
  if (await isUp($)) await refresh($)
  else stop()
}

async function tick($: EngineInterface): Promise<void> {
  if (!(await isUp($))) return stop()
  const t = await $.clock.now()
  await update($, now, () => t)
}

async function isUp($: EngineInterface): Promise<boolean> {
  return (await $.ui.panes()).some(pane => pane.id === PANE)
}

async function isShown($: EngineInterface): Promise<boolean> {
  return (await $.ui.panes()).some(pane => pane.id === PANE && pane.isShown)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: COMMAND,
      description: 'tixforge: my PRs and the tickets in a side pane (run again to close)',
      // Opens while Claude works too: the handler reads no turn state.
      immediate: true,
    })
    const saved = await $.store.get('panel.sections')
    if (saved && typeof saved === 'object') await update($, sections, () => saved as { prs: boolean; tickets: boolean })
    // A reload while the pane stayed up: keep it fed.
    if (await isUp($)) startTimers($)

    return next(e)
  })

  on('command.run', { command: COMMAND }, async $ => {
    const w = wordsFor(await read($, lang))
    // Shown: close it. Open but behind another pane: bring it up.
    if (await isShown($)) {
      stop()
      await $.ui.close({ id: PANE })
      return { text: w.closed }
    }
    await update($, view, () => ({ kind: 'list' }) as PanelView)
    const opened = await $.ui.open({ id: PANE, title: w.title })
    if (!opened.isPlaced && !(await isUp($))) return { text: `${w.failed}: ${opened.reason ?? ''}` }
    startTimers($)
    const t = await $.clock.now()
    await update($, now, () => t)
    const old = await read($, data)
    if (!old || t - old.fetchedAt > FRESH_MS) void refresh($)

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
    const w = wordsFor(await read($, lang))

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
                  onPress={() => startTicket($, issue.id)}
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
