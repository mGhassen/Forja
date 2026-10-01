import { useEffect, useRef, useState, type Dispatch, type SetStateAction } from 'react'

/**
 * Local editable draft hydrated from a server row.
 *
 * Hydrates when `profileId`, `updatedAt`, or the `serverValue` reference /
 * JSON content changes (fresh fetch). Skips same-key + same content so parent
 * re-renders do not wipe mid-edit toggles.
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
  const appliedContentRef = useRef<string | null>(null)

  useEffect(() => {
    hydratedKeyRef.current = null
    appliedServerRef.current = undefined
    appliedContentRef.current = null
    setDraft(emptyRef.current())
  }, [profileId])

  useEffect(() => {
    if (!profileId || !isReady) return
    if (hydratePaused) return
    const key = `${profileId}:${updatedAt ?? 'null'}`
    let content: string
    try {
      content = JSON.stringify(serverValue ?? null)
    } catch {
      content = String(serverValue)
    }
    if (
      hydratedKeyRef.current === key &&
      (Object.is(appliedServerRef.current, serverValue) ||
        appliedContentRef.current === content)
    ) {
      return
    }
    hydratedKeyRef.current = key
    appliedServerRef.current = serverValue
    appliedContentRef.current = content
    setDraft(mapRef.current(serverValue))
  }, [profileId, isReady, updatedAt, serverValue, hydratePaused])

  return [draft, setDraft]
}
