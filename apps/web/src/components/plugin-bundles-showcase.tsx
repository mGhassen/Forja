import { useMemo, useState } from 'react'
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

const PAGE_SIZE = 3

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
  const description = bundle.description.trim()

  return (
    <Reveal delayMs={delayMs} className="h-full" variant="scale">
      <article
        className={cn(
          'flex h-full min-h-[220px] flex-col rounded-xl border border-white/10 bg-[#121110] p-4 transition',
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
            <h3 className="font-disp mt-1 line-clamp-2 min-h-[2.5rem] text-lg uppercase leading-tight tracking-tight text-[#EDE6DA]">
              {bundle.name}
            </h3>
          </div>
          <span className="shrink-0 font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.4)]">
            {bundle.packs.length}
          </span>
        </div>

        <p className="mt-2 line-clamp-2 min-h-[2.5rem] text-xs leading-relaxed text-[rgba(237,230,218,0.5)]">
          {description || '\u00a0'}
        </p>

        <ul className="mt-3 flex min-h-[3.25rem] flex-wrap content-start gap-1.5">
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

  const pageCount = Math.max(1, Math.ceil(ordered.length / PAGE_SIZE))
  const [page, setPage] = useState(0)
  const safePage = Math.min(page, pageCount - 1)
  const pageItems = ordered.slice(
    safePage * PAGE_SIZE,
    safePage * PAGE_SIZE + PAGE_SIZE,
  )

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
      <div className="grid grid-cols-1 items-stretch gap-3 md:grid-cols-3">
        {pageItems.map((bundle, i) => (
          <div key={bundle.id} className="h-full min-w-0">
            <BundleCard
              bundle={bundle}
              delayMs={i * 50}
              busy={batchInstall.busy}
              onGet={() => batchInstall.openDialog(bundle.packs)}
            />
          </div>
        ))}
      </div>

      {pageCount > 1 ? (
        <div className="mt-6 flex items-center justify-center gap-3">
          <button
            type="button"
            data-hover=""
            disabled={safePage <= 0}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.55)] transition hover:text-forja-green disabled:opacity-30"
          >
            Prev
          </button>
          <div className="flex items-center gap-2">
            {Array.from({ length: pageCount }, (_, i) => (
              <button
                key={i}
                type="button"
                aria-label={`Page ${i + 1}`}
                aria-current={i === safePage ? 'page' : undefined}
                onClick={() => setPage(i)}
                className={cn(
                  'size-2 rounded-full transition',
                  i === safePage
                    ? 'bg-forja-green'
                    : 'bg-white/20 hover:bg-white/40',
                )}
              />
            ))}
          </div>
          <button
            type="button"
            data-hover=""
            disabled={safePage >= pageCount - 1}
            onClick={() => setPage((p) => Math.min(pageCount - 1, p + 1))}
            className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.55)] transition hover:text-forja-green disabled:opacity-30"
          >
            Next
          </button>
        </div>
      ) : null}

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
