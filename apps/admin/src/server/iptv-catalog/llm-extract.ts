/**
 * Hybrid IPTV extract entrypoint.
 * Mechanical first; LLM agent is **opt-in** (`IPTV_LLM_EXTRACT=1`) + API key.
 * Agent errors never fail the scrape — fall back to mechanical.
 */
import type { ExtractedPortal } from './extract'
import {
  looksLikeIptvBlob,
  runIptvExtractAgent,
} from './agent/run-extract-agent'

/** Off unless explicitly enabled — key alone must not arm prod. */
function llmEnabled(): boolean {
  const flag = process.env.IPTV_LLM_EXTRACT?.trim().toLowerCase()
  if (flag !== '1' && flag !== 'true' && flag !== 'on') return false
  return Boolean(process.env.ANTHROPIC_API_KEY?.trim())
}

export { looksLikeIptvBlob }

/** @deprecated Prefer extractPortalsHybrid — kept for callers that want agent only. */
export async function extractPortalsWithLlm(
  rawText: string,
  source = 'catalog-llm',
): Promise<ExtractedPortal[]> {
  if (!llmEnabled() || !looksLikeIptvBlob(rawText)) return []
  try {
    const { portals } = await runIptvExtractAgent(rawText, source)
    return portals
  } catch (e) {
    console.error('[iptv-extract] LLM agent failed:', e)
    return []
  }
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
  try {
    const { portals } = await runIptvExtractAgent(rawText, `${source}-agent`)
    return {
      portals: portals.length > 0 ? portals : first,
      usedLlm: portals.length > 0,
    }
  } catch (e) {
    console.error('[iptv-extract] LLM agent failed, using mechanical:', e)
    return { portals: first, usedLlm: false }
  }
}
