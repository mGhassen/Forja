import { cn } from '@/lib/utils'

const NODES = [
  { label: 'Providers', x: '50%', y: '7%', accent: 'brand' as const },
  { label: 'Live', x: '90%', y: '28%', accent: 'flame' as const },
  { label: 'Home', x: '90%', y: '72%', accent: 'brand' as const },
  { label: 'IPTV', x: '50%', y: '93%', accent: 'flame' as const },
  { label: 'Anime', x: '10%', y: '72%', accent: 'flame' as const },
  { label: 'Torrent', x: '10%', y: '28%', accent: 'brand' as const },
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
      <div className="absolute inset-[12%] rounded-full border border-white/[0.07]" />
      <div className="absolute inset-[26%] rounded-full border border-dashed border-white/[0.05]" />
      <div className="absolute inset-[40%] rounded-full border border-white/[0.04]" />
      <div className="absolute inset-[46%] rounded-full bg-[radial-gradient(circle,rgba(28,231,131,0.14),transparent_70%)]" />

      <svg
        className="absolute inset-0 h-full w-full opacity-30"
        viewBox="0 0 100 100"
        fill="none"
      >
        <path
          d="M50 7 L90 28 L90 72 L50 93 L10 72 L10 28 Z"
          stroke="rgba(237,230,218,0.35)"
          strokeWidth="0.25"
          strokeDasharray="1.2 1.8"
        />
      </svg>

      {NODES.map((node) => (
        <div
          key={node.label}
          className="absolute z-[1] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-1.5"
          style={{ left: node.x, top: node.y }}
        >
          <span
            className={cn(
              'size-1.5 rounded-full',
              node.accent === 'flame'
                ? 'bg-forja-flame shadow-[0_0_10px_rgba(255,77,28,0.7)]'
                : 'bg-forja-green shadow-[0_0_10px_rgba(28,231,131,0.7)]',
            )}
          />
          <span
            className={cn(
              'font-mono-ui text-[10px] uppercase tracking-[0.16em]',
              node.accent === 'flame' ? 'text-flame/80' : 'text-forja-green/80',
            )}
          >
            {node.label}
          </span>
        </div>
      ))}

      <div className="absolute left-1/2 top-1/2 z-[2] -translate-x-1/2 -translate-y-1/2 text-center">
        <p className="font-serif-i text-2xl leading-none text-[#EDE6DA] sm:text-3xl">
          Forja
        </p>
      </div>
    </div>
  )
}
