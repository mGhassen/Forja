import type { RegionGuess } from './types'

/** Lightweight port of crates/iptv region heuristics. */
export function classifyRegion(
  timezone: string | null | undefined,
  categoryNames: string[],
): RegionGuess {
  const scores = new Map<string, number>()

  const bump = (code: string, w: number) => {
    scores.set(code, (scores.get(code) ?? 0) + w)
  }

  if (timezone) {
    const t = timezone.toLowerCase()
    if (t.includes('istanbul')) bump('TR', 3)
    else if (t.includes('london') || t.includes('dublin')) bump('UK', 3)
    else if (
      t.includes('new_york') ||
      t.includes('chicago') ||
      t.includes('los_angeles') ||
      t.includes('america/')
    ) {
      bump('US', 2.5)
    } else if (t.includes('europe/')) bump('EU', 2)
    else if (t.includes('africa/casablanca') || t.includes('africa/tunis')) {
      bump('EU', 1)
      bump('MENA', 1.5)
    }
  }

  for (const raw of categoryNames) {
    const s = raw.toUpperCase()
    if (/\bTR\b|TURK|TÜRK|TURKEY/.test(s)) bump('TR', 2)
    if (/\bUK\b|BRITAIN|BRITISH/.test(s)) bump('UK', 2)
    if (/\bUS\b|USA\b|UNITED STATES|\bNFL\b|\bNBA\b/.test(s)) bump('US', 2)
    if (/\bDE\b|GERMAN|DEUTSCH/.test(s)) bump('DE', 1.5)
    if (/\bFR\b|FRENCH|FRANCE/.test(s)) bump('FR', 1.5)
    if (/\bIT\b|ITALY|ITALIAN/.test(s)) bump('IT', 1.5)
    if (/ARAB|MENA|العرب/.test(s)) bump('AR', 1.5)
    if (/\bEU\b|EUROPE/.test(s)) bump('EU', 1)
  }

  if (scores.size === 0) {
    return { primary: 'UNKNOWN', tags: [], confidence: 0 }
  }

  const ranked = [...scores.entries()].sort((a, b) => b[1] - a[1])
  const total = Math.max(
    ranked.reduce((s, [, v]) => s + v, 0),
    0.001,
  )
  const [topCode, topScore] = ranked[0]!
  const confidence = Math.min(1, Math.max(0, topScore / total))
  const tags = ranked.filter(([, s]) => s >= 1).map(([k]) => k)
  const primary =
    confidence < 0.45 && tags.length > 1 ? 'MIXED' : topCode

  return { primary, tags, confidence }
}
