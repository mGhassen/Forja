import { useEffect, useState } from 'react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { ProviderOrderList } from '@/components/provider-order-list'
import { SettingsSection } from '@/components/settings-section'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  emptyProvidersPayload,
  SYNC_DOMAINS,
  type ProvidersPayload,
} from '@/lib/sync-domains'

export function AccountSettingsProvidersPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useUserSetting<ProvidersPayload>(SYNC_DOMAINS.providers)
  const [draft, setDraft] = useState(emptyProvidersPayload())
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(emptyProvidersPayload())
  }, [profileId])

  useEffect(() => {
    if (!data) return
    setDraft({ ...emptyProvidersPayload(), ...data.payload })
  }, [data])

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Provider order"
      description="Try-order for web streams, anime mirrors, and Asian drama hosts. Higher items are tried first."
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
        label="Web streaming"
        description="Embed and extractor providers for movies and TV."
      >
          <ProviderOrderList
            items={draft.stream_provider_order ?? []}
            disabled={isLoading}
            onChange={(stream_provider_order) =>
              setDraft((prev) => ({ ...prev, stream_provider_order }))
            }
          />
      </SettingsSection>

      <SettingsSection label="Anime" description="Mirror try-order for the Anime tab.">
          <ProviderOrderList
            items={draft.anime_provider_order ?? []}
            disabled={isLoading}
            onChange={(anime_provider_order) =>
              setDraft((prev) => ({ ...prev, anime_provider_order }))
            }
          />
      </SettingsSection>

      <SettingsSection label="Asian drama" description="KissKH-compatible hosts.">
          <ProviderOrderList
            items={draft.asian_drama_provider_order ?? []}
            disabled={isLoading}
            onChange={(asian_drama_provider_order) =>
              setDraft((prev) => ({ ...prev, asian_drama_provider_order }))
            }
          />
      </SettingsSection>
    </AccountSettingsShell>
  )
}
