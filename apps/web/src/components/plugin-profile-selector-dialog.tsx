import { useEffect, useMemo, useRef, useState } from 'react'
import { Check, Loader2, Users, X } from 'lucide-react'
import { useQueryClient } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { LiquidGlass } from '@/components/liquid-glass'
import { ProfileAvatar } from '@/components/profile-avatar'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import type { ForjaPackRow } from '@/lib/sync-domains'
import {
  applyPackProfileMembership,
  fetchPackProfileMembership,
} from '@/lib/forja-plugin-profile-membership'
import { cn } from '@/lib/utils'

type PluginProfileSelectorDialogProps = {
  open: boolean
  pack: ForjaPackRow | null
  onClose: () => void
  onSaved?: () => void
}

export function PluginProfileSelectorDialog({
  open,
  pack,
  onClose,
  onSaved,
}: PluginProfileSelectorDialogProps) {
  const panelRef = useRef<HTMLDivElement>(null)
  const { user } = useAuth()
  const { profiles, activeProfile } = useProfiles()
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState<Set<string>>(() => new Set())
  const [initial, setInitial] = useState<Set<string>>(() => new Set())
  const [loading, setLoading] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const title = useMemo(() => {
    if (!pack) return 'Plugin pack'
    const name = pack.name?.trim()
    if (name && name !== pack.manifestUrl) return name
    return 'Plugin pack'
  }, [pack])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !busy) onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, busy, onClose])

  useEffect(() => {
    if (!open) return
    panelRef.current?.focus()
  }, [open])

  useEffect(() => {
    if (!open || !pack || !user?.id || profiles.length === 0) return
    let cancelled = false
    setLoading(true)
    setError(null)
    void fetchPackProfileMembership({
      accountId: user.id,
      profileIds: profiles.map((p) => p.id),
      manifestUrl: pack.manifestUrl,
    })
      .then((map) => {
        if (cancelled) return
        const next = new Set<string>()
        for (const [id, installed] of map) {
          if (installed) next.add(id)
        }
        setSelected(next)
        setInitial(new Set(next))
      })
      .catch((err: unknown) => {
        if (cancelled) return
        setError(err instanceof Error ? err.message : 'Could not load profiles.')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [open, pack, user?.id, profiles])

  const dirty = useMemo(() => {
    if (selected.size !== initial.size) return true
    for (const id of selected) {
      if (!initial.has(id)) return true
    }
    return false
  }, [selected, initial])

  function toggle(profileId: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(profileId)) next.delete(profileId)
      else next.add(profileId)
      return next
    })
  }

  async function handleSave() {
    if (!pack || !user?.id || busy || !dirty) return
    setBusy(true)
    setError(null)
    try {
      await applyPackProfileMembership({
        accountId: user.id,
        userId: user.id,
        pack,
        selectedIds: selected,
        allProfileIds: profiles.map((p) => p.id),
      })
      await queryClient.invalidateQueries({
        queryKey: ['profile_settings', user.id],
      })
      onSaved?.()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Could not save.')
    } finally {
      setBusy(false)
    }
  }

  if (!open || !pack) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center"
      role="presentation"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/65 backdrop-blur-sm"
        aria-label="Dismiss"
        disabled={busy}
        onClick={() => {
          if (!busy) onClose()
        }}
      />
      <div
        ref={panelRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="plugin-profile-selector-title"
        className="relative flex max-h-[min(90vh,560px)] w-full max-w-md flex-col outline-none"
      >
        <LiquidGlass className="flex max-h-[inherit] flex-col border-white/15 p-0 shadow-2xl">
          <div className="flex items-start justify-between gap-3 border-b border-white/10 px-5 py-4">
            <div className="flex min-w-0 items-start gap-3">
              <div className="flex size-9 shrink-0 items-center justify-center rounded-lg border border-forja-green/25 bg-forja-green/10 text-forja-green">
                <Users className="size-4" aria-hidden />
              </div>
              <div className="min-w-0">
                <p className="font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)]">
                  Profiles
                </p>
                <h2
                  id="plugin-profile-selector-title"
                  className="truncate font-medium text-[#EDE6DA]"
                >
                  {title}
                </h2>
                <p className="mt-1 text-xs text-[rgba(237,230,218,0.5)]">
                  Select which profiles get this pack. Devices sync membership
                  and install or remove scripts after.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={onClose}
              disabled={busy}
              className="flex size-8 shrink-0 items-center justify-center rounded-lg text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-[#EDE6DA] disabled:opacity-50"
              aria-label="Close"
            >
              <X className="size-4" />
            </button>
          </div>

          <div className="min-h-0 flex-1 overflow-y-auto px-3 py-3">
            {loading ? (
              <div className="flex items-center justify-center gap-2 py-10 text-sm text-[rgba(237,230,218,0.5)]">
                <Loader2 className="size-4 animate-spin" />
                Loading profiles…
              </div>
            ) : profiles.length === 0 ? (
              <p className="px-2 py-8 text-center text-sm text-[rgba(237,230,218,0.55)]">
                Create a profile first.
              </p>
            ) : (
              <ul className="space-y-1">
                {profiles.map((profile) => {
                  const on = selected.has(profile.id)
                  const isActive = profile.id === activeProfile?.id
                  return (
                    <li key={profile.id}>
                      <button
                        type="button"
                        onClick={() => toggle(profile.id)}
                        disabled={busy}
                        className={cn(
                          'flex w-full cursor-pointer items-center gap-3 rounded-xl px-2.5 py-2.5 text-left transition',
                          on
                            ? 'bg-forja-green/10 text-[#EDE6DA]'
                            : 'text-[#EDE6DA] hover:bg-white/6',
                          busy && 'pointer-events-none opacity-60',
                        )}
                      >
                        <ProfileAvatar
                          avatarKey={profile.avatar_key}
                          name={profile.name}
                          className="size-11 shrink-0 rounded-xl ring-1 ring-white/10"
                        />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate font-disp text-base uppercase tracking-tight">
                            {profile.name}
                          </span>
                          <span className="mt-0.5 block text-[11px] text-forja-muted">
                            {on
                              ? isActive
                                ? 'On this profile · active'
                                : 'On this profile'
                              : 'Not on this profile'}
                          </span>
                        </span>
                        <span
                          className={cn(
                            'flex size-5 shrink-0 items-center justify-center rounded border',
                            on
                              ? 'border-forja-green bg-forja-green text-[#0B0A0A]'
                              : 'border-white/20 bg-transparent',
                          )}
                          aria-hidden
                        >
                          {on ? <Check className="size-3.5 stroke-3" /> : null}
                        </span>
                      </button>
                    </li>
                  )
                })}
              </ul>
            )}
          </div>

          {error ? (
            <p className="border-t border-white/10 px-5 py-2 text-xs text-red-400">
              {error}
            </p>
          ) : null}

          <div className="flex flex-col-reverse gap-2 border-t border-white/10 px-5 py-4 sm:flex-row sm:justify-end">
            <Button
              type="button"
              variant="ghost"
              className="text-[rgba(237,230,218,0.65)]"
              onClick={onClose}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              type="button"
              className="bg-forja-green text-[#0B0A0A] hover:bg-forja-green/90"
              onClick={() => void handleSave()}
              disabled={busy || loading || !dirty || profiles.length === 0}
            >
              {busy ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  Saving…
                </>
              ) : (
                'Save'
              )}
            </Button>
          </div>
        </LiquidGlass>
      </div>
    </div>
  )
}
