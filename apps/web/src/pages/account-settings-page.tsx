import { Link } from '@tanstack/react-router'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { useUserSettings } from '@/hooks/use-user-setting'
import { REMOTE_SETTING_SECTIONS } from '@/lib/sync-domains'

export function AccountSettingsPage() {
  const settingsQuery = useUserSettings()
  const updatedByDomain = new Map(
    (settingsQuery.data ?? []).map((row) => [row.domain, row.updated_at]),
  )

  return (
    <AccountSettingsShell
      title="Remote settings"
      description="Manage settings that travel with your account. Device-only options like cache, navigation, and torrent tuning stay in the app."
      backTo="/account"
      backLabel="← Account"
    >
      <Card>
        <CardHeader>
          <CardTitle>Synced from the web or app</CardTitle>
          <CardDescription>
            Changes save to your Forja account and apply on the next sign-in or sync in the
            app.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {settingsQuery.isLoading && (
            <p className="text-sm text-forja-muted">Loading…</p>
          )}
          {settingsQuery.isError && (
            <p className="text-sm text-red-300">
              {settingsQuery.error instanceof Error
                ? settingsQuery.error.message
                : 'Failed to load settings'}
            </p>
          )}
          {REMOTE_SETTING_SECTIONS.map((section) => {
            const updatedAt = updatedByDomain.get(section.domain)
            return (
              <Link
                key={section.domain}
                to={section.href}
                className="block rounded-lg border border-forja-border bg-forja-surface/40 px-4 py-4 transition hover:border-forja-green/40 hover:bg-forja-surface/70"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="font-medium">{section.title}</p>
                    <p className="mt-1 text-sm text-forja-muted">{section.description}</p>
                  </div>
                  <span className="shrink-0 text-sm text-forja-green">Open →</span>
                </div>
                {updatedAt ? (
                  <p className="mt-2 text-xs text-forja-muted">
                    Last saved {new Date(updatedAt).toLocaleString()}
                  </p>
                ) : (
                  <p className="mt-2 text-xs text-forja-muted">Not configured yet</p>
                )}
              </Link>
            )
          })}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Stays on your device</CardTitle>
          <CardDescription>
            These are intentionally not synced — they depend on hardware, LAN services, or
            one-time cache.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ul className="list-inside list-disc space-y-1 text-sm text-forja-muted">
            <li>Shell navigation layout and default tab</li>
            <li>Torrent cache size, connections, and provider scores</li>
            <li>Debrid and indexer API keys (for now)</li>
            <li>Cache clears, downloaded updates, and WebView data</li>
            <li>Trakt / Simkl / MDBlist account linking</li>
          </ul>
        </CardContent>
      </Card>
    </AccountSettingsShell>
  )
}
