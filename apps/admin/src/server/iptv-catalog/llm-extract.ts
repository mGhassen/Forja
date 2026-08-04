/**
 * Hybrid IPTV extract entrypoint.
 * Mechanical first; on 0 hits → tool-use agent (sample → layout → local full parse).
 */
import type { ExtractedPortal } from './extract'
import {
  looksLikeIptvBlob,
  runIptvExtractAgent,
} from './agent/run-extract-agent'

function llmEnabled(): boolean {
  const flag = process.env.IPTV_LLM_EXTRACT?.trim().toLowerCase()
  if (flag === '0' || flag === 'false' || flag === 'off') return false
  return Boolean(process.env.ANTHROPIC_API_KEY?.trim())
}

export { looksLikeIptvBlob }

/** @deprecated Prefer extractPortalsHybrid — kept for callers that want agent only. */
export async function extractPortalsWithLlm(
  rawText: string,
  source = 'catalog-llm',
): Promise<ExtractedPortal[]> {
  if (!llmEnabled() || !looksLikeIptvBlob(rawText)) return []
  const { portals } = await runIptvExtractAgent(rawText, source)
  return portals
}

export async function extractPortalsHybrid(
  rawText: string,
  source: string,
  mechanical: (text: string, src: string) => ExtractedPortal[],
): Promise<{ portals: ExtractedPortal[]; usedLlm: boolean }> {
  const first = mechanical(rawText, source)
  if (first.length > 0) return { portals: first, usedLlm: false }
  if (!llmEnabled() || !looksLikeIptvBlob(rawText)) {
    return { portals: first, usedLlm: false }
  }
  const { portals } = await runIptvExtractAgent(rawText, `${source}-agent`)
  return { portals, usedLlm: portals.length > 0 }
}
