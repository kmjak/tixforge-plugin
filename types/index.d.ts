// The values the /tixforge-panel pane (hooks/panel.tsx) keeps in $.state.
// scripts/panel-data.sh makes them; the pane only draws them.

export type PanelPr = {
  number: string
  verdict: string
  isDraft: boolean
  url: string
  title: string
}

export type PanelTicket = {
  id: string
  state: string
  assignee: string
  isMine: boolean
  title: string
}

export type PanelData = {
  me: string
  lang: string
  prs: PanelPr[]
  tickets: PanelTicket[]
  more: number
  fetchedAt: number
}

export type PanelIssue = {
  id: string
  state: string
  assignees: string
  start: 'yes' | 'assigned' | 'started'
  title: string
  body: string
}

export type PanelView =
  | { kind: 'list' }
  | { kind: 'detail'; id: string; issue?: PanelIssue; error?: string }

declare module 'claude-code' {
  interface PluginState {
    tixforge: {
      data: Shaped<PanelData | null>
      error: string
      view: Shaped<PanelView>
      now: number
      lang: string
      sections: Shaped<{ prs: boolean; tickets: boolean }>
    }
  }
}
