import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from 'react'

/**
 * Local editable draft hydrated from a server row.
 *
 * Hydrates when `profileId`, `updatedAt`, or the `serverValue` reference
 * changes (fresh fetch). Skips same-key + same-reference so parent re-renders
 * do not wipe mid-edit toggles.
 *
 * [hydratePaused] skips soft-pull remounts while a local commit is in flight.
 */
export function useServerDraft<T>(
  profileId: string | null,
  updatedAt: string | null | undefined,
  isReady: boolean,
  serverValue: unknown,
  mapServer: (value: unknown) => T,
  makeEmpty: () => T,
  hydratePaused = false,
): [T, Dispatch<SetStateAction<T>>] {
  const [draft, setDraft] = useState(makeEmpty)
  const mapRef = useRef(mapServer)
  const emptyRef = useRef(makeEmpty)
  mapRef.current = mapServer
  emptyRef.current = makeEmpty
  const hydratedKeyRef = useRef<string | null>(null)
  const appliedServerRef = useRef<unknown>(undefined)

  useEffect(() => {
    hydratedKeyRef.current = null
    appliedServerRef.current = undefined
    setDraft(emptyRef.current())
  }, [profileId])

  useEffect(() => {
    if (!profileId || !isReady) return
    if (hydratePaused) return
    const key = `${profileId}:${updatedAt ?? 'null'}`
    if (
      hydratedKeyRef.current === key &&
      Object.is(appliedServerRef.current, serverValue)
    ) {
      return
    }
    hydratedKeyRef.current = key
    appliedServerRef.current = serverValue
    setDraft(mapRef.current(serverValue))
  }, [profileId, isReady, updatedAt, serverValue, hydratePaused])

  return [draft, setDraft]
}
