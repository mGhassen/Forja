/**
 * Mechanical-only smoke for the 4 paste fixtures (no Anthropic).
 */
import { readFileSync } from 'node:fs'
import { extractPortals } from '../src/server/iptv-catalog/extract'
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

for (const c of CASES) {
  const text = decryptFromPasteResponse(c.url, readFileSync(c.body, 'utf8'))
  if (!text) {
    console.log(c.id, 'DECRYPT FAIL')
    continue
  }
  const portals = extractPortals(text, c.id)
  const byPlat: Record<string, number> = {}
  let withExpiry = 0
  for (const p of portals) {
    byPlat[p.platform] = (byPlat[p.platform] ?? 0) + 1
    if (p.expiry) withExpiry++
  }
  console.log(
    c.id,
    'count=',
    portals.length,
    byPlat,
    'withExpiry=',
    withExpiry,
    'sample=',
    portals.slice(0, 3).map((p) => ({
      platform: p.platform,
      user: p.username,
      expiry: p.expiry,
      url: p.url.slice(0, 50),
    })),
  )
}
