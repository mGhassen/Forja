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
import { Separator } from '@/components/ui/separator'
import { useAuth } from '@/hooks/use-auth'
import { RequireAuth } from '@/components/require-auth'

export function AccountPage() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-2xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <p className="font-display text-sm uppercase tracking-[0.3em] text-forja-green">
            Account
          </p>
          <h1 className="mt-3 font-display text-3xl tracking-tight sm:text-4xl">Forja account</h1>
          <Card className="mt-10">
            <CardHeader>
              <CardTitle>Logged in</CardTitle>
              <CardDescription>{user?.email}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-forja-muted">
                Manage IPTV portals, playback prefs, provider order, and Stremio addons
                from the web — the app pulls them when you sign in.
              </p>
              <Separator />
              <div className="flex flex-wrap gap-3">
                <Button asChild>
                  <Link to="/account/settings">Remote settings</Link>
                </Button>
                <Button
                  variant="secondary"
                  onClick={async () => {
                    await signOut()
                    void navigate({ to: '/' })
                  }}
                >
                  Log out
                </Button>
              </div>
            </CardContent>
          </Card>
        </main>
      </div>
    </RequireAuth>
  )
}
