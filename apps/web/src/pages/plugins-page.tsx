import { useEffect } from 'react'
import { Link } from '@tanstack/react-router'
import { PluginCatalogBrowser } from '@/components/plugin-catalog-browser'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { useAuth } from '@/hooks/use-auth'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaPluginCatalog } from '@/hooks/use-forja-plugin-catalog'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import {
  clearPluginInstallIntent,
  packRowFromIntent,
  readPluginInstallIntent,
} from '@/lib/forja-plugin-install'
import {
  emptyForjaPayload,
  type ForjaPayload,
} from '@/lib/sync-domains'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

function usePendingPluginInstall() {
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, profileId, isLoading, save } = useForjaSetting()
  const { commit } = useCommitDraft({
    profileId,
    updatedAt: data?.updated_at,
    isReady: Boolean(data) && !isLoading,
    serverValue: data?.payload,
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save,
  })

  useEffect(() => {
    if (!user || !activeProfile || !data || isLoading) return
    const intent = readPluginInstallIntent()
    if (!intent) return
    const row = packRowFromIntent(intent)
    void commit((prev) => {
      if (prev.packs.some((pack) => pack.manifestUrl === row.manifestUrl)) {
        return prev
      }
      return { packs: [...prev.packs, row] }
    }).finally(() => {
      clearPluginInstallIntent()
    })
  }, [activeProfile, commit, data, isLoading, user])
}

export function PluginsPage() {
  const { data: packs, isLoading, error } = useForjaPluginCatalog()
  usePendingPluginInstall()

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="quiet" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="mx-auto w-full max-w-[1200px] flex-1 px-[5vw] pb-12 pt-20 sm:pt-24">
          <header className="mb-6 flex flex-col gap-2 sm:mb-8 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h1 className="font-disp text-2xl font-bold uppercase tracking-tight text-[#EDE6DA] sm:text-3xl">
                Plugins
              </h1>
              <p className="mt-1 max-w-lg text-sm text-[rgba(237,230,218,0.5)]">
                Official remote engine packs. Search, pick one, add to your
                profile — Forja installs on sync.
              </p>
            </div>
            <Link
              to="/download"
              className="shrink-0 text-xs text-[rgba(237,230,218,0.45)] underline-offset-2 hover:text-forja-green hover:underline"
            >
              Don&apos;t have the app? Download
            </Link>
          </header>

          <PluginCatalogBrowser
            packs={packs ?? []}
            isLoading={isLoading}
            error={error}
          />
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
