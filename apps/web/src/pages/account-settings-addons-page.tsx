import { Link } from '@tanstack/react-router'
import { ChevronRight } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { usePlaybackSetting } from '@/hooks/use-user-setting'
import {
  emptyPreferencesPayload,
  type PreferencesPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

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

  const playDraft = useCommitDraft({
    profileId: playback.profileId,
    updatedAt: playback.data?.updated_at,
    isReady: Boolean(playback.data) && !playback.isLoading,
    serverValue: playback.data?.payload,
    mapServer: playbackFromServer,
    makeEmpty: emptyPreferencesPayload,
    save: playback.save,
  })

  const busy = playDraft.controlsLocked || playDraft.isSaving

  const setPlayBool = (key: keyof PreferencesPayload, value: boolean) => {
    void playDraft.commit((prev) => ({ ...prev, [key]: value }))
  }

  /** IPTV player prefs flag only — Features IPTV tab comes from the IPTV hub pack. */
  const setIptvAddon = (on: boolean) => {
    void playDraft.commit((prev) => ({
      ...prev,
      addon_feature_iptv: on,
      ...(on ? {} : { iptv_epg_enabled: false }),
    }))
  }

  return (
    <AccountSettingsShell
      title="Addons"
      description="Host product surfaces — same list as Settings → Addons in the app. Hub tabs (IPTV, Live Sports, Home, …) come from Forja Packs on this profile, then show under Features."
      footer={
        <SettingsAutosaveFooter
          isSaving={playDraft.isSaving}
          savedFlash={playDraft.savedFlash}
          error={playDraft.saveError}
        />
      }
    >
      <SettingsSection
        label="Built-in addons"
        description="Always listed. Packs do not add rows here — they contribute settings under Forja Packs or hub tabs under Features."
      >
        <AddonRow
          title="Playback"
          description="Quality, audio, auto-play"
          hasToggle={false}
          href="/account/settings/playback"
          disabled={busy}
        />
        <AddonRow
          title="IPTV"
          description="Live player prefs (EPG, quality). The IPTV tab comes from the IPTV hub pack under Forja Packs."
          checked={playDraft.draft.addon_feature_iptv === true}
          onCheckedChange={(v) => setIptvAddon(v)}
          href="/account/settings/iptv"
          hrefLabel="Portals"
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
          Debrid, Connected services, and LAN stay in the app. Live Sports and
          other hub packs are added under Forja Packs on this profile; the app
          downloads and installs them.
        </p>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
