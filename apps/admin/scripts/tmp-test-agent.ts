/**
 * Compare mechanical (no AI) vs forced agent (AI) on paste.sh fixtures.
 * Bodies: /tmp/forja-pastes/<id>.txt
 *
 *   ONLY=gDY7Rsoq node --env-file=.env /tmp/forja-test-agent.mjs
 */
import { readFileSync } from 'node:fs'
import { extractPortals } from '../src/server/iptv-catalog/extract'
import { runIptvExtractAgent } from '../src/server/iptv-catalog/agent/run-extract-agent'
import { decryptFromPasteResponse } from '../src/server/iptv-catalog/pastesh'

const CASES = [
  {
    id: 'j_1vsS7a',
    url: 'https://paste.sh/j_1vsS7a#4zoU15kXDNH7TbDXgi9vEpxZ',
    body: '/tmp/forja-pastes/j_1vsS7a.txt',
  },
  {
    id: 'R3RcRPmu',
    url: 'https://paste.sh/R3RcRPmu#i2IidinWM_6gTKG5KsZwFrcG',
    body: '/tmp/forja-pastes/R3RcRPmu.txt',
  },
  {
    id: 'mTnrUhpU',
    url: 'https://paste.sh/mTnrUhpU#jL5Ju8gLvvwuclW-aD_NyWxq',
    body: '/tmp/forja-pastes/mTnrUhpU.txt',
  },
  {
    id: 'gDY7Rsoq',
    url: 'https://paste.sh/gDY7Rsoq#OhITPxh8DOeKaGc9dqvuifOd',
    body: '/tmp/forja-pastes/gDY7Rsoq.txt',
  },
]

type Portal = ReturnType<typeof extractPortals>[number]

function summarize(portals: Portal[]) {
  const byPlat = new Map<string, number>()
  for (const p of portals) {
    byPlat.set(p.platform, (byPlat.get(p.platform) ?? 0) + 1)
  }
  const sample = portals.slice(0, 8).map((p) => ({
    platform: p.platform,
    url: p.url.slice(0, 72),
    user: p.username,
    type: p.type,
    output: p.output?.slice(0, 48),
    expiry: p.expiry,
    maxConn: p.maxConnections,
  }))
  return { count: portals.length, byPlat: Object.fromEntries(byPlat), sample }
}

function portalKey(p: Portal): string {
  return `${p.platform}|${p.url}|${p.username}|${p.password}|${p.type}|${p.output}`.toLowerCase()
}

function diff(mech: Portal[], agent: Portal[]) {
  const mKeys = new Set(mech.map(portalKey))
  const aKeys = new Set(agent.map(portalKey))
  const onlyMech = [...mKeys].filter((k) => !aKeys.has(k)).length
  const onlyAgent = [...aKeys].filter((k) => !mKeys.has(k)).length
  const both = [...mKeys].filter((k) => aKeys.has(k)).length
  return { onlyMech, onlyAgent, both }
}

async function main() {
  console.log('ANTHROPIC_API_KEY:', process.env.ANTHROPIC_API_KEY ? 'yes' : 'NO')
  console.log('mode: mechanical vs FORCED agent (always both)\n')

  const only = process.env.ONLY?.trim()
  for (const c of CASES) {
    if (only && c.id !== only) continue
    console.log('========', c.id, '========')
    const raw = readFileSync(c.body, 'utf8')
    const text = decryptFromPasteResponse(c.url, raw)
    if (!text) {
      console.log('  DECRYPT FAIL')
      continue
    }
    console.log('  chars:', text.length)

    const mechanical = extractPortals(text, `mech-${c.id}`)
    console.log('\n  --- WITHOUT AI (mechanical) ---')
    console.log(JSON.stringify(summarize(mechanical), null, 2))

    console.log('\n  --- WITH AI (forced agent) ---')
    try {
      const { portals, steps, session } = await runIptvExtractAgent(
        text,
        `agent-${c.id}`,
      )
      console.log('  steps:', steps, 'finish:', session.finishReason)
      console.log(JSON.stringify(summarize(portals), null, 2))
      console.log('\n  --- DIFF ---')
      console.log(JSON.stringify(diff(mechanical, portals), null, 2))
    } catch (e) {
      console.log('  AGENT ERROR:', e instanceof Error ? e.message : e)
    }
    console.log('')
  }
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
