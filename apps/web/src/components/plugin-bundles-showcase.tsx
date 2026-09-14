import { useMemo } from 'react'
import { PluginBatchInstallDialog } from '@/components/plugin-batch-install-dialog'
import { Reveal } from '@/components/reveal'
import { usePluginBatchInstall } from '@/hooks/use-plugin-batch-install'
import {
  hydratePluginBundles,
  type ForjaPluginBundleLive,
  type ForjaPluginBundleMeta,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import { cn } from '@/lib/utils'

function packShortName(name: string): string {
  return name.replace(/^ForjaHQ\s+/i, '').trim() || name
}

function BundleCard({
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
  const preview = bundle.packs.slice(0, 4)
  const extra = bundle.packs.length - preview.length

  return (
    <Reveal delayMs={delayMs} variant="scale">
      <article
        className={cn(
          'flex h-full flex-col rounded-xl border border-white/10 bg-[#121110] p-4 transition',
          'hover:border-white/20 hover:bg-[#161514]',
        )}
      >
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            {bundle.recommended ? (
              <p className="font-mono-ui text-[9px] uppercase tracking-[0.16em] text-forja-flame">
                Recommended
              </p>
            ) : (
              <p className="font-mono-ui text-[9px] uppercase tracking-[0.16em] text-forja-green">
                Set
              </p>
            )}
            <h3 className="font-disp mt-1 text-lg uppercase leading-tight tracking-tight text-[#EDE6DA]">
              {bundle.name}
            </h3>
          </div>
          <span className="shrink-0 font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.4)]">
            {bundle.packs.length}
          </span>
        </div>

        {bundle.description.trim() ? (
          <p className="mt-2 line-clamp-2 text-xs leading-relaxed text-[rgba(237,230,218,0.5)]">
            {bundle.description}
          </p>
        ) : null}

        <ul className="mt-3 flex flex-wrap gap-1.5">
          {preview.map((pack) => (
            <li
              key={pack.id}
              className="rounded-md border border-white/10 bg-white/[0.03] px-2 py-0.5 font-mono-ui text-[9px] uppercase tracking-[0.1em] text-[rgba(237,230,218,0.65)]"
            >
              {packShortName(pack.name)}
            </li>
          ))}
          {extra > 0 ? (
            <li className="px-1 font-mono-ui text-[9px] text-[rgba(237,230,218,0.35)]">
              +{extra}
            </li>
          ) : null}
        </ul>

        <button
          type="button"
          data-hover=""
          disabled={busy || bundle.packs.length === 0}
          onClick={onGet}
          className="mt-auto pt-4 font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA] disabled:opacity-50"
        >
          Get set
        </button>
      </article>
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

  const ordered = useMemo(() => {
    const rec = live.filter((b) => b.recommended)
    const rest = live.filter((b) => !b.recommended)
    return [...rec, ...rest]
  }, [live])

  if (error) {
    return (
      <div className="rounded-lg border border-white/10 bg-[#121110] p-4 text-sm text-[rgba(237,230,218,0.6)]">
        {error.message}
      </div>
    )
  }

  if (isLoading && live.length === 0) {
    return (
      <div className="rounded-lg border border-white/10 bg-[#121110]/60 p-6 text-center font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
        Loading sets…
      </div>
    )
  }

  if (live.length === 0) return null

  return (
    <>
      <div className="-mx-[5vw] overflow-x-auto px-[5vw] pb-2 [scrollbar-width:thin]">
        <div className="flex w-max gap-3">
          {ordered.map((bundle, i) => (
            <div key={bundle.id} className="w-[min(78vw,280px)] shrink-0 sm:w-[260px]">
              <BundleCard
                bundle={bundle}
                delayMs={i * 50}
                busy={batchInstall.busy}
                onGet={() => batchInstall.openDialog(bundle.packs)}
              />
            </div>
          ))}
        </div>
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
