import {
  useCallback,
  useRef,
  useState,
  type Dispatch,
  type SetStateAction,
} from 'react'
import { useServerDraft } from '@/hooks/use-server-draft'

type CommitDraftOptions<TDraft, TPayload> = {
  profileId: string | null
  updatedAt: string | null | undefined
  isReady: boolean
  serverValue: unknown
  mapServer: (value: unknown) => TDraft
  makeEmpty: () => TDraft
  save: (payload: TPayload) => Promise<unknown>
  /** Map draft → API payload. Defaults to identity. */
  toPayload?: (draft: TDraft) => TPayload
}

/**
 * Optimistic draft: UI updates immediately; upsert runs async on a serial queue.
 * Soft-pull hydrate is paused while saves are in flight.
 */
export function useCommitDraft<TDraft, TPayload = TDraft>({
  profileId,
  updatedAt,
  isReady,
  serverValue,
  mapServer,
  makeEmpty,
  save,
  toPayload,
}: CommitDraftOptions<TDraft, TPayload>): {
  draft: TDraft
  /** Local-only update (e.g. mid-fetch UI). Prefer [commit] for user edits. */
  setDraft: Dispatch<SetStateAction<TDraft>>
  /** Optimistic apply + background save. Resolves when this edit's upsert finishes. */
  commit: (updater: SetStateAction<TDraft>) => Promise<void>
  controlsLocked: boolean
  isSaving: boolean
  savedFlash: boolean
  saveError: Error | null
} {
  const pendingSaves = useRef(0)
  const [hydratePaused, setHydratePaused] = useState(false)
  const [draft, setDraft] = useServerDraft(
    profileId,
    updatedAt,
    isReady,
    serverValue,
    mapServer,
    makeEmpty,
    hydratePaused,
  )
  const draftRef = useRef(draft)
  draftRef.current = draft
  const [isSaving, setIsSaving] = useState(false)
  const [savedFlash, setSavedFlash] = useState(false)
  const [saveError, setSaveError] = useState<Error | null>(null)
  const flashTimer = useRef<number | null>(null)
  const toPayloadRef = useRef(toPayload)
  toPayloadRef.current = toPayload
  const saveRef = useRef(save)
  saveRef.current = save
  const saveChain = useRef(Promise.resolve<void>(undefined))

  const commit = useCallback(
    async (updater: SetStateAction<TDraft>) => {
      const prev = draftRef.current
      const next =
        typeof updater === 'function'
          ? (updater as (p: TDraft) => TDraft)(prev)
          : updater
      if (Object.is(next, prev)) return

      // Optimistic UI — do not wait for network before returning control.
      draftRef.current = next
      setDraft(next)
      pendingSaves.current += 1
      setHydratePaused(true)
      setIsSaving(true)
      setSaveError(null)

      const map = toPayloadRef.current
      const payload = (map ? map(next) : next) as TPayload

      const run = saveChain.current.then(async () => {
        try {
          await saveRef.current(payload)
          setSavedFlash(true)
          if (flashTimer.current != null) window.clearTimeout(flashTimer.current)
          flashTimer.current = window.setTimeout(() => setSavedFlash(false), 2000)
        } catch (e) {
          // Only revert if nothing newer was committed on top.
          if (Object.is(draftRef.current, next)) {
            draftRef.current = prev
            setDraft(prev)
          }
          setSaveError(e instanceof Error ? e : new Error('Save failed'))
          throw e
        } finally {
          pendingSaves.current = Math.max(0, pendingSaves.current - 1)
          if (pendingSaves.current === 0) {
            setHydratePaused(false)
            setIsSaving(false)
          }
        }
      })
      saveChain.current = run.then(
        () => undefined,
        () => undefined,
      )
      await run
    },
    [setDraft],
  )

  return {
    draft,
    setDraft,
    commit,
    controlsLocked: !profileId || !isReady,
    isSaving,
    savedFlash,
    saveError,
  }
}
