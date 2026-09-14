import { cn } from '@/lib/utils'

type LanFluxBusProps = {
  className?: string
}

export function LanFluxBus({ className }: LanFluxBusProps) {
  return (
    <div
      className={cn(
        'relative overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.12)] bg-[#121110] px-5 py-8 sm:px-8 sm:py-10',
        className,
      )}
      aria-hidden
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_20%_50%,rgba(28,231,131,0.08),transparent_55%),radial-gradient(ellipse_at_80%_50%,rgba(255,77,28,0.06),transparent_55%)]" />

      <div className="relative grid items-center gap-6 sm:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)_minmax(0,1fr)] sm:gap-4">
        <div className="flex flex-col items-center text-center sm:items-start sm:text-left">
          <div className="flex size-14 items-center justify-center rounded-xl border border-forja-green/35 bg-forja-green/10 shadow-[0_0_28px_rgba(28,231,131,0.18)] sm:size-16">
            <span className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green">
              PC
            </span>
          </div>
          <p className="font-disp mt-4 text-2xl uppercase tracking-tight text-forja-green sm:text-3xl">
            Desktop
          </p>
          <p className="mt-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.45)]">
            Torrent engine
          </p>
        </div>

        <div className="relative flex min-h-[4.5rem] flex-col justify-center">
          <p className="mb-3 text-center font-mono-ui text-[9px] uppercase tracking-[0.2em] text-flame">
            Passthrough bus
          </p>

          <div className="relative h-3 rounded-full border border-white/10 bg-black/40">
            <div className="lan-flux-rail absolute inset-y-0 left-0 right-0 overflow-hidden rounded-full">
              <div className="lan-flux-beam absolute inset-y-0 w-1/3 bg-gradient-to-r from-transparent via-forja-green/80 to-transparent" />
            </div>
            <span className="lan-flux-packet absolute top-1/2 size-2.5 -translate-y-1/2 rounded-full bg-forja-green shadow-[0_0_12px_rgba(28,231,131,0.9)]" />
            <span className="lan-flux-packet lan-flux-packet-delay absolute top-1/2 size-2 -translate-y-1/2 rounded-full bg-flame shadow-[0_0_10px_rgba(255,77,28,0.8)]" />
            <span className="lan-flux-packet lan-flux-packet-delay-2 absolute top-1/2 size-1.5 -translate-y-1/2 rounded-full bg-[#EDE6DA]" />
          </div>

          <div className="mt-3 flex justify-between font-mono-ui text-[9px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.35)]">
            <span>Magnet</span>
            <span>Stream</span>
            <span>Play</span>
          </div>
        </div>

        <div className="flex flex-col items-center text-center sm:items-end sm:text-right">
          <div className="flex size-14 items-center justify-center rounded-xl border border-forja-flame/35 bg-forja-flame/10 shadow-[0_0_28px_rgba(255,77,28,0.16)] sm:size-16">
            <span className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-flame">
              TV
            </span>
          </div>
          <p className="font-disp mt-4 text-2xl uppercase tracking-tight text-[#EDE6DA] sm:text-3xl">
            TV
          </p>
          <p className="mt-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.45)]">
            Native player
          </p>
        </div>
      </div>
    </div>
  )
}
