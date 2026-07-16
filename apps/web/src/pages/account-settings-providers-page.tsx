import { useEffect, useState } from 'react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { ProviderOrderList } from '@/components/provider-order-list'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  emptyProvidersPayload,
  SYNC_DOMAINS,
  type ProvidersPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

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

type ProviderTabId = (typeof tabs)[number]['id']

export function AccountSettingsProvidersPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useUserSetting<ProvidersPayload>(SYNC_DOMAINS.providers)
  const [draft, setDraft] = useState(emptyProvidersPayload())
  const [activeTab, setActiveTab] = useState<ProviderTabId>('film')
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(emptyProvidersPayload())
  }, [profileId])

  useEffect(() => {
    if (!data) return
    setDraft({ ...emptyProvidersPayload(), ...data.payload })
  }, [data])

  const tab = tabs.find((item) => item.id === activeTab) ?? tabs[0]

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
      <div
        role="tablist"
        aria-label="Provider types"
        className="mb-6 flex flex-wrap gap-2"
      >
        {tabs.map((item) => {
          const selected = item.id === activeTab
          return (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={selected}
              id={`provider-tab-${item.id}`}
              className={cn(
                'rounded-md px-3.5 py-2 text-sm transition',
                selected
                  ? 'bg-forja-green font-bold text-[#0B0A0A]'
                  : 'bg-forja-elevated font-medium text-forja-muted hover:bg-white/5 hover:text-forja-text',
              )}
              onClick={() => setActiveTab(item.id)}
            >
              {item.label}
            </button>
          )
        })}
      </div>

      <div
        role="tabpanel"
        aria-labelledby={`provider-tab-${tab.id}`}
        className="min-h-80"
      >
        <div className="mb-4">
          <div className="mb-1 flex items-center gap-2.5">
            <span className="h-0.5 w-3.5 bg-forja-green" />
            <h3 className="text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green">
              {tab.label}
            </h3>
          </div>
          <p className="ml-6 text-xs leading-5 text-forja-muted">{tab.description}</p>
        </div>

        <ProviderOrderList
          items={draft[tab.key] ?? []}
          disabled={isLoading}
          onChange={(next) =>
            setDraft((prev) => ({
              ...prev,
              [tab.key]: next,
            }))
          }
        />
      </div>
    </AccountSettingsShell>
  )
}
