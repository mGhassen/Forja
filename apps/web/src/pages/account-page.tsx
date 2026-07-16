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
        <main className="mx-auto max-w-2xl px-6 py-16">
          <p className="font-display text-sm uppercase tracking-[0.3em] text-forja-green">
            Account
          </p>
          <h1 className="mt-3 font-display text-4xl tracking-tight">Forja account</h1>
          <Card className="mt-10">
            <CardHeader>
              <CardTitle>Logged in</CardTitle>
              <CardDescription>{user?.email}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-forja-muted">
                Cloud settings sync uses the same project as the Forja app. Domains
                are managed in the app; this page shows status.
              </p>
              <Separator />
              <div className="flex flex-wrap gap-3">
                <Button asChild>
                  <Link to="/account/settings">Settings sync</Link>
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
