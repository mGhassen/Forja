/** Admin portal expiry — always `dd/mm/yyyy` (never US `mm/dd/yyyy`). */
const MONTH_INDEX: Record<string, number> = {
  jan: 0,
  january: 0,
  feb: 1,
  february: 1,
  mar: 2,
  march: 2,
  apr: 3,
  april: 3,
  may: 4,
  jun: 5,
  june: 5,
  jul: 6,
  july: 6,
  aug: 7,
  august: 7,
  sep: 8,
  september: 8,
  oct: 9,
  october: 9,
  nov: 10,
  november: 10,
  dec: 11,
  december: 11,
}

function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

/** Format a Date as `dd/mm/yyyy`. */
export function formatAdminDate(d: Date): string {
  return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()}`
}

/** Format a Date / ISO string as `dd/mm/yyyy, HH:mm` (24h, en-GB order). */
export function formatAdminDateTime(raw?: string | Date | null): string {
  if (raw == null || raw === '') return ''
  const d = raw instanceof Date ? raw : new Date(raw)
  if (Number.isNaN(d.getTime())) return String(raw)
  return `${formatAdminDate(d)}, ${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}

export function parsePortalExpiry(raw?: string | null): Date | null {
  const s = (raw ?? '').trim()
  if (!s || s.toLowerCase() === 'unknown') return null

  if (/^\d+$/.test(s)) {
    const n = Number(s)
    // Xtream `exp_date` is unix seconds; treat large values as millis.
    const ms = n > 1e12 ? n : n * 1000
    const d = new Date(ms)
    if (Number.isNaN(d.getTime()) || d.getFullYear() <= 1970) return null
    return d
  }

  // Always treat numeric slash dates as DD/MM/YYYY (not US MM/DD).
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

  // ISO `2027-02-16` / `2027-02-16T…`
  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(s)
  if (iso) {
    const year = Number(iso[1])
    const month = Number(iso[2]) - 1
    const day = Number(iso[3])
    if (year > 1970 && month >= 0 && month <= 11 && day >= 1 && day <= 31) {
      return new Date(year, month, day)
    }
  }

  // `16 Feb 2027` / `16 February 2027` (legacy stored format)
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

  // `February 16, 2027` / `Feb 16 2027`
  const eng = /^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})/.exec(s)
  if (eng) {
    const month = MONTH_INDEX[eng[1].toLowerCase()]
    const day = Number(eng[2])
    const year = Number(eng[3])
    if (
      month != null &&
      Number.isInteger(day) &&
      Number.isInteger(year) &&
      year > 1970 &&
      day >= 1 &&
      day <= 31
    ) {
      return new Date(year, month, day)
    }
  }

  // Do not use `new Date(s)` — V8 parses ambiguous slash dates as US MM/DD.
  return null
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
  return formatAdminDate(d)
}
