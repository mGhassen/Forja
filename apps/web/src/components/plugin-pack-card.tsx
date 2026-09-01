import { useState } from 'react'
import {
  Check,
  Copy,
  LayoutGrid,
  Magnet,
  SatelliteDish,
  Trophy,
  Zap,
  type LucideIcon,
} from 'lucide-react'
import { AddToForjaButton } from '@/components/add-to-forja-button'
import { LiquidGlass } from '@/components/liquid-glass'
import type {
  ForjaPluginKind,
  ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import { pluginKindLabel } from '@/lib/forja-plugin-catalog'
import { cn } from '@/lib/utils'

const KIND_ICONS: Record<ForjaPluginKind, LucideIcon> = {
  providers: Zap,
  live: Trophy,
  hubs: LayoutGrid,
  torrent: Magnet,
  iptv: SatelliteDish,
}

type PluginPackCardProps = {
  pack: ForjaPluginPackLive
  index?: number
}

export function PluginPackCard({ pack, index = 0 }: PluginPackCardProps) {
  const [copied, setCopied] = useState(false)
  const Icon = KIND_ICONS[pack.kind]
  const isFlame = pack.accent === 'flame'

  async function copyManifest() {
    try {
      await navigator.clipboard.writeText(pack.manifestUrl)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  return (
    <article
      className={cn(
        'hover-lift group relative h-full overflow-hidden rounded-2xl transition duration-500',
        'border border-[rgba(237,230,218,0.12)] bg-[#121110]',
        isFlame
          ? 'hover:border-forja-flame/35 hover:shadow-[0_24px_80px_-24px_rgba(255,77,28,0.25)]'
          : 'hover:border-forja-green/35 hover:shadow-[0_24px_80px_-24px_rgba(28,231,131,0.22)]',
      )}
      style={{ transitionDelay: `${index * 30}ms` }}
    >
      <div
        aria-hidden
        className={cn(
          'pointer-events-none absolute inset-x-0 top-0 h-px opacity-60 transition-opacity group-hover:opacity-100',
          isFlame
            ? 'bg-linear-to-r from-transparent via-forja-flame/80 to-transparent'
            : 'bg-linear-to-r from-transparent via-forja-green/80 to-transparent',
        )}
      />

      <div
        aria-hidden
        className={cn(
          'pointer-events-none absolute -right-8 -top-8 size-32 rounded-full blur-3xl transition-opacity duration-500 opacity-0 group-hover:opacity-100',
          isFlame ? 'bg-forja-flame/20' : 'bg-forja-green/20',
        )}
      />

      <div className="relative flex h-full flex-col p-6 sm:p-7">
        <div className="flex items-start justify-between gap-4">
          <div
            className={cn(
              'flex size-12 shrink-0 items-center justify-center rounded-xl border',
              isFlame
                ? 'border-forja-flame/25 bg-forja-flame/10 text-forja-flame'
                : 'border-forja-green/25 bg-forja-green/10 text-forja-green',
            )}
          >
            <Icon className="size-5" strokeWidth={2.25} aria-hidden />
          </div>
          {pack.version ? (
            <span className="rounded-full border border-white/10 bg-black/30 px-2.5 py-1 font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.55)]">
              v{pack.version}
            </span>
          ) : null}
        </div>

        <div className="mt-5 space-y-2">
          <p
            className={cn(
              'font-mono-ui text-[10px] font-bold uppercase tracking-[0.18em]',
              isFlame ? 'text-forja-flame' : 'text-forja-green',
            )}
          >
            {pluginKindLabel(pack.kind)}
          </p>
          <h3 className="font-disp text-[clamp(1.35rem,3vw,1.65rem)] uppercase leading-[0.95] tracking-[-0.03em] text-[#EDE6DA]">
            {pack.name.replace(/^ForjaHQ\s+/i, '')}
          </h3>
          <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.62)]">
            {pack.description}
          </p>
        </div>

        <div className="mt-5 flex flex-wrap gap-2">
          {pack.pluginCount != null ? (
            <span className="rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.5)]">
              {pack.pluginCount} plugins
            </span>
          ) : null}
          <span className="rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.5)]">
            Remote
          </span>
        </div>

        <div className="mt-auto flex flex-col gap-4 pt-6">
          <button
            type="button"
            onClick={() => void copyManifest()}
            className="inline-flex w-fit items-center gap-2 rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.45)] transition hover:border-white/20 hover:text-[#EDE6DA]"
          >
            {copied ? (
              <Check className="size-3.5 text-forja-green" aria-hidden />
            ) : (
              <Copy className="size-3.5" aria-hidden />
            )}
            {copied ? 'Copied' : 'Copy manifest URL'}
          </button>
          <AddToForjaButton pack={pack} variant="magnet" className="w-full" />
        </div>
      </div>
    </article>
  )
}

export function PluginPackCardSkeleton() {
  return (
    <LiquidGlass className="h-full min-h-[320px] animate-pulse border-white/10 bg-white/[0.03] p-7">
      <div className="size-12 rounded-xl bg-white/10" />
      <div className="mt-5 h-3 w-24 rounded bg-white/10" />
      <div className="mt-3 h-8 w-3/4 rounded bg-white/10" />
      <div className="mt-3 space-y-2">
        <div className="h-3 w-full rounded bg-white/5" />
        <div className="h-3 w-5/6 rounded bg-white/5" />
      </div>
      <div className="mt-auto flex gap-2 pt-10">
        <div className="h-8 w-20 rounded-full bg-white/10" />
        <div className="h-8 w-16 rounded-full bg-white/10" />
      </div>
    </LiquidGlass>
  )
}
