/** Match Flutter `_formatExpiry` / `_parsePortalExpiryDate` (dd MMM yyyy). */
const MONTHS = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
] as const

const MONTH_INDEX: Record<string, number> = {
  jan: 0,
  feb: 1,
  mar: 2,
  apr: 3,
  may: 4,
  jun: 5,
  jul: 6,
  aug: 7,
  sep: 8,
  oct: 9,
  nov: 10,
  dec: 11,
}

export function parsePortalExpiry(raw?: string | null): Date | null {
  const s = (raw ?? '').trim()
  if (!s || s.toLowerCase() === 'unknown') return null

  if (/^\d+$/.test(s)) {
    const n = Number(s)
    // Xtream `exp_date` is unix seconds; treat large values as millis.
    const ms = n > 1e12 ? n : n * 1000
    const d = new Date(ms)
    return Number.isNaN(d.getTime()) ? null : d
  }

  const parts = s.split(/\s+/)
  if (parts.length === 3) {
    const day = Number(parts[0])
    const month = MONTH_INDEX[parts[1].toLowerCase()]
    const year = Number(parts[2])
    if (
      Number.isInteger(day) &&
      month != null &&
      Number.isInteger(year) &&
      day >= 1 &&
      day <= 31
    ) {
      return new Date(year, month, day)
    }
  }

  const d = new Date(s)
  return Number.isNaN(d.getTime()) ? null : d
}

export function formatPortalExpiry(raw?: string | null): string | null {
  if (raw == null) return null
  const s = String(raw).trim()
  if (!s) return null
  const d = parsePortalExpiry(s)
  if (!d) return s
  const day = String(d.getDate()).padStart(2, '0')
  return `${day} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
}
