/**
 * PostgREST / Supabase caps a single response (default max_rows = 1000).
 * `.limit(N)` with N > max still returns at most max — page with `.range`.
 */
export async function fetchAllRows<T>(
  fetchPage: (from: number, to: number) => Promise<T[]>,
  pageSize = 1000,
): Promise<T[]> {
  const size = Math.max(1, Math.min(pageSize, 1000))
  const out: T[] = []
  let from = 0
  for (;;) {
    const rows = await fetchPage(from, from + size - 1)
    out.push(...rows)
    if (rows.length < size) break
    from += size
  }
  return out
}
