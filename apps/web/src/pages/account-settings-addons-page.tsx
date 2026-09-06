import { Link } from '@tanstack/react-router'
import { ChevronRight } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import {
  useNavigationSetting,
  usePlaybackSetting,
} from '@/hooks/use-user-setting'
import {
  emptyPreferencesPayload,
  DEFAULT_NAV_TAB,
  HOST_CORE_NAV_IDS,
  normalizeNavigationPayload,
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
  const n = normalizeNavigationPayload(value as NavigationPayload | undefined)
  return {
    order: n.tabOrder,
    visible: new Set(n.visibleIds),
    defaultTab: n.defaultTab,
  }
}

function emptyNavDraft(): NavDraft {
  return {
    order: [...HOST_CORE_NAV_IDS],
    visible: new Set(),
    defaultTab: DEFAULT_NAV_TAB,
  }
}

function navToPayload(draft: NavDraft): NavigationPayload {
  return normalizeNavigationPayload({
    visibleIds: draft.order.filter((id) => draft.visible.has(id)),
    tabOrder: draft.order,
    defaultTab: draft.defaultTab,
  })
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
  const playback = usePlaybackSetting()
  const navigation = useNavigationSetting()

  const playDraft = useCommitDraft({
    profileId: playback.profileId,
    updatedAt: playback.data?.updated_at,
    isReady: Boolean(playback.data) && !playback.isLoading,
    serverValue: playback.data?.payload,
    mapServer: playbackFromServer,
    makeEmpty: emptyPreferencesPayload,
    save: playback.save,
  })

  const navDraft = useCommitDraft({
    profileId: navigation.profileId,
    updatedAt: navigation.data?.updated_at,
    isReady: Boolean(navigation.data) && !navigation.isLoading,
    serverValue: navigation.data?.payload,
    mapServer: navFromServer,
    makeEmpty: emptyNavDraft,
    save: navigation.save,
    toPayload: navToPayload,
  })

  const busy =
    playDraft.controlsLocked ||
    playDraft.isSaving ||
    navDraft.controlsLocked ||
    navDraft.isSaving

  const setPlayBool = (key: keyof PreferencesPayload, value: boolean) => {
    void playDraft.commit((prev) => ({ ...prev, [key]: value }))
  }

  const setNavTab = (id: string, on: boolean) => {
    void navDraft.commit((prev) => {
      const visible = new Set(prev.visible)
      if (on) visible.add(id)
      else visible.delete(id)
      const order = prev.order.includes(id) ? prev.order : [...prev.order, id]
      let defaultTab = prev.defaultTab
      if (!on && defaultTab === id) {
        const still = order.filter((x) => visible.has(x))
        defaultTab = still[0] ?? DEFAULT_NAV_TAB
      }
      return { ...prev, order, visible, defaultTab }
    })
  }

  /** RFC-086: unlock via playback flag + default Features rail on (same as app). */
  const setHostAddon = (
    navId: 'iptv' | 'live_matches',
    on: boolean,
  ) => {
    const flagKey =
      navId === 'iptv' ? 'addon_feature_iptv' : 'addon_feature_live_matches'
    void playDraft.commit((prev) => ({
      ...prev,
      [flagKey]: on,
      ...(navId === 'iptv' && !on ? { iptv_epg_enabled: false } : {}),
    }))
    setNavTab(navId, on)
  }

  const hostAddonOn = (navId: 'iptv' | 'live_matches'): boolean => {
    const flag =
      navId === 'iptv'
        ? playDraft.draft.addon_feature_iptv
        : playDraft.draft.addon_feature_live_matches
    // Legacy cloud: web used to write nav only — treat rail membership as on.
    if (flag === undefined) return navDraft.draft.visible.has(navId)
    return flag
  }

  const footerSaving = playDraft.isSaving || navDraft.isSaving
  const footerFlash = playDraft.savedFlash || navDraft.savedFlash
  const footerError = playDraft.saveError ?? navDraft.saveError

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
