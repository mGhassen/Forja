import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

type Tone = 'brand' | 'flame' | 'mixed' | 'cool' | 'warm'

const TONES: Record<Tone, string> = {
  brand:
    'radial-gradient(ellipse 70% 60% at 20% 30%, rgba(28,231,131,0.35), transparent 55%), radial-gradient(ellipse 55% 50% at 85% 70%, rgba(28,231,131,0.12), transparent 50%), linear-gradient(160deg, #0f0e0d 0%, #121110 45%, #0B0A0A 100%)',
  flame:
    'radial-gradient(ellipse 65% 55% at 80% 25%, rgba(255,77,28,0.38), transparent 55%), radial-gradient(ellipse 50% 45% at 15% 80%, rgba(255,138,61,0.16), transparent 50%), linear-gradient(160deg, #0f0e0d 0%, #141110 45%, #0B0A0A 100%)',
  mixed:
    'radial-gradient(ellipse 55% 50% at 15% 20%, rgba(28,231,131,0.28), transparent 50%), radial-gradient(ellipse 60% 55% at 90% 75%, rgba(255,77,28,0.28), transparent 55%), linear-gradient(145deg, #0B0A0A 0%, #121110 50%, #0f0e0d 100%)',
  cool:
    'radial-gradient(ellipse 80% 50% at 50% 0%, rgba(28,231,131,0.22), transparent 55%), radial-gradient(ellipse 40% 60% at 100% 50%, rgba(237,230,218,0.06), transparent 45%), linear-gradient(180deg, #10100f 0%, #0B0A0A 100%)',
  warm:
    'radial-gradient(ellipse 70% 55% at 0% 100%, rgba(255,77,28,0.3), transparent 55%), radial-gradient(ellipse 45% 40% at 70% 20%, rgba(255,138,61,0.14), transparent 50%), linear-gradient(200deg, #12100e 0%, #0B0A0A 100%)',
}

/** Abstract brand atmosphere — no film/series artwork. */
export function AbstractBackdrop({
  tone = 'mixed',
  className,
  children,
}: {
  tone?: Tone
  className?: string
  children?: ReactNode
}) {
  return (
    <div
      className={cn('relative overflow-hidden bg-[#0B0A0A]', className)}
      style={{ backgroundImage: TONES[tone] }}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-[0.35]"
        style={{
          backgroundImage:
            'repeating-linear-gradient(115deg, transparent 0, transparent 18px, rgba(237,230,218,0.03) 18px, rgba(237,230,218,0.03) 19px)',
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-8 -top-8 h-40 w-40 rounded-full border border-[rgba(237,230,218,0.08)] sm:h-56 sm:w-56"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -bottom-10 -left-6 h-28 w-28 rounded-full border border-[rgba(28,231,131,0.12)]"
      />
      {children}
    </div>
  )
}
