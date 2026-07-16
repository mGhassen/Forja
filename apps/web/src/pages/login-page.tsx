import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const WORDS = ['stream', 'sync', 'live', 'play'] as const
const BEATS = [
  {
    n: '01',
    title: 'One player',
    line: 'Movies, series, anime, live TV — same controls, same calm.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Your sources',
    line: 'Playlists you connect. Guides inside the player. Nothing hosted here.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Every screen',
    line: 'Desk, couch, TV — pick up where you left off when you sign in.',
    accent: 'brand' as const,
  },
]

const MARQUEE = [
  'Playback',
  'Guides',
  'Live lists',
  'Subtitles',
  'Desk to TV',
  'No ads',
]

const CYCLE_MS = 3200

function LoginStoryPanel() {
  const [wordIndex, setWordIndex] = useState(0)
  const [reduced, setReduced] = useState(false)

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    setReduced(mq.matches)
    const onChange = () => setReduced(mq.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  useEffect(() => {
    if (reduced) return
    const id = window.setInterval(() => {
      setWordIndex((i) => (i + 1) % WORDS.length)
    }, CYCLE_MS)
    return () => window.clearInterval(id)
  }, [reduced])

  const word = WORDS[wordIndex]!

  return (
    <section className="relative flex min-h-[min(52vh,520px)] flex-col justify-center overflow-hidden border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-14 lg:min-h-0 lg:border-b-0 lg:border-r lg:py-20">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 70% 60% at 20% 40%, rgba(28,231,131,0.14), transparent 55%), radial-gradient(ellipse 55% 50% at 85% 75%, rgba(255,77,28,0.12), transparent 50%)',
        }}
      />
      <div
        aria-hidden
        className="animate-login-glow pointer-events-none absolute -top-24 right-[-10%] h-64 w-64 rounded-full bg-forja-green/20 blur-3xl"
      />

      <div className="hero-enter relative z-[1] max-w-xl">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.22em] text-forja-green">
          <span className="animate-live-dot mr-2 inline-block h-1.5 w-1.5 rounded-full bg-forja-green align-middle" />
          Creative player platform
        </p>

        <h1 className="mt-5 font-disp text-[clamp(36px,7vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
          Built to
          <br />
          <span
            key={word}
            className="animate-word-in font-serif-i inline-block normal-case text-flame"
          >
            {word}.
          </span>
        </h1>

        <p className="mt-6 max-w-md font-disp text-[clamp(17px,2.4vw,26px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
          Forja is a player — not a catalog pitch.
          <br />
          <span className="text-[#EDE6DA]">Sign in to sync settings across your screens.</span>
        </p>
      </div>

      <ul className="relative z-[1] mt-10 space-y-4">
        {BEATS.map((beat, i) => (
          <Reveal key={beat.n} delayMs={i * 90} variant="left">
            <li className="group flex gap-4 border-l-2 border-[rgba(237,230,218,0.12)] py-1 pl-4 transition-colors hover:border-forja-green/50">
              <span
                className={cn(
                  'font-mono-ui shrink-0 text-[11px] tracking-[0.16em]',
                  beat.accent === 'flame' ? 'text-flame' : 'text-brand',
                )}
              >
                {beat.n}
              </span>
              <div>
                <p className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA]">
                  {beat.title}
                </p>
                <p className="mt-1 text-sm leading-relaxed text-[rgba(237,230,218,0.48)]">
                  {beat.line}
                </p>
              </div>
            </li>
          </Reveal>
        ))}
      </ul>

      <div className="relative z-[1] mt-10 hidden overflow-hidden border border-[rgba(237,230,218,0.12)] bg-[#121110] py-4 sm:block">
        <div className="animate-marquee flex w-max gap-10 whitespace-nowrap px-4">
          {[...MARQUEE, ...MARQUEE].map((item, i) => (
            <span key={`${item}-${i}`} className="inline-flex items-center gap-3">
              <span className="font-serif-i text-xl text-[#EDE6DA]">{item}</span>
              <span className={i % 2 === 0 ? 'text-brand' : 'text-flame'}>✦</span>
            </span>
          ))}
        </div>
      </div>

      <div className="login-scanline relative z-[1] mt-8 hidden max-w-sm overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] p-5 lg:block">
        <div className="flex items-center gap-3">
          <div className="animate-play-pulse flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-forja-green text-[#0B0A0A]">
            <svg viewBox="0 0 24 24" className="h-5 w-5 fill-current" aria-hidden>
              <path d="M8 5v14l11-7z" />
            </svg>
          </div>
          <div className="min-w-0 flex-1">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green">
              Now playing
            </p>
            <p className="font-disp truncate text-lg uppercase tracking-tight">Your night</p>
          </div>
        </div>
        <div className="mt-4 h-1 overflow-hidden rounded-full bg-[rgba(237,230,218,0.12)]">
          <div
            className={cn(
              'h-full rounded-full bg-flame',
              reduced ? 'w-2/3' : 'animate-stream-progress',
            )}
          />
        </div>
        <p className="font-mono-ui mt-3 text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)]">
          Free · No ads · Player first
        </p>
      </div>
    </section>
  )
}

function LoginForm() {
  const navigate = useNavigate()
  const { signIn, user, loading, configured } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!loading && user) {
      void navigate({ to: '/account' })
    }
  }, [loading, user, navigate])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)
    const { error: signInError } = await signIn(email.trim(), password)
    setSubmitting(false)
    if (signInError) {
      setError(signInError)
      return
    }
    void navigate({ to: '/account' })
  }

  return (
    <section className="flex flex-1 items-center justify-center px-[5vw] py-14 lg:py-20">
      <Reveal variant="right" className="w-full max-w-md">
        <Card className="border-[rgba(237,230,218,0.16)] bg-[#121110]/90 shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)] backdrop-blur-sm">
          <CardHeader className="space-y-2 pb-2">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
              Welcome back
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              Log in
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Your player settings, synced. Download stays free — account is optional.
            </CardDescription>
          </CardHeader>

          <CardContent>
            {!configured ? (
              <div className="space-y-4">
                <p className="rounded-lg border border-flame/30 bg-flame/10 px-4 py-3 text-sm leading-relaxed text-[rgba(237,230,218,0.72)]">
                  Supabase is not configured on this site yet. Set{' '}
                  <code className="font-mono-ui text-xs text-forja-green">VITE_SUPABASE_URL</code>{' '}
                  and{' '}
                  <code className="font-mono-ui text-xs text-forja-green">
                    VITE_SUPABASE_ANON_KEY
                  </code>{' '}
                  in <code className="font-mono-ui text-xs">apps/web/.env</code>, or download and
                  play without an account.
                </p>
                <Link
                  to="/download"
                  data-hover=""
                  className="btn-magnet inline-flex w-full items-center justify-center rounded-full px-6 py-3.5 font-mono-ui text-xs font-bold uppercase tracking-[0.1em]"
                >
                  Download Forja
                </Link>
              </div>
            ) : (
              <form onSubmit={onSubmit} className="space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="email">Email</Label>
                  <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A]"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="password">Password</Label>
                  <Input
                    id="password"
                    type="password"
                    autoComplete="current-password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A]"
                  />
                </div>

                {error ? (
                  <p
                    role="alert"
                    className="rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]"
                  >
                    {error}
                  </p>
                ) : null}

                <Button
                  type="submit"
                  disabled={submitting || loading}
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Signing in…' : 'Sign in'}
                </Button>
              </form>
            )}

            <div className="mt-8 space-y-4 border-t border-[rgba(237,230,218,0.1)] pt-6">
              <p className="text-center text-sm text-[rgba(237,230,218,0.45)]">
                No account yet?{' '}
                <Link to="/signup" className="text-forja-green hover:text-flame hover:underline">
                  Create one
                </Link>
              </p>
              <Link
                to="/download"
                className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]"
              >
                Or download and play without signing in →
              </Link>
            </div>
          </CardContent>
        </Card>
      </Reveal>
    </section>
  )
}

export function LoginPage() {
  return (
    <div className="film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader solid />

      <main className="relative mx-auto grid min-h-screen max-w-[1400px] lg:grid-cols-[1.05fr_0.95fr] lg:pt-[4.5rem]">
        <LoginStoryPanel />
        <LoginForm />
      </main>
    </div>
  )
}
