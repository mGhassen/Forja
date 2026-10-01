import { useEffect, useMemo, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { ChevronRight } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import {
  useForjaSetting,
  usePlaybackSetting,
} from '@/hooks/use-user-setting'
import {
  discoverPackAddonBuckets,
  packAddonBucketsFromUrls,
  type PackAddonBucket,
} from '@/lib/pack-addon-discovery'
import {
  emptyForjaPayload,
  emptyPreferencesPayload,
  type ForjaPayload,
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

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return {
    packs: payload?.packs ?? [],
    ...(payload?.onboarded === true ? { onboarded: true as const } : {}),
  }
}

/**
 * Cloud Addons hub — same host rows + pack-discovered buckets as
 * Settings → Addons in the app (RFC-089).
 */
export function AccountSettingsAddonsPage() {
  const playback = usePlaybackSetting()
  const forja = useForjaSetting()
  const [packBuckets, setPackBuckets] = useState<PackAddonBucket[]>([])
  const [packLoading, setPackLoading] = useState(true)

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
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save: forja.save,
  })

  const forjaReady = Boolean(forja.data) && !forja.isLoading
  const packs = packsDraft.draft.packs
  const packsKey = useMemo(
    () =>
      packs
        .map((p) => `${p.manifestUrl}|${p.enabled !== false ? 1 : 0}`)
        .sort()
        .join('\n'),
    [packs],
  )

  useEffect(() => {
    if (!forjaReady) {
      setPackLoading(true)
      setPackBuckets([])
      return
    }

    let cancelled = false
    // Sync seed from URLs so IPTV Portals appears even when manifest fetch fails
    // (Flutter often syncs local `/Users/…/hubs/iptv/manifest.json` paths).
    const seeded = packAddonBucketsFromUrls(packs)
    setPackBuckets(seeded)
    setPackLoading(seeded.length === 0)

    void (async () => {
      try {
        const buckets = await discoverPackAddonBuckets(packs)
        if (!cancelled) setPackBuckets(buckets)
      } catch {
        if (!cancelled) setPackBuckets(seeded)
      } finally {
        if (!cancelled) setPackLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [packsKey, packs, forjaReady])

  const busy = playDraft.controlsLocked || playDraft.isSaving

  const setPlayBool = (key: keyof PreferencesPayload, value: boolean) => {
    void playDraft.commit((prev) => ({ ...prev, [key]: value }))
  }

  return (
    <AccountSettingsShell
      title="Addons"
      description="Same list as Settings → Addons in the app. Host surfaces below; pack settings rows appear when those packs are enabled on this profile."
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
        description="Playback, Direct torrent, Stremio, and Nuvio. Connected services and LAN stay in the app."
      >
        <AddonRow
          title="Playback"
          description="Quality, audio, auto-play"
          hasToggle={false}
          href="/account/settings/playback"
          disabled={busy}
        />
        <AddonRow
          title="Direct torrent"
          description="Jackett, Prowlarr, torrent engine"
          checked={playDraft.draft.play_source_torrent_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_torrent_enabled', v)}
          href="/account/settings/torrent"
          hrefLabel="Plugins"
          disabled={busy}
        />
        <AddonRow
          title="Stremio"
          description="Stremio addons"
          checked={playDraft.draft.play_source_stremio_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_stremio_enabled', v)}
          href="/account/settings/stremio"
          hrefLabel="Addons"
          disabled={busy}
        />
        <AddonRow
          title="Nuvio"
          description="Nuvio scrapers"
          checked={playDraft.draft.play_source_nuvio_enabled ?? true}
          onCheckedChange={(v) => setPlayBool('play_source_nuvio_enabled', v)}
          href="/account/settings/nuvio"
          hrefLabel="Scrapers"
          disabled={busy}
        />
      </SettingsSection>

      <SettingsSection
        label="Pack settings"
        description="Discovered from enabled Forja Packs on this profile (same as the app). Install packs under Forja Packs."
      >
        {packLoading ? (
          <p className="px-0.5 py-2 text-sm text-forja-muted">
            Loading pack settings…
          </p>
        ) : packBuckets.length === 0 ? (
          <p className="px-0.5 py-2 text-sm text-forja-muted">
            No pack settings yet. Enable IPTV, Live Sports, My List, Debrid, or
            other packs with Addon settings under{' '}
            <Link
              to="/account/settings/forja"
              className="text-forja-green hover:underline"
            >
              Forja Packs
            </Link>
            .
          </p>
        ) : (
          packBuckets.map((bucket) => (
            <AddonRow
              key={bucket.id}
              title={bucket.title}
              description={bucket.subtitle}
              hasToggle={false}
              href={bucket.href}
              hrefLabel={bucket.id === 'iptv' ? 'Portals' : 'Settings'}
            />
          ))
        )}
      </SettingsSection>

      <p className="px-0.5 pb-2 text-xs text-forja-muted">
        Debrid API keys, Connected services (Simkl), and LAN stay in the app.
        Non-secret pack settings (Live Sports Setup, My List open hubs, …) sync
        with your devices.
      </p>
    </AccountSettingsShell>
  )
}
