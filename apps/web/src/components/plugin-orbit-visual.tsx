import { cn } from '@/lib/utils'

/** Outer ring only — clear hole for the center stack. */
const NODES = [
  { label: 'Providers', x: '50%', y: '8%', accent: 'brand' as const },
  { label: 'Live', x: '88%', y: '28%', accent: 'flame' as const },
  { label: 'Home', x: '88%', y: '72%', accent: 'brand' as const },
  { label: 'IPTV', x: '50%', y: '92%', accent: 'flame' as const },
  { label: 'Anime', x: '12%', y: '72%', accent: 'flame' as const },
  { label: 'Torrent', x: '12%', y: '28%', accent: 'brand' as const },
] as const

export function PluginOrbitVisual({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'relative mx-auto aspect-square w-full max-w-[min(100%,28rem)]',
        className,
      )}
      aria-hidden
    >
      <div className="absolute inset-[14%] rounded-full border border-white/[0.08] bg-[radial-gradient(circle_at_50%_40%,rgba(28,231,131,0.12),transparent_62%)]" />
      <div className="absolute inset-[24%] rounded-full border border-dashed border-white/[0.06]" />
      <div className="absolute inset-[36%] rounded-full border border-white/[0.04]" />

      {NODES.map((node) => (
        <div
          key={node.label}
          className="absolute z-[1] -translate-x-1/2 -translate-y-1/2"
          style={{ left: node.x, top: node.y }}
        >
          <div
            className={cn(
              'flex min-w-[4.25rem] flex-col items-center gap-1 rounded-xl border px-2.5 py-2 backdrop-blur-md',
              node.accent === 'flame'
                ? 'border-forja-flame/30 bg-forja-flame/10'
                : 'border-forja-green/30 bg-forja-green/10',
            )}
          >
            <span
              className={cn(
                'size-1.5 rounded-full',
                node.accent === 'flame' ? 'bg-forja-flame' : 'bg-forja-green',
              )}
            />
            <span className="font-mono-ui text-[8px] font-bold uppercase tracking-[0.12em] text-[#EDE6DA]/90">
              {node.label}
            </span>
          </div>
        </div>
      ))}

      {/* Center stack: badge + Community with real gap (no overlap) */}
      <div className="absolute left-1/2 top-1/2 z-[2] flex -translate-x-1/2 -translate-y-[58%] flex-col items-center">
        <div className="flex h-[4.5rem] w-[4.5rem] flex-col items-center justify-center rounded-2xl border border-forja-green/30 bg-[#0c0b0a] px-2 shadow-[0_0_40px_rgba(28,231,131,0.22)]">
          <span className="font-mono-ui text-center text-[9px] font-bold uppercase leading-tight tracking-[0.12em] text-forja-green">
            Your
            <br />
            pack
          </span>
        </div>
        <span className="mt-3 font-mono-ui text-[9px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.45)]">
          Community
        </span>
      </div>
    </div>
  )
}
