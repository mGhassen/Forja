import {
  type ExtractedPortal,
  type FileMeta,
  extractPortals,
} from '../extract'
import {
  type NoteLayout,
  applyNoteLayout,
  buildStructureSample,
  previewPortals,
} from './layout'

export const AGENT_TOOLS = [
  {
    name: 'read_sample',
    description:
      'Return a ~3.5k dense sample (header + credential lines) of the note. Prefer this over peeking the whole file.',
    input_schema: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: 'peek_lines',
    description:
      'Return a small line window from the full note (0-based start, max 40 lines).',
    input_schema: {
      type: 'object',
      properties: {
        start: { type: 'integer', minimum: 0 },
        count: { type: 'integer', minimum: 1, maximum: 40 },
      },
      required: ['start', 'count'],
      additionalProperties: false,
    },
  },
  {
    name: 'run_mechanical',
    description:
      'Run free mechanical regex extract on the FULL note. Returns count + small preview.',
    input_schema: {
      type: 'object',
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: 'apply_layout',
    description:
      'Apply a layout (kind + token roles) across the FULL note locally. Returns count + preview. Does not call the LLM on the body.',
    input_schema: {
      type: 'object',
      properties: {
        kind: {
          type: 'string',
          enum: [
            'table',
            'emoji_card',
            'get_php',
            'labeled',
            'line_template',
            'unknown',
          ],
        },
        tokens: {
          type: 'array',
          items: {
            type: 'string',
            enum: [
              'hostPort',
              'userPass',
              'conn',
              'expiryMonDay',
              'expiryYear',
              'expiryNo',
              'status',
              'outputs',
              'timezone',
              'skip',
              'hostRepeat',
            ],
          },
        },
        platformHint: {
          type: 'string',
          enum: ['xtream', 'm3u', 'stalker'],
        },
        regionHint: { type: 'string' },
        minUserLen: { type: 'integer', minimum: 1, maximum: 8 },
        minPassLen: { type: 'integer', minimum: 1, maximum: 8 },
        confidence: { type: 'number' },
      },
      required: ['kind'],
      additionalProperties: false,
    },
  },
  {
    name: 'commit_portals',
    description:
      'Commit portals from the last mechanical run, last layout apply, or merge of both. Call before finish.',
    input_schema: {
      type: 'object',
      properties: {
        source: {
          type: 'string',
          enum: ['mechanical', 'layout', 'merge'],
          description: 'Which bucket to commit.',
        },
      },
      required: ['source'],
      additionalProperties: false,
    },
  },
  {
    name: 'finish',
    description: 'End the agent loop. Call after commit_portals (or when sure note is empty).',
    input_schema: {
      type: 'object',
      properties: {
        reason: { type: 'string' },
      },
      required: ['reason'],
      additionalProperties: false,
    },
  },
] as const

export type AgentToolName = (typeof AGENT_TOOLS)[number]['name']

export type AgentSession = {
  fullText: string
  source: string
  fileMeta: FileMeta
  lines: string[]
  mechanical: ExtractedPortal[]
  layoutHits: ExtractedPortal[]
  committed: ExtractedPortal[]
  finished: boolean
  finishReason: string | null
  lastLayout: NoteLayout | null
}

export function createAgentSession(
  fullText: string,
  source: string,
  fileMeta: FileMeta,
): AgentSession {
  return {
    fullText,
    source,
    fileMeta,
    lines: fullText.split(/\r?\n/),
    mechanical: [],
    layoutHits: [],
    committed: [],
    finished: false,
    finishReason: null,
    lastLayout: null,
  }
}

function mergePortals(
  buckets: ExtractedPortal[][],
): ExtractedPortal[] {
  const acc = new Map<string, ExtractedPortal>()
  for (const list of buckets) {
    for (const p of list) {
      const key =
        `${p.platform}|${p.url}|${p.username}|${p.password}|${p.type}|${p.output}`.toLowerCase()
      if (!acc.has(key)) acc.set(key, p)
    }
  }
  return [...acc.values()]
}

export function executeAgentTool(
  session: AgentSession,
  name: string,
  input: Record<string, unknown>,
): unknown {
  switch (name as AgentToolName) {
    case 'read_sample': {
      const s = buildStructureSample(session.fullText)
      return {
        truncated: s.truncated,
        lineCount: s.lineCount,
        denseLineCount: s.denseLineCount,
        sampleChars: s.sample.length,
        sample: s.sample,
      }
    }
    case 'peek_lines': {
      const start = Math.max(0, Number(input.start) || 0)
      const count = Math.min(40, Math.max(1, Number(input.count) || 10))
      const slice = session.lines.slice(start, start + count)
      return {
        start,
        count: slice.length,
        totalLines: session.lines.length,
        lines: slice,
      }
    }
    case 'run_mechanical': {
      session.mechanical = extractPortals(session.fullText, session.source)
      return {
        count: session.mechanical.length,
        preview: previewPortals(session.mechanical),
      }
    }
    case 'apply_layout': {
      const layout: NoteLayout = {
        kind: (input.kind as NoteLayout['kind']) || 'unknown',
        tokens: Array.isArray(input.tokens)
          ? (input.tokens as NoteLayout['tokens'])
          : undefined,
        regionHint:
          input.regionHint === undefined
            ? null
            : (input.regionHint as string | null),
        platformHint:
          input.platformHint === undefined
            ? null
            : (input.platformHint as NoteLayout['platformHint']),
        minUserLen:
          input.minUserLen != null ? Number(input.minUserLen) : undefined,
        minPassLen:
          input.minPassLen != null ? Number(input.minPassLen) : undefined,
        confidence:
          input.confidence != null ? Number(input.confidence) : undefined,
      }
      session.lastLayout = layout
      session.layoutHits = applyNoteLayout(
        session.fullText,
        layout,
        `${session.source}-layout`,
        session.fileMeta,
      )
      return {
        count: session.layoutHits.length,
        layout,
        preview: previewPortals(session.layoutHits),
      }
    }
    case 'commit_portals': {
      const src = String(input.source || 'merge')
      if (src === 'mechanical') {
        session.committed = [...session.mechanical]
      } else if (src === 'layout') {
        session.committed = [...session.layoutHits]
      } else {
        session.committed = mergePortals([
          session.mechanical,
          session.layoutHits,
        ])
      }
      return {
        committed: session.committed.length,
        source: src,
        preview: previewPortals(session.committed),
      }
    }
    case 'finish': {
      session.finished = true
      session.finishReason = String(input.reason || 'done')
      // If agent forgot commit, auto-merge best effort.
      if (session.committed.length === 0) {
        session.committed = mergePortals([
          session.mechanical,
          session.layoutHits,
        ])
      }
      return {
        finished: true,
        reason: session.finishReason,
        committed: session.committed.length,
      }
    }
    default:
      return { error: `unknown tool: ${name}` }
  }
}
