import { cn } from '@/lib/utils'

type LanFluxBusProps = {
  className?: string
}

/** Open flux: Desktop torrent engine → TV play. No card chrome. */
export function LanFluxBus({ className }: LanFluxBusProps) {
  return (
    <div className={cn('w-full', className)} aria-hidden>
      <div className="flex flex-col items-stretch gap-8 sm:flex-row sm:items-center sm:gap-6">
        <div className="min-w-0 shrink-0 sm:w-[11rem]">
          <p className="font-disp text-[clamp(2rem,5vw,3rem)] uppercase leading-none tracking-tight text-forja-green">
            Desktop
          </p>
          <p className="mt-2 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.45)]">
            Downloads the torrent
          </p>
        </div>

        <div className="relative min-h-[3rem] flex-1">
          <div className="absolute left-0 right-0 top-1/2 h-px -translate-y-1/2 bg-[rgba(237,230,218,0.2)]" />
          <div className="lan-flux-beam absolute left-0 top-1/2 h-0.5 w-1/4 -translate-y-1/2 bg-gradient-to-r from-transparent via-forja-green to-transparent" />
          <span className="lan-flux-packet absolute top-1/2 size-2 -translate-y-1/2 rounded-full bg-forja-green shadow-[0_0_10px_rgba(28,231,131,0.85)]" />
          <span className="lan-flux-packet lan-flux-packet-delay absolute top-1/2 size-1.5 -translate-y-1/2 rounded-full bg-flame" />

          <p className="absolute inset-x-0 top-0 text-center font-mono-ui text-[9px] uppercase tracking-[0.2em] text-flame">
            Stream over Wi-Fi
          </p>
          <p className="absolute inset-x-0 bottom-0 text-center font-mono-ui text-[9px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.35)]">
            Magnet on TV · torrent on PC · play on TV
          </p>
        </div>

        <div className="min-w-0 shrink-0 text-left sm:w-[11rem] sm:text-right">
          <p className="font-disp text-[clamp(2rem,5vw,3rem)] uppercase leading-none tracking-tight text-[#EDE6DA]">
            TV
          </p>
          <p className="mt-2 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.45)]">
            Plays the stream
          </p>
        </div>
      </div>
    </div>
  )
}
