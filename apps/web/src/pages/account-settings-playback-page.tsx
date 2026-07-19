import { useEffect, useState } from 'react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { SettingsToggle } from '@/components/settings-toggle'
import { usePlaybackSetting } from '@/hooks/use-user-setting'
import {
  AUDIO_LANGUAGE_OPTIONS,
  emptyPreferencesPayload,
  MAX_PLAYBACK_HEIGHT_OPTIONS,
  type PreferencesPayload,
} from '@/lib/sync-domains'

export function AccountSettingsPlaybackPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    usePlaybackSetting()
  const [draft, setDraft] = useState(emptyPreferencesPayload())
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    // Wipe immediately on profile change — never keep the previous profile's draft.
    setDraft(emptyPreferencesPayload())
  }, [profileId])

  useEffect(() => {
    if (!profileId || isLoading || !data) {
      setDraft(emptyPreferencesPayload())
      return
    }
    setDraft({ ...emptyPreferencesPayload(), ...data.payload })
  }, [profileId, isLoading, data])

  const setBool = (key: keyof PreferencesPayload, value: boolean) => {
    setDraft((prev) => ({ ...prev, [key]: value }))
  }

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Playback"
      description="Cross-device playback preferences. Built-in engine and per-device player choices stay in the app."
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
        label="Play sources"
        description="Which backends Forja tries when you hit Play."
      >
          <SettingsToggle
            label="Direct torrent"
            description="Indexers and Nuvio scrapers from Sources."
            checked={draft.play_source_torrent_enabled ?? true}
            onChange={(v) => setBool('play_source_torrent_enabled', v)}
            disabled={isLoading}
          />
          <SettingsToggle
            label="Stremio"
            description="Installed Stremio addons."
            checked={draft.play_source_stremio_enabled ?? true}
            onChange={(v) => setBool('play_source_stremio_enabled', v)}
            disabled={isLoading}
          />
          <SettingsToggle
            label="Web streaming"
            description="Embed and extractor providers."
            checked={draft.play_source_webstreaming_enabled ?? true}
            onChange={(v) => setBool('play_source_webstreaming_enabled', v)}
            disabled={isLoading}
          />
      </SettingsSection>

      <SettingsSection label="Player">
          <SettingsToggle
            label="Auto next episode"
            checked={draft.auto_next_episode ?? true}
            onChange={(v) => setBool('auto_next_episode', v)}
            disabled={isLoading}
          />
          <SettingsToggle
            label="Auto skip intro"
            description="Uses IntroDB when available."
            checked={draft.auto_skip_intro ?? false}
            onChange={(v) => setBool('auto_skip_intro', v)}
            disabled={isLoading}
          />
          <SettingsToggle
            label="IPTV programme guide"
            description="Load EPG in the IPTV player."
            checked={draft.iptv_epg_enabled ?? true}
            onChange={(v) => setBool('iptv_epg_enabled', v)}
            disabled={isLoading}
          />
          <SettingsToggle
            label="Avoid unsupported audio"
            description="Skip Atmos, TrueHD, and 7.1 when possible."
            checked={draft.avoid_unsupported_audio ?? true}
            onChange={(v) => setBool('avoid_unsupported_audio', v)}
            disabled={isLoading}
          />

          <div className="flex min-h-[66px] items-center justify-between gap-5 px-0.5 py-3">
            <Label htmlFor="audio-lang" className="text-sm font-medium">
              Preferred audio language
            </Label>
            <select
              id="audio-lang"
              className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
              value={draft.preferred_audio_lang ?? 'None'}
              disabled={isLoading}
              onChange={(e) =>
                setDraft((prev) => ({ ...prev, preferred_audio_lang: e.target.value }))
              }
            >
              {AUDIO_LANGUAGE_OPTIONS.map((lang) => (
                <option key={lang} value={lang}>
                  {lang}
                </option>
              ))}
            </select>
          </div>

          <div className="flex min-h-[66px] items-center justify-between gap-5 px-0.5 py-3">
            <Label htmlFor="max-quality" className="text-sm font-medium">
              Max stream quality
            </Label>
            <select
              id="max-quality"
              className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
              value={String(draft.max_playback_height ?? 0)}
              disabled={isLoading}
              onChange={(e) =>
                setDraft((prev) => ({
                  ...prev,
                  max_playback_height: Number(e.target.value),
                }))
              }
            >
              {MAX_PLAYBACK_HEIGHT_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </div>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
