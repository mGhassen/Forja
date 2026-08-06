import { useEffect, useMemo, useState } from 'react'

export function useTablePagination<T>(
  rows: T[],
  opts?: {
    initialPageSize?: number
    /** Reset to page 0 when any of these change (filters, sort, …). */
    resetKey?: unknown
  },
) {
  const initialPageSize = opts?.initialPageSize ?? 50
  const [page, setPage] = useState(0)
  const [pageSize, setPageSize] = useState(initialPageSize)

  useEffect(() => {
    setPage(0)
  }, [opts?.resetKey, pageSize])

  const total = rows.length
  const pageCount = Math.max(1, Math.ceil(total / pageSize) || 1)
  const safePage = Math.min(Math.max(0, page), pageCount - 1)
  const startIndex = safePage * pageSize
  const pageRows = useMemo(
    () => rows.slice(startIndex, startIndex + pageSize),
    [rows, startIndex, pageSize],
  )

  return {
    page: safePage,
    pageSize,
    setPage,
    setPageSize,
    pageRows,
    total,
    startIndex,
  }
}
