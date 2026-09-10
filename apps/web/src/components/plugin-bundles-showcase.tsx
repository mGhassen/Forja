import { useMemo } from 'react'
import { Layers, Sparkles } from 'lucide-react'
import { PluginBatchInstallDialog } from '@/components/plugin-batch-install-dialog'
import { Reveal } from '@/components/reveal'
import { LiquidGlass } from '@/components/liquid-glass'
import { usePluginBatchInstall } from '@/hooks/use-plugin-batch-install'
import {
  hydratePluginBundles,
  pluginKindLabel,
  type ForjaPluginBundleLive,
  type ForjaPluginBundleMeta,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import { cn } from '@/lib/utils'

function packShortName(name: string): string {
  return name.replace(/^ForjaHQ\s+/i, '').trim() || name
}

function BundlePackChips({ packs }: { packs: ForjaPluginPackLive[] }) {
  return (
    <ul className="flex flex-wrap gap-2">
      {packs.map((pack) => (
        <li
          key={pack.id}
          className={cn(
            'rounded-full border px-3 py-1.5 font-mono-ui text-[10px] uppercase tracking-[0.12em]',
            pack.accent === 'flame'
              ? 'border-forja-flame/35 bg-forja-flame/10 text-forja-flame'
              : 'border-forja-green/30 bg-forja-green/10 text-forja-green',
          )}
        >
          {packShortName(pack.name)}
          <span className="ml-1.5 text-[rgba(237,230,218,0.35)]">
            {pluginKindLabel(pack.kind)}
          </span>
        </li>
      ))}
    </ul>
  )
}

function FeaturedBundle({
  bundle,
  onGet,
  busy,
}: {
  bundle: ForjaPluginBundleLive
  onGet: () => void
  busy: boolean
}) {
  return (
    <Reveal>
      <LiquidGlass className="relative overflow-hidden border-white/12 p-0">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_12%_0%,rgba(255,77,28,0.18),transparent_45%),radial-gradient(ellipse_at_90%_80%,rgba(28,231,131,0.12),transparent_50%)]"
        />
        <div className="relative grid gap-8 p-7 sm:p-10 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:gap-12 lg:p-12">
          <div>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-1.5 rounded-full border border-forja-flame/40 bg-forja-flame/14 px-3 py-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-forja-flame">
                <Sparkles className="size-3.5" aria-hidden />
                Recommended set
              </span>
              <span className="font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.4)]">
                {bundle.packs.length} packs
              </span>
            </div>
            <h3 className="font-disp text-[clamp(1.75rem,4vw,3rem)] uppercase leading-[0.92] tracking-[-0.03em] text-[#EDE6DA]">
              {bundle.name}
            </h3>
            {bundle.description.trim() ? (
              <p className="mt-4 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                {bundle.description}
              </p>
            ) : null}
            <button
              type="button"
              data-hover=""
              disabled={busy || bundle.packs.length === 0}
              onClick={onGet}
              className="btn-magnet mt-8 inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(255,77,28,0.28)] will-change-transform disabled:opacity-50 sm:text-xs"
            >
              Get this set
            </button>
          </div>
          <div>
            <p className="mb-3 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
              Includes
            </p>
            <BundlePackChips packs={bundle.packs} />
          </div>
        </div>
      </LiquidGlass>
    </Reveal>
  )
}

function SecondaryBundleCard({
  bundle,
  onGet,
  busy,
  delayMs,
}: {
  bundle: ForjaPluginBundleLive
  onGet: () => void
  busy: boolean
  delayMs: number
}) {
  return (
    <Reveal delayMs={delayMs} variant="scale">
      <LiquidGlass className="hover-lift flex h-full flex-col border-white/10 p-6 sm:p-7">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-forja-green">
              {bundle.packs.length} packs
            </p>
            <h3 className="mt-2 font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
              {bundle.name}
            </h3>
          </div>
          <Layers
            className="size-5 shrink-0 text-[rgba(237,230,218,0.35)]"
            aria-hidden
          />
        </div>
        {bundle.description.trim() ? (
          <p className="mt-3 flex-1 text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
            {bundle.description}
          </p>
        ) : (
          <div className="flex-1" />
        )}
        <div className="mt-4">
          <BundlePackChips packs={bundle.packs.slice(0, 6)} />
          {bundle.packs.length > 6 ? (
            <p className="mt-2 font-mono-ui text-[10px] text-[rgba(237,230,218,0.35)]">
              +{bundle.packs.length - 6} more
            </p>
          ) : null}
        </div>
        <button
          type="button"
          data-hover=""
          disabled={busy || bundle.packs.length === 0}
          onClick={onGet}
          className="mt-6 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-flame transition hover:text-[#EDE6DA] disabled:opacity-50"
        >
          Get this set →
        </button>
      </LiquidGlass>
    </Reveal>
  )
}

type PluginBundlesShowcaseProps = {
  packs: ForjaPluginPackLive[]
  bundles: ForjaPluginBundleMeta[]
  isLoading?: boolean
  error?: Error | null
}

export function PluginBundlesShowcase({
  packs,
  bundles,
  isLoading,
  error,
}: PluginBundlesShowcaseProps) {
  const live = useMemo(
    () => hydratePluginBundles(bundles, packs),
    [bundles, packs],
  )

  const batchInstall = usePluginBatchInstall({ catalogPacks: packs })

  const featured = live.find((b) => b.recommended) ?? live[0] ?? null
  const rest = featured
    ? live.filter((b) => b.id !== featured.id)
    : live

  if (error) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#121110] p-6 text-sm text-[rgba(237,230,218,0.6)]">
        {error.message}
      </div>
    )
  }

  if (isLoading && live.length === 0) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#121110]/60 p-10 text-center font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
        Loading sets…
      </div>
    )
  }

  if (live.length === 0) return null

  return (
    <>
      <div className="flex flex-col gap-6">
        {featured ? (
          <FeaturedBundle
            bundle={featured}
            busy={batchInstall.busy}
            onGet={() => batchInstall.openDialog(featured.packs)}
          />
        ) : null}
        {rest.length > 0 ? (
          <div
            className={cn(
              'grid gap-4',
              rest.length === 1 ? 'md:grid-cols-1' : 'md:grid-cols-2',
            )}
          >
            {rest.map((bundle, i) => (
              <SecondaryBundleCard
                key={bundle.id}
                bundle={bundle}
                delayMs={i * 80}
                busy={batchInstall.busy}
                onGet={() => batchInstall.openDialog(bundle.packs)}
              />
            ))}
          </div>
        ) : null}
      </div>

      <PluginBatchInstallDialog
        open={batchInstall.dialogOpen}
        packs={batchInstall.dialogPacks}
        installedPacks={batchInstall.installedPacks}
        initialSelection={batchInstall.initialSelection}
        busy={batchInstall.busy}
        onCancel={batchInstall.closeDialog}
        onConfirm={(items) => void batchInstall.confirmBatch(items)}
      />
    </>
  )
}
