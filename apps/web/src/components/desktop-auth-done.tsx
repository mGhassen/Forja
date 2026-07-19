import { useEffect, useState } from 'react'
import { Check } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { closeDesktopHandoffWindow } from '@/lib/desktop-auth-callback'

const CLOSE_AFTER_SECONDS = 10

/**
 * Full-viewport confirmation after desktop Web login / signup handoff.
 * Hides the auth story panel chrome; countdown then best-effort tab close.
 */
export function DesktopAuthDone({
  title = 'Signed in to Forja',
  body = 'The desktop app has its own session. This browser stays signed in — you can return to Forja now.',
}: {
  title?: string
  body?: string
}) {
  const [secondsLeft, setSecondsLeft] = useState(CLOSE_AFTER_SECONDS)
  const [closeBlocked, setCloseBlocked] = useState(false)

  useEffect(() => {
    if (secondsLeft <= 0) {
      closeDesktopHandoffWindow()
      // Browsers often block window.close() for tabs the OS opened.
      const stillOpen = !window.closed
      if (stillOpen) setCloseBlocked(true)
      return
    }
    const id = window.setTimeout(() => {
      setSecondsLeft((s) => s - 1)
    }, 1000)
    return () => window.clearTimeout(id)
  }, [secondsLeft])

  function onCloseNow() {
    closeDesktopHandoffWindow()
    if (!window.closed) setCloseBlocked(true)
  }

  return (
    <div className="fixed inset-0 z-[80] flex items-center justify-center bg-forja-bg px-6 text-[#EDE6DA]">
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.35]"
        aria-hidden
        style={{
          background:
            'radial-gradient(ellipse 70% 50% at 50% 40%, rgba(28, 231, 131, 0.12), transparent 70%)',
        }}
      />
      <main className="relative z-10 flex w-full max-w-md flex-col items-center text-center">
        <div
          className="mb-8 flex size-14 items-center justify-center rounded-full border border-forja-green/40 bg-forja-green/10"
          aria-hidden
        >
          <Check className="size-7 text-forja-green" strokeWidth={2.5} />
        </div>
        <p className="font-mono-ui mb-3 text-[10px] uppercase tracking-[0.22em] text-forja-green">
          Desktop handoff
        </p>
        <h1 className="font-disp text-3xl font-extrabold uppercase tracking-tight sm:text-4xl">
          {title}
        </h1>
        <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
          {body}
        </p>

        {closeBlocked ? (
          <p className="mt-8 text-sm leading-relaxed text-[rgba(237,230,218,0.7)]">
            This tab could not close automatically. You can close it now and
            return to Forja.
          </p>
        ) : (
          <p className="mt-8 font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
            Closing in{' '}
            <span className="tabular-nums text-[#EDE6DA]">{secondsLeft}</span>
            s
          </p>
        )}

        <Button
          type="button"
          onClick={onCloseNow}
          className="mt-8 h-12 min-w-[12rem] rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
        >
          Close tab
        </Button>
      </main>
    </div>
  )
}
