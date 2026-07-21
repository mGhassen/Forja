import { useEffect, useState } from 'react'
import { Check, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  closeDesktopHandoffWindow,
  focusDesktopApp,
} from '@/lib/desktop-auth-callback'

const CLOSE_AFTER_SECONDS = 10

/**
 * In-card confirmation after desktop Web login / signup handoff.
 * Renders inside the existing login/signup LiquidGlass card — not a new page.
 */
export function DesktopAuthDone({
  phase = 'done',
  title = 'Signed in to Forja',
  body = 'The desktop app has its own session. This browser stays signed in — you can return to Forja now.',
  loadingLabel = 'Connecting to Forja…',
}: {
  phase?: 'loading' | 'done'
  title?: string
  body?: string
  loadingLabel?: string
}) {
  const [secondsLeft, setSecondsLeft] = useState(CLOSE_AFTER_SECONDS)
  const [closeBlocked, setCloseBlocked] = useState(false)

  useEffect(() => {
    if (phase !== 'done') return
    const onPageHide = () => {
      void focusDesktopApp()
    }
    window.addEventListener('pagehide', onPageHide)
    return () => window.removeEventListener('pagehide', onPageHide)
  }, [phase])

  useEffect(() => {
    if (phase !== 'done') return
    if (secondsLeft <= 0) {
      closeDesktopHandoffWindow()
      // Auto path has no user gesture — close usually fails; confirm after a tick.
      const id = window.setTimeout(() => {
        if (!window.closed) setCloseBlocked(true)
      }, 50)
      return () => window.clearTimeout(id)
    }
    const id = window.setTimeout(() => {
      setSecondsLeft((s) => s - 1)
    }, 1000)
    return () => window.clearTimeout(id)
  }, [phase, secondsLeft])

  function onCloseNow() {
    closeDesktopHandoffWindow()
    // close() is sync but window.closed can lag a frame; don't flash the
    // "could not close" copy before the browser has a chance to shut the tab.
    window.setTimeout(() => {
      if (!window.closed) setCloseBlocked(true)
    }, 50)
  }

  if (phase === 'loading') {
    return (
      <div className="desktop-auth-phase flex flex-col items-center px-2 py-8 text-center">
        <div
          className="mb-8 flex size-14 items-center justify-center rounded-full border border-forja-green/30 bg-forja-green/10"
          aria-hidden
        >
          <Loader2 className="size-7 animate-spin text-forja-green" />
        </div>
        <p className="font-mono-ui mb-3 text-[10px] uppercase tracking-[0.22em] text-forja-green">
          Desktop handoff
        </p>
        <h2 className="font-disp text-3xl font-extrabold uppercase tracking-tight">
          Connecting…
        </h2>
        <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
          {loadingLabel}
        </p>
      </div>
    )
  }

  return (
    <div className="desktop-auth-phase flex flex-col items-center px-2 py-4 text-center">
      <div
        className="mb-8 flex size-14 items-center justify-center rounded-full border border-forja-green/40 bg-forja-green/10"
        aria-hidden
      >
        <Check className="size-7 text-forja-green" strokeWidth={2.5} />
      </div>
      <p className="font-mono-ui mb-3 text-[10px] uppercase tracking-[0.22em] text-forja-green">
        Desktop handoff
      </p>
      <h2 className="font-disp text-3xl font-extrabold uppercase tracking-tight sm:text-4xl">
        {title}
      </h2>
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
          <span className="tabular-nums text-[#EDE6DA]">{secondsLeft}</span>s
        </p>
      )}

      <Button
        type="button"
        onClick={onCloseNow}
        className="mt-8 h-12 min-w-48 rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
      >
        Close tab
      </Button>
    </div>
  )
}
