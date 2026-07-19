import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Lock, Star } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { useNavigationSetting } from '@/hooks/use-user-setting'
import {
  DEFAULT_NAV_TAB,
  DEFAULT_NAV_VISIBLE_IDS,
  SYNCABLE_NAV_TABS,
  emptyNavigationPayload,
  normalizeNavigationPayload,
  type NavigationPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

type NavDraft = {
  /** Full order for UI: visible first (cloud order), then hidden defaults. */
  order: string[]
  visible: Set<string>
  defaultTab: string
}

function labelFor(id: string): string {
  if (id === 'settings') return 'Settings'
  return SYNCABLE_NAV_TABS.find((t) => t.id === id)?.label ?? id
}

function draftFromPayload(payload: NavigationPayload | undefined): NavDraft {
  const n = normalizeNavigationPayload(payload)
  const visible = new Set(n.visibleIds)
  const hidden = DEFAULT_NAV_VISIBLE_IDS.filter((id) => !visible.has(id))
  return {
    order: [...n.visibleIds, ...hidden],
    visible,
    defaultTab: n.defaultTab,
  }
}

function payloadFromDraft(draft: NavDraft): NavigationPayload {
  const visibleIds = draft.order.filter((id) => draft.visible.has(id))
  return normalizeNavigationPayload({
    visibleIds,
    defaultTab: draft.defaultTab,
  })
}

export function AccountSettingsNavigationPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useNavigationSetting()
  const [draft, setDraft] = useState<NavDraft>(() =>
    draftFromPayload(emptyNavigationPayload()),
  )
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(draftFromPayload(emptyNavigationPayload()))
  }, [profileId])

  useEffect(() => {
    if (!profileId || isLoading || !data) {
      setDraft(draftFromPayload(emptyNavigationPayload()))
      return
    }
    setDraft(draftFromPayload(data.payload))
  }, [profileId, isLoading, data])

  const startupOptions = useMemo(() => {
    const opts = draft.order.filter((id) => draft.visible.has(id))
    if (!opts.includes('settings')) opts.push('settings')
    return opts
  }, [draft.order, draft.visible])

  const move = (index: number, dir: -1 | 1) => {
    setDraft((prev) => {
      const next = [...prev.order]
      const target = index + dir
      if (target < 0 || target >= next.length) return prev
      ;[next[index], next[target]] = [next[target], next[index]]
      return { ...prev, order: next }
    })
  }

  const setVisible = (id: string, on: boolean) => {
    setDraft((prev) => {
      const visible = new Set(prev.visible)
      if (on) visible.add(id)
      else visible.delete(id)
      let defaultTab = prev.defaultTab
      if (
        !on &&
        defaultTab === id &&
        defaultTab !== 'settings'
      ) {
        const still = prev.order.filter((x) => visible.has(x))
        defaultTab = still.includes(DEFAULT_NAV_TAB)
          ? DEFAULT_NAV_TAB
          : (still[0] ?? 'settings')
      }
      return { ...prev, visible, defaultTab }
    })
  }

  const handleSave = async () => {
    await save(payloadFromDraft(draft))
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Features"
      description="Show, hide, and reorder shell tabs for this profile. Settings stays visible. Matches Settings → Features in the app."
      footer={
        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={() => void handleSave()} disabled={isLoading || isSaving}>
            {isSaving ? 'Saving…' : 'Save changes'}
          </Button>
          {savedFlash ? (
            <span className="text-sm text-forja-green">Saved - open Forja to sync.</span>
          ) : null}
          {saveError ? (
            <span className="text-sm text-red-300">
              {saveError instanceof Error ? saveError.message : 'Save failed'}
            </span>
          ) : null}
        </div>
      }
    >
      <SettingsSection
        label="Tabs"
        description="Star sets the default tab after launch or profile switch."
      >
        <ul className="divide-y divide-forja-border/60">
          {draft.order.map((id, index) => {
            const on = draft.visible.has(id)
            const isDefault = draft.defaultTab === id
            return (
              <li
                key={id}
                className="flex min-h-[58px] items-center gap-3 px-0.5 py-2"
              >
                <div className="flex shrink-0 flex-col gap-0.5">
                  <button
                    type="button"
                    aria-label={`Move ${labelFor(id)} up`}
                    disabled={isLoading || index === 0}
                    onClick={() => move(index, -1)}
                    className="text-forja-muted hover:text-forja-text disabled:opacity-30"
                  >
                    <ChevronUp className="size-4" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Move ${labelFor(id)} down`}
                    disabled={isLoading || index === draft.order.length - 1}
                    onClick={() => move(index, 1)}
                    className="text-forja-muted hover:text-forja-text disabled:opacity-30"
                  >
                    <ChevronDown className="size-4" />
                  </button>
                </div>
                <span
                  className={cn(
                    'min-w-0 flex-1 text-sm font-medium',
                    on ? 'text-forja-text' : 'text-forja-muted',
                  )}
                >
                  {labelFor(id)}
                </span>
                <button
                  type="button"
                  aria-label={
                    isDefault
                      ? `${labelFor(id)} is default tab`
                      : `Set ${labelFor(id)} as default tab`
                  }
                  disabled={isLoading || !on}
                  onClick={() =>
                    setDraft((prev) => ({ ...prev, defaultTab: id }))
                  }
                  className={cn(
                    'shrink-0 disabled:opacity-30',
                    isDefault ? 'text-forja-green' : 'text-forja-muted hover:text-forja-text',
                  )}
                >
                  <Star
                    className="size-5"
                    fill={isDefault ? 'currentColor' : 'none'}
                  />
                </button>
                <label
                  className={cn(
                    'relative h-6 w-11 shrink-0 cursor-pointer rounded-full transition-colors',
                    on ? 'bg-forja-green' : 'bg-white/15',
                    isLoading ? 'cursor-not-allowed opacity-60' : null,
                  )}
                >
                  <input
                    type="checkbox"
                    className="sr-only"
                    checked={on}
                    disabled={isLoading}
                    onChange={(e) => setVisible(id, e.target.checked)}
                  />
                  <span
                    className={cn(
                      'absolute top-1 size-4 rounded-full bg-forja-bg transition-transform',
                      on ? 'translate-x-6' : 'translate-x-1',
                    )}
                  />
                </label>
              </li>
            )
          })}
          <li className="flex min-h-[58px] items-center gap-3 px-0.5 py-2">
            <span className="w-5 shrink-0" />
            <span className="min-w-0 flex-1 text-sm font-semibold text-forja-green">
              Settings
            </span>
            <button
              type="button"
              aria-label={
                draft.defaultTab === 'settings'
                  ? 'Settings is default tab'
                  : 'Set Settings as default tab'
              }
              disabled={isLoading}
              onClick={() =>
                setDraft((prev) => ({ ...prev, defaultTab: 'settings' }))
              }
              className={cn(
                'shrink-0',
                draft.defaultTab === 'settings'
                  ? 'text-forja-green'
                  : 'text-forja-muted hover:text-forja-text',
              )}
            >
              <Star
                className="size-5"
                fill={draft.defaultTab === 'settings' ? 'currentColor' : 'none'}
              />
            </button>
            <span
              className="flex h-6 w-11 shrink-0 items-center justify-center text-forja-muted"
              title="Always visible"
            >
              <Lock className="size-4" />
            </span>
          </li>
        </ul>
      </SettingsSection>

      <SettingsSection label="Default tab">
        <div className="flex min-h-[58px] items-center justify-between gap-5 px-0.5 py-3">
          <span className="text-sm font-medium">Opens after sync / profile switch</span>
          <select
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={
              startupOptions.includes(draft.defaultTab)
                ? draft.defaultTab
                : (startupOptions[0] ?? DEFAULT_NAV_TAB)
            }
            disabled={isLoading}
            onChange={(e) =>
              setDraft((prev) => ({ ...prev, defaultTab: e.target.value }))
            }
          >
            {startupOptions.map((id) => (
              <option key={id} value={id}>
                {labelFor(id)}
              </option>
            ))}
          </select>
        </div>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
