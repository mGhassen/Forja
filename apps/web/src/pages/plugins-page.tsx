import { useEffect } from 'react'
import { Loader2, Puzzle } from 'lucide-react'
import { AddToForjaButton } from '@/components/add-to-forja-button'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { useAuth } from '@/hooks/use-auth'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaPluginCatalog } from '@/hooks/use-forja-plugin-catalog'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import {
  groupPluginPacksByKind,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import {
  clearPluginInstallIntent,
  packRowFromIntent,
  readPluginInstallIntent,
} from '@/lib/forja-plugin-install'
import {
  emptyForjaPayload,
  type ForjaPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

function PluginPackCard({ pack }: { pack: ForjaPluginPackLive }) {
  const accent =
    pack.accent === 'flame'
      ? 'border-forja-flame/25 bg-forja-flame/5'
      : 'border-forja-green/25 bg-forja-green/5'

  return (
    <Card
      className={cn(
        'border-forja-border/80 bg-forja-surface/80 backdrop-blur-sm transition-colors hover:border-forja-green/30',
        accent,
      )}
    >
      <CardHeader className="gap-3 pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0 space-y-1">
            <CardTitle className="font-disp text-2xl tracking-tight">
              {pack.name}
            </CardTitle>
            <CardDescription className="text-[#EDE6DA]/72">
              {pack.description}
            </CardDescription>
          </div>
          {pack.version ? (
            <span className="shrink-0 rounded-full border border-white/10 bg-black/20 px-2.5 py-1 font-mono text-[11px] uppercase tracking-wider text-forja-muted">
              v{pack.version}
            </span>
          ) : null}
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <dl className="grid gap-2 text-sm text-forja-muted sm:grid-cols-2">
          {pack.pluginCount != null ? (
            <div>
              <dt className="font-mono text-[10px] uppercase tracking-[0.14em] text-[#EDE6DA]/45">
                Plugins
              </dt>
              <dd className="text-[#EDE6DA]/80">{pack.pluginCount}</dd>
            </div>
          ) : null}
          <div className="sm:col-span-2">
            <dt className="font-mono text-[10px] uppercase tracking-[0.14em] text-[#EDE6DA]/45">
              Manifest
            </dt>
            <dd className="truncate font-mono text-xs text-[#EDE6DA]/65">
              {pack.manifestUrl}
            </dd>
          </div>
        </dl>
        <AddToForjaButton pack={pack} />
      </CardContent>
    </Card>
  )
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

  const groups = packs ? groupPluginPacksByKind(packs) : []

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="quiet" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1 px-[5vw] pb-16 pt-24 sm:pt-28">
          <div className="mx-auto max-w-[1100px]">
            <Reveal>
              <header className="mb-10 max-w-3xl space-y-4">
                <div className="inline-flex items-center gap-2 rounded-full border border-forja-green/30 bg-forja-green/10 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.16em] text-forja-green">
                  <Puzzle className="size-3.5" aria-hidden />
                  Remote packs
                </div>
                <h1 className="font-disp text-[clamp(2.4rem,6vw,4rem)] font-bold leading-[0.95] tracking-[-0.04em]">
                  Forja plugins
                </h1>
                <p className="text-lg text-[#EDE6DA]/72">
                  Official engine packs hosted on GitHub. Add a pack to your
                  signed-in profile — Forja installs it on sync. You can also
                  paste manifest URLs under{' '}
                  <span className="text-[#EDE6DA]">
                    Settings → Sources → Forja
                  </span>
                  .
                </p>
              </header>
            </Reveal>

            {isLoading ? (
              <div className="flex items-center gap-3 text-forja-muted">
                <Loader2 className="size-5 animate-spin" aria-hidden />
                Loading remote packs…
              </div>
            ) : error ? (
              <p className="text-red-300">
                {error instanceof Error
                  ? error.message
                  : 'Could not load plugins.'}
              </p>
            ) : (
              <div className="space-y-12">
                {groups.map((group, groupIndex) => (
                  <section key={group.kind} aria-labelledby={`kind-${group.kind}`}>
                    <Reveal delayMs={groupIndex * 60}>
                      <h2
                        id={`kind-${group.kind}`}
                        className="mb-5 font-mono text-[11px] font-bold uppercase tracking-[0.18em] text-forja-muted"
                      >
                        {group.label}
                      </h2>
                      <div className="grid gap-5 md:grid-cols-2">
                        {group.packs.map((pack, packIndex) => (
                          <Reveal
                            key={pack.id}
                            delayMs={groupIndex * 60 + packIndex * 40}
                          >
                            <PluginPackCard pack={pack} />
                          </Reveal>
                        ))}
                      </div>
                    </Reveal>
                  </section>
                ))}
              </div>
            )}
          </div>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
