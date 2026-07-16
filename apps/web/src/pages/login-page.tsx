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
import { useAuth, AUTH_UNAVAILABLE_MESSAGE } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const BEATS = [
  {
    n: '01',
    title: 'Settings',
    line: 'Playback prefs, portals, and sources stay with your account.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Devices',
    line: 'Sign in on another screen and pick up the same setup.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Optional',
    line: 'You can download and watch without an account.',
    accent: 'brand' as const,
  },
]

function LoginStoryPanel() {
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
          Forja account
        </p>

        <h1 className="mt-5 font-disp text-[clamp(36px,7vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
          Sign in
          <br />
          <span className="font-serif-i normal-case text-flame">to sync.</span>
        </h1>

        <p className="mt-6 max-w-md font-disp text-[clamp(17px,2.4vw,26px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
          <span className="text-[#EDE6DA]">Keep settings aligned across your devices.</span>
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
      void navigate({ to: '/account/profiles' })
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
    void navigate({ to: '/account/profiles' })
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
              Your player settings, synced. Account is optional.
            </CardDescription>
          </CardHeader>

          <CardContent>
            <form onSubmit={onSubmit} className="space-y-5">
              {!configured ? (
                <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Web sign-in is not open yet. Download Forja - you can watch without an
                  account.
                </p>
              ) : null}

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  required={configured}
                  disabled={!configured}
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  required={configured}
                  disabled={!configured}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
                />
              </div>

              {error ? (
                <p
                  role="alert"
                  className="rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]"
                >
                  {error === AUTH_UNAVAILABLE_MESSAGE
                    ? 'Sign-in is not available right now. Download Forja and play without an account.'
                    : error}
                </p>
              ) : null}

              {configured ? (
                <Button
                  type="submit"
                  disabled={submitting || loading}
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Signing in…' : 'Sign in'}
                </Button>
              ) : (
                <Link
                  to="/download"
                  data-hover=""
                  className="btn-magnet inline-flex h-12 w-full items-center justify-center rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  Download Forja
                </Link>
              )}
            </form>

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
