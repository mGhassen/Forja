import { parseNoteFileMeta, type ExtractedPortal } from '../extract'
import {
  IPTV_EXTRACT_AGENT_NAME,
  IPTV_EXTRACT_AGENT_SKILL,
} from './skill'
import {
  AGENT_TOOLS,
  createAgentSession,
  executeAgentTool,
  type AgentSession,
} from './tools'

const DEFAULT_MODEL = 'claude-haiku-4-5-20251001'
const MAX_STEPS = 10

type AnthropicContent =
  | { type: 'text'; text: string }
  | {
      type: 'tool_use'
      id: string
      name: string
      input: Record<string, unknown>
    }

type AnthropicMessage = {
  role: 'user' | 'assistant'
  content: string | AnthropicContent[]
}

function modelId(): string {
  return process.env.IPTV_LLM_MODEL?.trim() || DEFAULT_MODEL
}

function llmEnabled(): boolean {
  const flag = process.env.IPTV_LLM_EXTRACT?.trim().toLowerCase()
  if (flag !== '1' && flag !== 'true' && flag !== 'on') return false
  return Boolean(process.env.ANTHROPIC_API_KEY?.trim())
}

export function looksLikeIptvBlob(text: string): boolean {
  if (text.length < 25) return false
  const t = text.toLowerCase()
  return (
    t.includes('http://') ||
    t.includes('https://') ||
    t.includes('get.php') ||
    t.includes('username') ||
    t.includes('password') ||
    t.includes('maxconn') ||
    t.includes('xtream') ||
    t.includes('m3u') ||
    /:\d{2,5}\s+\S+:\S+/.test(text) ||
    /(?:\d{1,3}\.){3}\d{1,3}:\d{2,5}/.test(text)
  )
}

async function anthropicTurn(
  key: string,
  messages: AnthropicMessage[],
): Promise<{ content: AnthropicContent[]; stopReason: string }> {
  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: modelId(),
      max_tokens: 2048,
      temperature: 0,
      system: IPTV_EXTRACT_AGENT_SKILL,
      tools: AGENT_TOOLS,
      messages,
    }),
  })
  if (!resp.ok) {
    const body = await resp.text().catch(() => '')
    throw new Error(`anthropic HTTP ${resp.status}: ${body.slice(0, 400)}`)
  }
  const json = (await resp.json()) as {
    content?: AnthropicContent[]
    stop_reason?: string
  }
  return {
    content: json.content ?? [],
    stopReason: json.stop_reason ?? '',
  }
}

/**
 * Agentic IPTV extract: tool-use loop (read_sample → mechanical/layout → commit → finish).
 * Full note stays local; tools only return samples / peeks / counts.
 */
export async function runIptvExtractAgent(
  rawText: string,
  source = 'catalog-agent',
): Promise<{ portals: ExtractedPortal[]; session: AgentSession; steps: number }> {
  if (!llmEnabled()) {
    const fileMeta = parseNoteFileMeta(rawText)
    const session = createAgentSession(rawText, source, fileMeta)
    return { portals: [], session, steps: 0 }
  }

  const key = process.env.ANTHROPIC_API_KEY!.trim()
  const fileMeta = parseNoteFileMeta(rawText)
  const session = createAgentSession(rawText, source, fileMeta)

  const messages: AnthropicMessage[] = [
    {
      role: 'user',
      content: `Agent: ${IPTV_EXTRACT_AGENT_NAME}
Note size: ${rawText.length} chars, ${session.lines.length} lines.
Use tools to extract all IPTV portals. Start with read_sample and run_mechanical.`,
    },
  ]

  let steps = 0
  while (steps < MAX_STEPS && !session.finished) {
    steps++
    const turn = await anthropicTurn(key, messages)
    messages.push({ role: 'assistant', content: turn.content })

    const toolUses = turn.content.filter(
      (c): c is Extract<AnthropicContent, { type: 'tool_use' }> =>
        c.type === 'tool_use',
    )
    if (toolUses.length === 0) {
      // Model stopped without tools — finish with whatever we have.
      session.finished = true
      session.finishReason = 'no_tool_use'
      if (session.committed.length === 0) {
        session.committed = [
          ...new Map(
            [...session.mechanical, ...session.layoutHits].map((p) => [
              `${p.url}|${p.username}|${p.password}`.toLowerCase(),
              p,
            ]),
          ).values(),
        ]
      }
      break
    }

    const results: Array<{
      type: 'tool_result'
      tool_use_id: string
      content: string
      is_error?: boolean
    }> = []
    for (const tu of toolUses) {
      try {
        const out = executeAgentTool(
          session,
          tu.name,
          (tu.input ?? {}) as Record<string, unknown>,
        )
        results.push({
          type: 'tool_result',
          tool_use_id: tu.id,
          content: JSON.stringify(out),
        })
      } catch (e) {
        results.push({
          type: 'tool_result',
          tool_use_id: tu.id,
          is_error: true,
          content: e instanceof Error ? e.message : 'tool failed',
        })
      }
    }
    messages.push({
      role: 'user',
      // Anthropic tool_result blocks
      content: results as unknown as AnthropicContent[],
    })

    if (session.finished) break
  }

  if (!session.finished && session.committed.length === 0) {
    session.committed = [
      ...new Map(
        [...session.mechanical, ...session.layoutHits].map((p) => [
          `${p.url}|${p.username}|${p.password}`.toLowerCase(),
          p,
        ]),
      ).values(),
    ]
    session.finishReason = session.finishReason ?? 'max_steps'
  }

  return { portals: session.committed, session, steps }
}
