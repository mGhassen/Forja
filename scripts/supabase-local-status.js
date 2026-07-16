/**
 * Parse `supabase status -o json` output.
 * CLI may print warnings before JSON and upgrade notices after the closing `}`.
 */

const { execSync } = require('child_process')

function extractJsonObject(text) {
  const start = text.indexOf('{')
  if (start < 0) return null
  const end = text.lastIndexOf('}')
  if (end < start) return null
  try {
    return JSON.parse(text.slice(start, end + 1))
  } catch {
    return null
  }
}

/**
 * @param {string} cwd - Supabase project directory (apps/web)
 * @returns {{ status: Record<string, string> | null, stopped: string[], raw: string }}
 */
function runSupabaseStatus(cwd) {
  try {
    const raw = execSync('supabase status -o json 2>&1', {
      stdio: 'pipe',
      cwd,
      encoding: 'utf8',
    })
    const stoppedMatch = raw.match(/Stopped services: \[(.*?)\]/)
    const stopped = stoppedMatch
      ? stoppedMatch[1]
          .split(/\s+/)
          .map((name) => name.trim())
          .filter(Boolean)
      : []
    const status = extractJsonObject(raw)
    return { status, stopped, raw }
  } catch {
    return { status: null, stopped: [], raw: '' }
  }
}

module.exports = { extractJsonObject, runSupabaseStatus }
