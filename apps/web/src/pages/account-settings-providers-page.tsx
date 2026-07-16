import { useEffect, useState } from 'react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { ProviderOrderList } from '@/components/provider-order-list'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  emptyProvidersPayload,
  SYNC_DOMAINS,
  type ProvidersPayload,
} from '@/lib/sync-domains'

const tabs = [
  {
    id: 'film',
    label: 'Film and series',
    description: 'Embed and extractor providers for movies and TV.',
    key: 'stream_provider_order',
  },
  {
    id: 'anime',
    label: 'Anime',
    description: 'Mirror try-order for the Anime tab.',
    key: 'anime_provider_order',
  },
  {
    id: 'asian',
    label: 'Asian drama',
    description: 'KissKH-compatible hosts.',
    key: 'asian_drama_provider_order',
  },
] as const

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
      description="Try-order for film and series, anime mirrors, and Asian drama hosts. Higher items are tried first."
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
      <Tabs defaultValue="film">
        <TabsList aria-label="Provider types">
          {tabs.map((item) => (
            <TabsTrigger key={item.id} value={item.id}>
              {item.label}
            </TabsTrigger>
          ))}
        </TabsList>

        {tabs.map((item) => (
          <TabsContent key={item.id} value={item.id} className="min-h-80">
            <p className="mb-4 text-xs leading-5 text-forja-muted">
              {item.description}
            </p>
            <ProviderOrderList
              items={draft[item.key] ?? []}
              disabled={isLoading}
              onChange={(next) =>
                setDraft((prev) => ({
                  ...prev,
                  [item.key]: next,
                }))
              }
            />
          </TabsContent>
        ))}
      </Tabs>
    </AccountSettingsShell>
  )
}
