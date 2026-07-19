/** 5-field UTC cron helpers for IPTV scrape automation. */

const FIELD_RE = /^(\*|([0-9]|[1-5][0-9])|\*\/[1-9][0-9]*|([0-9]|[1-5][0-9])-([0-9]|[1-5][0-9]))$/
const HOUR_RE = /^(\*|([0-9]|1[0-9]|2[0-3])|\*\/[1-9][0-9]*|([0-9]|1[0-9]|2[0-3])-([0-9]|1[0-9]|2[0-3]))$/
const DOM_RE = /^(\*|([1-9]|[12][0-9]|3[01])|\*\/[1-9][0-9]*|([1-9]|[12][0-9]|3[01])-([1-9]|[12][0-9]|3[01]))$/
const MON_RE = /^(\*|([1-9]|1[0-2])|\*\/[1-9][0-9]*|([1-9]|1[0-2])-([1-9]|1[0-2]))$/
const DOW_RE = /^(\*|[0-6]|\*\/[1-9][0-9]*|[0-6]-[0-6])$/

export const DEFAULT_SCRAPE_CRON = '0 6 * * *'

export type CronPreset = {
  id: string
  label: string
  cron: string
}

export const SCRAPE_CRON_PRESETS: CronPreset[] = [
  { id: 'daily-06', label: 'Every day at 06:00 UTC', cron: '0 6 * * *' },
  { id: 'daily-00', label: 'Every day at 00:00 UTC', cron: '0 0 * * *' },
  { id: 'daily-12', label: 'Every day at 12:00 UTC', cron: '0 12 * * *' },
  { id: 'every-6h', label: 'Every 6 hours', cron: '0 */6 * * *' },
  { id: 'every-12h', label: 'Every 12 hours', cron: '0 */12 * * *' },
  { id: 'hourly', label: 'Every hour', cron: '0 * * * *' },
]

function matchField(
  expr: string,
  value: number,
  min: number,
  max: number,
): boolean {
  const part = expr.trim()
  if (part === '*') return true

  if (part.startsWith('*/')) {
    const step = Number(part.slice(2))
    if (!Number.isInteger(step) || step < 1) return false
    return (value - min) % step === 0
  }

  if (part.includes('-')) {
    const [a, b] = part.split('-').map(Number)
    if (!Number.isInteger(a) || !Number.isInteger(b)) return false
    if (a < min || b > max || a > b) return false
    return value >= a && value <= b
  }

  const n = Number(part)
  if (!Number.isInteger(n) || n < min || n > max) return false
  return value === n
}

/** Validate standard 5-field cron (no lists/names). */
export function isValidScrapeCron(expr: string): boolean {
  const parts = expr.trim().split(/\s+/)
  if (parts.length !== 5) return false
  const [min, hour, dom, mon, dow] = parts
  return (
    FIELD_RE.test(min) &&
    HOUR_RE.test(hour) &&
    DOM_RE.test(dom) &&
    MON_RE.test(mon) &&
    DOW_RE.test(dow)
  )
}

/** True if `at` (UTC) matches the 5-field expression. */
export function cronMatchesUtc(expr: string, at: Date = new Date()): boolean {
  if (!isValidScrapeCron(expr)) return false
  const [min, hour, dom, mon, dow] = expr.trim().split(/\s+/)
  return (
    matchField(min, at.getUTCMinutes(), 0, 59) &&
    matchField(hour, at.getUTCHours(), 0, 23) &&
    matchField(dom, at.getUTCDate(), 1, 31) &&
    matchField(mon, at.getUTCMonth() + 1, 1, 12) &&
    matchField(dow, at.getUTCDay(), 0, 6)
  )
}

export function dailyCronFromUtc(hour: number, minute: number): string {
  const h = Math.min(23, Math.max(0, Math.floor(hour)))
  const m = Math.min(59, Math.max(0, Math.floor(minute)))
  return `${m} ${h} * * *`
}

export function parseDailyUtc(
  expr: string,
): { hour: number; minute: number } | null {
  const parts = expr.trim().split(/\s+/)
  if (parts.length !== 5) return null
  const [min, hour, dom, mon, dow] = parts
  if (dom !== '*' || mon !== '*' || dow !== '*') return null
  if (!/^\d+$/.test(min) || !/^\d+$/.test(hour)) return null
  const minute = Number(min)
  const h = Number(hour)
  if (minute < 0 || minute > 59 || h < 0 || h > 23) return null
  return { hour: h, minute }
}

/** Short human label for common patterns; else raw cron. */
export function humanizeScrapeCron(expr: string): string {
  const trimmed = expr.trim()
  if (!isValidScrapeCron(trimmed)) return 'Invalid cron'
  const preset = SCRAPE_CRON_PRESETS.find((p) => p.cron === trimmed)
  if (preset) return preset.label

  const daily = parseDailyUtc(trimmed)
  if (daily) {
    const hh = String(daily.hour).padStart(2, '0')
    const mm = String(daily.minute).padStart(2, '0')
    return `Every day at ${hh}:${mm} UTC`
  }

  const parts = trimmed.split(/\s+/)
  if (parts[0] === '0' && parts[1].startsWith('*/') && parts.slice(2).every((p) => p === '*')) {
    const step = parts[1].slice(2)
    return `Every ${step} hours`
  }
  if (
    parts[0] === '0' &&
    parts[1] === '*' &&
    parts.slice(2).every((p) => p === '*')
  ) {
    return 'Every hour'
  }

  return `Cron ${trimmed} (UTC)`
}
