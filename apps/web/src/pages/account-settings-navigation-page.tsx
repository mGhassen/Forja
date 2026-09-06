import { useEffect, useMemo } from 'react'
import { ChevronDown, ChevronUp, Lock, Star } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import {
  useForjaSetting,
  useNavigationSetting,
  usePlaybackSetting,
} from '@/hooks/use-user-setting'
import {
  availableFeatureTabIds,
  DEFAULT_NAV_TAB,
  emptyForjaPayload,
  emptyPreferencesPayload,
  navTabLabel,
  normalizeNavigationPayload,
  pruneNavigationToAvailable,
  type ForjaPayload,
  type NavigationPayload,
  type PreferencesPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

type NavDraft = {
  order: string[]
  visible: Set<string>
  defaultTab: string
}

function labelFor(id: string): string {
  return navTabLabel(id)
}

function emptyNavDraft(): NavDraft {
  return {
    order: [],
    visible: new Set(),
    defaultTab: DEFAULT_NAV_TAB,
  }
}

/** Inventory from cloud slices — never empty playDraft on first hydrate. */
function availableFromServer(
  playbackPayloadValue: unknown,
  forjaPayloadValue: unknown,
): string[] {
  const play = playbackPayloadValue as PreferencesPayload | undefined
  const packs =
    (forjaPayloadValue as ForjaPayload | undefined)?.packs ?? []
  return availableFeatureTabIds({
    addonFeatureIptv: play?.addon_feature_iptv,
    addonFeatureLiveMatches: play?.addon_feature_live_matches,
    packs,
  })
}

function navDraftFromServer(value: unknown): NavDraft {
  // Do not prune against inventory here — drafts are empty on the first effect
  // tick and would strip Addons/pack-enabled tabs (issue 224).
  const n = normalizeNavigationPayload(value as NavigationPayload | undefined)
  return {
    order: n.tabOrder,
    visible: new Set(n.visibleIds),
    defaultTab: n.defaultTab,
  }
}

export function AccountSettingsNavigationPage() {
  const navigation = useNavigationSetting()
  const playback = usePlaybackSetting()
  const forja = useForjaSetting()

  const playDraft = useCommitDraft({
    profileId: playback.profileId,
    updatedAt: playback.data?.updated_at,
    isReady: Boolean(playback.data) && !playback.isLoading,
    serverValue: playback.data?.payload,
    mapServer: (value: unknown) => ({
      ...emptyPreferencesPayload(),
      ...((value as PreferencesPayload | undefined) ?? {}),
    }),
    makeEmpty: emptyPreferencesPayload,
    save: playback.save,
  })

  const packsDraft = useCommitDraft({
    profileId: forja.profileId,
    updatedAt: forja.data?.updated_at,
    isReady: Boolean(forja.data) && !forja.isLoading,
    serverValue: forja.data?.payload,
    mapServer: (value: unknown) => ({
      packs: (value as ForjaPayload | undefined)?.packs ?? [],
      onboarded: (value as ForjaPayload | undefined)?.onboarded,
    }),
    makeEmpty: emptyForjaPayload,
    save: forja.save,
  })

  // Cloud playback/packs first — drafts start empty until effects run.
  const availableIds = useMemo(
    () =>
      availableFromServer(
        playback.data?.payload ?? playDraft.draft,
        forja.data?.payload ?? { packs: packsDraft.draft.packs },
      ),
    [
      playback.data?.payload,
      forja.data?.payload,
      playDraft.draft,
      packsDraft.draft.packs,
    ],
  )

  const {
    draft,
    commit,
    controlsLocked,
    isSaving,
    savedFlash,
    saveError,
  } = useCommitDraft({
    profileId: navigation.profileId,
    updatedAt: navigation.data?.updated_at,
    isReady: Boolean(navigation.data) && !navigation.isLoading,
    serverValue: navigation.data?.payload,
    mapServer: navDraftFromServer,
    makeEmpty: emptyNavDraft,
    save: navigation.save,
    toPayload: (d) =>
      pruneNavigationToAvailable(
        {
          visibleIds: d.order.filter((id) => d.visible.has(id)),
          tabOrder: d.order,
          defaultTab: d.defaultTab,
        },
        availableIds,
      ),
  })

  // Pack / Addons unlock can land while Features is open (or hydrate before
  // inventory is known). Default-on any available id not yet in draft order
  // and persist so the app rail matches.
  useEffect(() => {
    void commit((prev) => {
      const stillMissing = availableIds.filter((id) => !prev.order.includes(id))
      if (stillMissing.length === 0) return prev
      const visible = new Set(prev.visible)
      for (const id of stillMissing) visible.add(id)
      return {
        ...prev,
        order: [...prev.order, ...stillMissing],
        visible,
      }
    })
  }, [availableIds, commit])

  /** Derived inventory ordered by draft.order, then any new available ids. */
  const featureOrder = useMemo(() => {
    const available = new Set(availableIds)
    const ordered = draft.order.filter((id) => available.has(id))
    for (const id of availableIds) {
      if (!ordered.includes(id)) ordered.push(id)
    }
    return ordered
  }, [draft.order, availableIds])

  const startupOptions = useMemo(() => {
    const opts = featureOrder.filter((id) => draft.visible.has(id))
    if (!opts.includes('settings')) opts.push('settings')
    return opts
  }, [featureOrder, draft.visible])

  const move = (index: number, dir: -1 | 1) => {
    const id = featureOrder[index]
    if (!id) return
    void commit((prev) => {
      const full = [...featureOrder]
      const target = index + dir
      if (target < 0 || target >= full.length) return prev
      ;[full[index], full[target]] = [full[target]!, full[index]!]
      return { ...prev, order: full }
    })
  }

  const setVisible = (id: string, on: boolean) => {
    void commit((prev) => {
      const visible = new Set(prev.visible)
      if (on) visible.add(id)
      else visible.delete(id)
      let defaultTab = prev.defaultTab
      if (!on && defaultTab === id && defaultTab !== 'settings') {
        const still = featureOrder.filter((x) => visible.has(x))
        defaultTab = still[0] ?? 'settings'
      }
      return { ...prev, visible, defaultTab }
    })
  }

  const locked = controlsLocked || isSaving

  return (
    <AccountSettingsShell
      title="Features"
      description="Show, hide, and reorder shell tabs for this profile. Settings stays visible. Unlock IPTV / Live Sports under Addons; hub tabs appear when their Forja Packs are on this profile."
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
        description="Star sets the default tab after launch or profile switch. Only unlocked Addons and installed hub packs are listed."
      >
        <ul className="divide-y divide-forja-border/60">
          {featureOrder.length === 0 ? (
            <li className="px-0.5 py-4 text-sm text-forja-muted">
              No feature tabs yet. Turn on Addons or install hub packs.
            </li>
          ) : null}
          {featureOrder.map((id, index) => {
            const on = draft.visible.has(id)
            const isDefault = draft.defaultTab === id
            return (
              <li
                key={id}
                className="flex min-h-14.5 items-center gap-3 px-0.5 py-2"
              >
                <div className="flex shrink-0 flex-col gap-0.5">
                  <button
                    type="button"
                    aria-label={`Move ${labelFor(id)} up`}
                    disabled={locked || index === 0}
                    onClick={() => move(index, -1)}
                    className="text-forja-muted hover:text-forja-text disabled:opacity-30"
                  >
                    <ChevronUp className="size-4" />
                  </button>
                  <button
                    type="button"
                    aria-label={`Move ${labelFor(id)} down`}
                    disabled={locked || index === featureOrder.length - 1}
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
                  disabled={locked || !on}
                  onClick={() =>
                    void commit((prev) => ({ ...prev, defaultTab: id }))
                  }
                  className={cn(
                    'shrink-0 disabled:opacity-30',
                    isDefault
                      ? 'text-forja-green'
                      : 'text-forja-muted hover:text-forja-text',
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
                  disabled={locked}
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
          <li className="flex min-h-14.5 items-center gap-3 px-0.5 py-2">
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
              disabled={locked}
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
                fill={
                  draft.defaultTab === 'settings' ? 'currentColor' : 'none'
                }
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
        <div className="flex min-h-14.5 items-center justify-between gap-5 px-0.5 py-3">
          <span className="text-sm font-medium">
            Opens after sync / profile switch
          </span>
          <select
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={
              startupOptions.includes(draft.defaultTab)
                ? draft.defaultTab
                : (startupOptions[0] ?? DEFAULT_NAV_TAB)
            }
            disabled={locked}
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
