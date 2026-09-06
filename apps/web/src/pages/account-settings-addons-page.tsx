import { Link } from '@tanstack/react-router'
import { ChevronRight } from 'lucide-react'
import { useRef, useState } from 'react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useProfileSettings } from '@/hooks/use-profile-settings'
import {
  useForjaSetting,
  useNavigationSetting,
  usePlaybackSetting,
} from '@/hooks/use-user-setting'
import {
  availableFeatureTabIds,
  emptyForjaPayload,
  emptyPreferencesPayload,
  DEFAULT_NAV_TAB,
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

type AddonRowProps = {
  title: string
  description: string
  checked?: boolean
  onCheckedChange?: (v: boolean) => void
  hasToggle?: boolean
  href?: string
  hrefLabel?: string
  disabled?: boolean
}

function AddonRow({
  title,
  description,
  checked = false,
  onCheckedChange,
  hasToggle = true,
  href,
  hrefLabel = 'Configure',
  disabled,
}: AddonRowProps) {
  return (
    <div className="border-b border-forja-border/60 last:border-b-0">
      <div className="flex min-h-14.5 items-center gap-3 px-0.5 py-2">
        <div className="min-w-0 flex-1">
          {href ? (
            <Link
              to={href}
              className="group flex items-center gap-2 text-left hover:text-forja-green"
            >
              <span className="min-w-0">
                <span className="block text-sm font-medium text-forja-text group-hover:text-forja-green">
                  {title}
                </span>
                <span className="mt-1 block text-sm text-forja-muted">
                  {description}
                </span>
              </span>
              <span className="ml-auto flex shrink-0 items-center gap-1 text-xs text-forja-muted group-hover:text-forja-green">
                {hrefLabel}
                <ChevronRight className="size-4" />
              </span>
            </Link>
          ) : (
            <span className="min-w-0">
              <span className="block text-sm font-medium">{title}</span>
              <span className="mt-1 block text-sm text-forja-muted">
                {description}
              </span>
            </span>
          )}
        </div>
        {hasToggle && onCheckedChange ? (
          <button
            type="button"
            role="switch"
            aria-checked={checked}
            aria-label={`Activate ${title}`}
            disabled={disabled}
            onClick={() => onCheckedChange(!checked)}
            className={cn(
              'group relative h-6 w-11 shrink-0 appearance-none rounded-full border-0 p-0 transition-colors disabled:cursor-not-allowed disabled:opacity-60',
              checked ? 'bg-forja-green' : 'bg-white/15',
            )}
          >
            <span
              className={cn(
                'pointer-events-none absolute top-1 left-1 size-4 rounded-full bg-forja-bg transition-transform group-hover:bg-neutral-600',
                checked ? 'translate-x-5' : 'translate-x-0',
              )}
            />
          </button>
        ) : null}
      </div>
    </div>
  )
}

function navFromServer(value: unknown): NavDraft {
  const n = value as NavigationPayload | undefined
  return {
    order: [...(n?.tabOrder ?? [])],
    visible: new Set(n?.visibleIds ?? []),
    defaultTab: n?.defaultTab ?? DEFAULT_NAV_TAB,
  }
}

function emptyNavDraft(): NavDraft {
  return {
    order: [],
    visible: new Set(),
    defaultTab: DEFAULT_NAV_TAB,
  }
}

function navToPayload(
  draft: NavDraft,
  availableIds: string[],
): NavigationPayload {
  return pruneNavigationToAvailable(
    {
      visibleIds: draft.order.filter((id) => draft.visible.has(id)),
      tabOrder: draft.order,
      defaultTab: draft.defaultTab,
    },
    availableIds,
  )
}

function playbackFromServer(value: unknown): PreferencesPayload {
  return {
    ...emptyPreferencesPayload(),
    ...((value as PreferencesPayload | undefined) ?? {}),
  }
}

/**
 * Cloud Addons hub — mirrors Settings → Addons in the app.
 * Master switches + links into detail pages (Playback prefs, IPTV portals,
 * Stremio/Nuvio manifests). Hub packs are Plugins, not Addons.
 */
export function AccountSettingsAddonsPage() {
  const settings = useProfileSettings()
  const playback = usePlaybackSetting()
  const navigation = useNavigationSetting()
  const forja = useForjaSetting()
  const [hostBusy, setHostBusy] = useState(false)
  const [hostError, setHostError] = useState<Error | null>(null)
  const [hostFlash, setHostFlash] = useState(false)

  const playDraft = useCommitDraft({
    profileId: playback.profileId,
    updatedAt: playback.data?.updated_at,
    isReady: Boolean(playback.data) && !playback.isLoading,
    serverValue: playback.data?.payload,
    mapServer: playbackFromServer,
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

  const availableIds = availableFeatureTabIds({
    addonFeatureIptv: playDraft.draft.addon_feature_iptv,
    addonFeatureLiveMatches: playDraft.draft.addon_feature_live_matches,
    packs: packsDraft.draft.packs,
  })
  const availableIdsRef = useRef(availableIds)
  availableIdsRef.current = availableIds

  const navDraft = useCommitDraft({
    profileId: navigation.profileId,
    updatedAt: navigation.data?.updated_at,
    isReady: Boolean(navigation.data) && !navigation.isLoading,
    serverValue: navigation.data?.payload,
    mapServer: navFromServer,
    makeEmpty: emptyNavDraft,
    save: navigation.save,
    toPayload: (draft) => navToPayload(draft, availableIdsRef.current),
  })

  const busy =
    hostBusy ||
    playDraft.controlsLocked ||
    playDraft.isSaving ||
    navDraft.controlsLocked ||
    navDraft.isSaving ||
    packsDraft.controlsLocked

  const setPlayBool = (key: keyof PreferencesPayload, value: boolean) => {
    void playDraft.commit((prev) => ({ ...prev, [key]: value }))
  }

  /** One cloud write: unlock flag + default Features rail (no stale prune race). */
  const setHostAddon = (navId: 'iptv' | 'live_matches', on: boolean) => {
    void (async () => {
      const flagKey =
        navId === 'iptv' ? 'addon_feature_iptv' : 'addon_feature_live_matches'
      const nextPlayback: PreferencesPayload = {
        ...playDraft.draft,
        [flagKey]: on,
        ...(navId === 'iptv' && !on ? { iptv_epg_enabled: false } : {}),
      }
      const nextAvailable = availableFeatureTabIds({
        addonFeatureIptv: nextPlayback.addon_feature_iptv,
        addonFeatureLiveMatches: nextPlayback.addon_feature_live_matches,
        packs: packsDraft.draft.packs,
      })
      const visible = new Set(navDraft.draft.visible)
      if (on) visible.add(navId)
      else visible.delete(navId)
      const order = navDraft.draft.order.includes(navId)
        ? navDraft.draft.order
        : on
          ? [...navDraft.draft.order, navId]
          : navDraft.draft.order
      const nextNav = pruneNavigationToAvailable(
        {
          visibleIds: order.filter((id) => visible.has(id)),
          tabOrder: order,
          defaultTab: navDraft.draft.defaultTab,
        },
        nextAvailable,
      )

      setHostBusy(true)
      setHostError(null)
      try {
        await settings.patch({
          playback: nextPlayback,
          navigation: nextNav,
        })
        playDraft.setDraft(nextPlayback)
        navDraft.setDraft({
          order: nextNav.tabOrder,
          visible: new Set(nextNav.visibleIds),
          defaultTab: nextNav.defaultTab,
        })
        availableIdsRef.current = nextAvailable
        setHostFlash(true)
        window.setTimeout(() => setHostFlash(false), 2000)
      } catch (e) {
        setHostError(e instanceof Error ? e : new Error('Save failed'))
      } finally {
        setHostBusy(false)
      }
    })()
  }

  const hostAddonOn = (navId: 'iptv' | 'live_matches'): boolean => {
    const flag =
      navId === 'iptv'
        ? playDraft.draft.addon_feature_iptv
        : playDraft.draft.addon_feature_live_matches
    return flag === true
  }

  const footerSaving = hostBusy || playDraft.isSaving || navDraft.isSaving
  const footerFlash = hostFlash || playDraft.savedFlash || navDraft.savedFlash
  const footerError =
    hostError ?? playDraft.saveError ?? navDraft.saveError

  return (
    <AccountSettingsShell
      title="Addons"
      description="Host product surfaces — same list as Settings → Addons in the app. Switches activate each addon; open a row to configure. Hub catalogs install under Forja Packs, then show under Features."
      footer={
        <SettingsAutosaveFooter
          isSaving={footerSaving}
          savedFlash={footerFlash}
          error={footerError}
        />
      }
    >
      <SettingsSection
        label="Built-in addons"
        description="Always listed. Packs do not add rows here — they contribute settings inside an addon or hub tabs under Features."
      >
        <AddonRow
          title="Playback"
          description="Quality, audio, auto-play, web streaming"
          hasToggle={false}
          href="/account/settings/playback"
          disabled={busy}
        />
        <AddonRow
          title="IPTV"
          description="Xtream portals, EPG, live quality"
          checked={hostAddonOn('iptv')}
          onCheckedChange={(v) => setHostAddon('iptv', v)}
          href="/account/settings/iptv"
          hrefLabel="Portals"
          disabled={busy}
        />
        <AddonRow
          title="Live Sports"
          description="Live Matches tab, live provider packs, schedule catalogs"
          checked={hostAddonOn('live_matches')}
          onCheckedChange={(v) => setHostAddon('live_matches', v)}
          href="/account/settings/live-sports"
          hrefLabel="Plugins"
          disabled={busy}
        />
        <AddonRow
          title="Direct torrent"
          description="Torrent indexer packs, Jackett / Prowlarr in the app"
          checked={playDraft.draft.play_source_torrent_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_torrent_enabled', v)}
          href="/account/settings/torrent"
          hrefLabel="Plugins"
          disabled={busy}
        />
        <AddonRow
          title="Stremio"
          description="Install and manage Stremio addon URLs"
          checked={playDraft.draft.play_source_stremio_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_stremio_enabled', v)}
          href="/account/settings/stremio"
          hrefLabel="Addons"
          disabled={busy}
        />
        <AddonRow
          title="Nuvio"
          description="Install and manage Nuvio scraper manifests"
          checked={playDraft.draft.play_source_nuvio_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_nuvio_enabled', v)}
          href="/account/settings/nuvio"
          hrefLabel="Scrapers"
          disabled={busy}
        />
        <p className="px-0.5 pb-2 pt-4 text-xs text-forja-muted">
          Debrid, Connected services, and LAN stay in the app. Hub packs install
          under Forja Packs, then appear under Features. Live Sports / Direct
          torrent Plugins manage those Forja packs on this profile.
        </p>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
