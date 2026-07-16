import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
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

export function SignupPage() {
  const { signUp } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setPending(true)
    setError(null)
    setMessage(null)
    const result = await signUp(email.trim(), password)
    setPending(false)
    if (result.error) {
      setError(result.error)
      return
    }
    setMessage('Account ready. Confirm by email if asked, then log in.')
    void navigate({ to: '/account' })
  }

  return (
    <div className="min-h-screen">
      <SiteHeader solid />
      <main className="mx-auto flex max-w-md flex-col px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
            <CardDescription>
              Optional — syncs settings across Forja devices.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form className="space-y-4" onSubmit={onSubmit}>
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="new-password"
                  required
                  minLength={8}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
              {error && <p className="text-sm text-red-300">{error}</p>}
              {message && <p className="text-sm text-forja-green">{message}</p>}
              <Button type="submit" className="w-full" disabled={pending}>
                {pending ? 'Saving…' : 'Continue'}
              </Button>
            </form>
            <p className="mt-4 text-center text-sm text-forja-muted">
              Already registered?{' '}
              <Link to="/login" className="text-forja-green hover:underline">
                Log in
              </Link>
            </p>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}
