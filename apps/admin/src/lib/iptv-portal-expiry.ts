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

  // Reddit cards: `24/01/2027 19:55:57` (DD/MM/YYYY). Skip unix-epoch placeholders.
  const dmy = /^(\d{1,2})\/(\d{1,2})\/(\d{4})/.exec(s)
  if (dmy) {
    const day = Number(dmy[1])
    const month = Number(dmy[2]) - 1
    const year = Number(dmy[3])
    if (year <= 1970) return null
    if (
      Number.isInteger(day) &&
      month >= 0 &&
      month <= 11 &&
      Number.isInteger(year) &&
      day >= 1 &&
      day <= 31
    ) {
      return new Date(year, month, day)
    }
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
      if (year <= 1970) return null
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
  if (!d) {
    // Xtream sentinel / never-expires placeholders — don't keep as expiry text.
    if (/\b1970\b/.test(s) || /^unknown$/i.test(s)) return null
    return s
  }
  const day = String(d.getDate()).padStart(2, '0')
  return `${day} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
}
