import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from 'react'

/**
 * Local editable draft hydrated from a server row.
 *
 * Hydrates only when `profileId` or `updatedAt` changes — never on every
 * render / loading flicker. That prevents toggles and fields from snapping
 * back while the user is editing.
 */
export function useServerDraft<T>(
  profileId: string | null,
  updatedAt: string | null | undefined,
  isReady: boolean,
  serverValue: unknown,
  mapServer: (value: unknown) => T,
  makeEmpty: () => T,
): [T, Dispatch<SetStateAction<T>>] {
  const [draft, setDraft] = useState(makeEmpty)
  const mapRef = useRef(mapServer)
  const emptyRef = useRef(makeEmpty)
  mapRef.current = mapServer
  emptyRef.current = makeEmpty
  const hydratedKeyRef = useRef<string | null>(null)

  useEffect(() => {
    hydratedKeyRef.current = null
    setDraft(emptyRef.current())
  }, [profileId])

  useEffect(() => {
    if (!profileId || !isReady) return
    const key = `${profileId}:${updatedAt ?? 'null'}`
    if (hydratedKeyRef.current === key) return
    hydratedKeyRef.current = key
    setDraft(mapRef.current(serverValue))
  }, [profileId, isReady, updatedAt, serverValue])

  return [draft, setDraft]
}
