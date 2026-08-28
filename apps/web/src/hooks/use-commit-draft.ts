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
 * Server draft that saves immediately on [commit] — no "Save changes" button.
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
  commit: (updater: SetStateAction<TDraft>) => Promise<void>
  controlsLocked: boolean
  isSaving: boolean
  savedFlash: boolean
  saveError: Error | null
} {
  const [draft, setDraft] = useServerDraft(
    profileId,
    updatedAt,
    isReady,
    serverValue,
    mapServer,
    makeEmpty,
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

  const commit = useCallback(async (updater: SetStateAction<TDraft>) => {
    const prev = draftRef.current
    const next =
      typeof updater === 'function'
        ? (updater as (p: TDraft) => TDraft)(prev)
        : updater
    if (Object.is(next, prev)) return
    draftRef.current = next
    setDraft(next)
    setIsSaving(true)
    setSaveError(null)
    try {
      const map = toPayloadRef.current
      const payload = (map ? map(next) : next) as TPayload
      await saveRef.current(payload)
      setSavedFlash(true)
      if (flashTimer.current != null) window.clearTimeout(flashTimer.current)
      flashTimer.current = window.setTimeout(() => setSavedFlash(false), 2000)
    } catch (e) {
      draftRef.current = prev
      setDraft(prev)
      setSaveError(e instanceof Error ? e : new Error('Save failed'))
    } finally {
      setIsSaving(false)
    }
  }, [setDraft])

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
