import { useMemo } from 'react'
import { ChevronDown, ChevronUp, Lock, Star } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useNavigationSetting } from '@/hooks/use-user-setting'
import {
  DEFAULT_NAV_TAB,
  DEFAULT_NAV_VISIBLE_IDS,
  SYNCABLE_NAV_TABS,
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

function navigationFromServer(value: unknown): NavDraft {
  return draftFromPayload(value as NavigationPayload | undefined)
}

function emptyNavDraft(): NavDraft {
  return {
    order: [...DEFAULT_NAV_VISIBLE_IDS],
    visible: new Set(),
    defaultTab: DEFAULT_NAV_TAB,
  }
}

export function AccountSettingsNavigationPage() {
  const { data, profileId, isLoading, save } = useNavigationSetting()
  const {
    draft,
    commit,
    controlsLocked,
    isSaving,
    savedFlash,
    saveError,
  } = useCommitDraft({
    profileId,
    updatedAt: data?.updated_at,
    isReady: Boolean(data) && !isLoading,
    serverValue: data?.payload,
    mapServer: navigationFromServer,
    makeEmpty: emptyNavDraft,
    save,
    toPayload: payloadFromDraft,
  })

  const startupOptions = useMemo(() => {
    const opts = draft.order.filter((id) => draft.visible.has(id))
    if (!opts.includes('settings')) opts.push('settings')
    return opts
  }, [draft.order, draft.visible])

  const move = (index: number, dir: -1 | 1) => {
    void commit((prev) => {
      const next = [...prev.order]
      const target = index + dir
      if (target < 0 || target >= next.length) return prev
      ;[next[index], next[target]] = [next[target], next[index]]
      return { ...prev, order: next }
    })
  }

  const setVisible = (id: string, on: boolean) => {
    void commit((prev) => {
      const visible = new Set(prev.visible)
      if (on) visible.add(id)
      else visible.delete(id)
      let defaultTab = prev.defaultTab
      if (!on && defaultTab === id && defaultTab !== 'settings') {
        const still = prev.order.filter((x) => visible.has(x))
        defaultTab = still.includes(DEFAULT_NAV_TAB)
          ? DEFAULT_NAV_TAB
          : (still[0] ?? 'settings')
      }
      return { ...prev, visible, defaultTab }
    })
  }

  return (
    <AccountSettingsShell
      title="Features"
      description="Show, hide, and reorder shell tabs for this profile. Settings stays visible. Matches Settings → Features in the app."
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={saveError}
        />
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
                    disabled={controlsLocked || isSaving || index === 0}
                    onClick={() => move(index, -1)}
                    className="text-forja-muted hover:text-forja-text disabled:opacity-30"
                  >
                    <ChevronUp className="size-4" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Move ${labelFor(id)} down`}
                    disabled={
                      controlsLocked ||
                      isSaving ||
                      index === draft.order.length - 1
                    }
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
                  disabled={controlsLocked || isSaving || !on}
                  onClick={() =>
                    void commit((prev) => ({ ...prev, defaultTab: id }))
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
                <button
                  type="button"
                  role="switch"
                  aria-checked={on}
                  aria-label={`Show ${labelFor(id)}`}
                  disabled={controlsLocked || isSaving}
                  onClick={() => setVisible(id, !on)}
                  className={cn(
                    'group relative h-6 w-11 shrink-0 appearance-none rounded-full border-0 p-0 transition-colors active:scale-100 active:filter-none disabled:cursor-not-allowed disabled:opacity-60',
                    on ? 'bg-forja-green' : 'bg-white/15',
                  )}
                >
                  <span
                    className={cn(
                      'pointer-events-none absolute top-1 left-1 size-4 rounded-full bg-forja-bg transition-[transform,background-color] group-hover:bg-neutral-600',
                      on ? 'translate-x-5' : 'translate-x-0',
                    )}
                  />
                </button>
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
              disabled={controlsLocked || isSaving}
              onClick={() =>
                void commit((prev) => ({ ...prev, defaultTab: 'settings' }))
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
            disabled={controlsLocked || isSaving}
            onChange={(e) =>
              void commit((prev) => ({ ...prev, defaultTab: e.target.value }))
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
