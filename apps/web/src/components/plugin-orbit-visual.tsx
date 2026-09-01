import { cn } from '@/lib/utils'

const NODES = [
  { label: 'Providers', x: '50%', y: '8%', accent: 'brand' as const, delay: '0s' },
  { label: 'Live', x: '88%', y: '32%', accent: 'flame' as const, delay: '0.4s' },
  { label: 'Home', x: '78%', y: '72%', accent: 'brand' as const, delay: '0.8s' },
  { label: 'Anime', x: '22%', y: '78%', accent: 'flame' as const, delay: '1.2s' },
  { label: 'Torrent', x: '8%', y: '38%', accent: 'brand' as const, delay: '1.6s' },
  { label: 'IPTV', x: '50%', y: '50%', accent: 'flame' as const, delay: '2s' },
]

export function PluginOrbitVisual({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'relative mx-auto aspect-square w-full max-w-[min(100%,28rem)]',
        className,
      )}
      aria-hidden
    >
      <div className="absolute inset-[12%] rounded-full border border-white/[0.08] bg-[radial-gradient(circle_at_50%_40%,rgba(28,231,131,0.12),transparent_62%)] shadow-[inset_0_0_80px_rgba(28,231,131,0.06)]" />
      <div className="absolute inset-[22%] animate-[spin_48s_linear_infinite] rounded-full border border-dashed border-white/[0.06]" />
      <div className="absolute inset-[34%] animate-[spin_36s_linear_infinite_reverse] rounded-full border border-white/[0.04]" />

      <svg
        className="absolute inset-0 h-full w-full opacity-40"
        viewBox="0 0 100 100"
        fill="none"
      >
        <circle cx="50" cy="50" r="38" stroke="rgba(28,231,131,0.15)" strokeWidth="0.3" />
        <path
          d="M50 12 L88 32 L78 72 L22 78 L8 38 Z"
          stroke="rgba(255,77,28,0.2)"
          strokeWidth="0.35"
          strokeDasharray="2 2"
        />
      </svg>

      {NODES.map((node) => (
        <div
          key={node.label}
          className="absolute -translate-x-1/2 -translate-y-1/2 animate-float"
          style={{
            left: node.x,
            top: node.y,
            animationDelay: node.delay,
          }}
        >
          <div
            className={cn(
              'relative flex min-w-[4.5rem] flex-col items-center gap-1.5 rounded-2xl border px-3 py-2.5 backdrop-blur-md',
              node.accent === 'flame'
                ? 'border-forja-flame/30 bg-forja-flame/10 shadow-[0_0_28px_rgba(255,77,28,0.18)]'
                : 'border-forja-green/30 bg-forja-green/10 shadow-[0_0_28px_rgba(28,231,131,0.18)]',
            )}
          >
            <span
              className={cn(
                'size-2 rounded-full',
                node.accent === 'flame' ? 'bg-forja-flame' : 'bg-forja-green',
              )}
            />
            <span className="font-mono-ui text-[9px] font-bold uppercase tracking-[0.14em] text-[#EDE6DA]/90">
              {node.label}
            </span>
          </div>
        </div>
      ))}

      <div className="absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-2">
        <div className="flex size-16 items-center justify-center rounded-2xl border border-forja-green/25 bg-[#121110]/90 shadow-[0_20px_60px_-20px_rgba(28,231,131,0.25)] backdrop-blur-xl">
          <span className="font-mono-ui text-[9px] font-bold uppercase leading-tight tracking-[0.14em] text-forja-green">
            Your
            <br />
            pack
          </span>
        </div>
        <span className="font-mono-ui text-[9px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.45)]">
          Community
        </span>
      </div>
    </div>
  )
}
