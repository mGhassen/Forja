import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { SettingsToggle } from '@/components/settings-toggle'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { usePlaybackSetting } from '@/hooks/use-user-setting'
import {
  ANIME_TITLE_LANGUAGE_OPTIONS,
  AUDIO_LANGUAGE_OPTIONS,
  emptyPreferencesPayload,
  MAX_PLAYBACK_HEIGHT_OPTIONS,
  SUBTITLE_LANGUAGE_OPTIONS,
  type PreferencesPayload,
} from '@/lib/sync-domains'

function playbackFromServer(value: unknown): PreferencesPayload {
  return {
    ...emptyPreferencesPayload(),
    ...((value as PreferencesPayload | undefined) ?? {}),
  }
}

export function AccountSettingsPlaybackPage() {
  const { data, profileId, isLoading, save } = usePlaybackSetting()
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
    mapServer: playbackFromServer,
    makeEmpty: emptyPreferencesPayload,
    save,
  })

  const setBool = (key: keyof PreferencesPayload, value: boolean) => {
    void commit((prev) => ({ ...prev, [key]: value }))
  }

  return (
    <AccountSettingsShell
      title="Playback"
      description="Addons → Playback — quality, audio, auto-play. Same player prefs as Settings → Addons → Playback in the app. Play sources (torrent / Stremio / Nuvio) are on the Addons hub."
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={saveError}
        />
      }
    >
      <SettingsSection label="Player">
        <SettingsToggle
          label="Auto next episode"
          checked={draft.auto_next_episode ?? true}
          onChange={(v) => setBool('auto_next_episode', v)}
          disabled={controlsLocked || isSaving}
        />
        <SettingsToggle
          label="Auto skip intro"
          description="Uses IntroDB when available."
          checked={draft.auto_skip_intro ?? false}
          onChange={(v) => setBool('auto_skip_intro', v)}
          disabled={controlsLocked || isSaving}
        />
        <SettingsToggle
          label="Content warnings"
          description="Show IMDb content ratings when playback starts."
          checked={draft.content_warnings ?? true}
          onChange={(v) => setBool('content_warnings', v)}
          disabled={controlsLocked || isSaving}
        />
        <SettingsToggle
          label="Avoid unsupported audio"
          description="Skip Atmos, TrueHD, and 7.1 when possible."
          checked={draft.avoid_unsupported_audio ?? true}
          onChange={(v) => setBool('avoid_unsupported_audio', v)}
          disabled={controlsLocked || isSaving}
        />
        <SettingsToggle
          label="Auto picture-in-picture"
          description="Desktop: enter PiP when switching Space or virtual desktop while playing."
          checked={draft.auto_pip_on_desktop_switch ?? false}
          onChange={(v) => setBool('auto_pip_on_desktop_switch', v)}
          disabled={controlsLocked || isSaving}
        />

        <div className="flex min-h-16.5 items-center justify-between gap-5 px-0.5 py-3">
          <Label htmlFor="audio-lang" className="text-sm font-medium">
            Preferred audio language
          </Label>
          <select
            id="audio-lang"
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={draft.preferred_audio_lang ?? 'None'}
            disabled={controlsLocked || isSaving}
            onChange={(e) =>
              void commit((prev) => ({
                ...prev,
                preferred_audio_lang: e.target.value,
              }))
            }
          >
            {AUDIO_LANGUAGE_OPTIONS.map((lang) => (
              <option key={lang} value={lang}>
                {lang}
              </option>
            ))}
          </select>
        </div>

        <div className="flex min-h-16.5 items-center justify-between gap-5 px-0.5 py-3">
          <Label htmlFor="subtitle-lang" className="text-sm font-medium">
            Preferred subtitle language
          </Label>
          <select
            id="subtitle-lang"
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={draft.preferred_subtitle_lang ?? 'English'}
            disabled={controlsLocked || isSaving}
            onChange={(e) =>
              void commit((prev) => ({
                ...prev,
                preferred_subtitle_lang: e.target.value,
              }))
            }
          >
            {SUBTITLE_LANGUAGE_OPTIONS.map((lang) => (
              <option key={lang} value={lang}>
                {lang}
              </option>
            ))}
          </select>
        </div>

        <div className="flex min-h-16.5 items-center justify-between gap-5 px-0.5 py-3">
          <Label htmlFor="max-quality" className="text-sm font-medium">
            Max stream quality
          </Label>
          <select
            id="max-quality"
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={String(draft.max_playback_height ?? 2160)}
            disabled={controlsLocked || isSaving}
            onChange={(e) =>
              void commit((prev) => ({
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

        <div className="flex min-h-16.5 items-center justify-between gap-5 px-0.5 py-3">
          <div className="min-w-0">
            <Label htmlFor="anime-title-lang" className="text-sm font-medium">
              Anime title language
            </Label>
            <p className="mt-0.5 text-xs text-forja-muted">
              Anime hub, details, and player. Default Romaji.
            </p>
          </div>
          <select
            id="anime-title-lang"
            className="h-9 min-w-40 border border-forja-border bg-forja-surface px-3 text-sm"
            value={draft.anime_title_language ?? 'romaji'}
            disabled={controlsLocked || isSaving}
            onChange={(e) =>
              void commit((prev) => ({
                ...prev,
                anime_title_language: e.target.value,
              }))
            }
          >
            {ANIME_TITLE_LANGUAGE_OPTIONS.map((opt) => (
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
