import { useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'

export function AccountSettingsAccountPage() {
  const navigate = useNavigate()
  const { user, deleteAccount } = useAuth()
  const [confirmEmail, setConfirmEmail] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [showDelete, setShowDelete] = useState(false)

  async function onDelete() {
    setDeleteError(null)
    setDeleting(true)
    const { error } = await deleteAccount(confirmEmail.trim())
    setDeleting(false)
    if (error) {
      setDeleteError(error)
      return
    }
    void navigate({ to: '/' })
  }

  return (
    <AccountSettingsShell
      section="account"
      title="Your account"
      description="Manage the Forja cloud account used for sync. Profile settings (IPTV, playback, navigation, Stremio) stay under Profile in the sidebar."
    >
      <SettingsSection
        label="Signed in"
        description="This email is shared across the web portal and the Forja app."
      >
        <p className="break-all text-base text-[#EDE6DA]">{user?.email ?? '—'}</p>
      </SettingsSection>

      <SettingsSection
        label="Delete account"
        description="Permanently removes this account and every synced profile and setting. The Forja app still works without an account."
      >
        {!showDelete ? (
          <Button
            type="button"
            variant="outline"
            className="gap-2 border-red-400/40 text-red-300 hover:border-red-300/60 hover:text-red-200"
            onClick={() => setShowDelete(true)}
          >
            <Trash2 className="size-4" />
            Delete account…
          </Button>
        ) : (
          <div className="space-y-4 rounded-lg border border-red-400/35 bg-red-500/5 p-4">
            <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.75)]">
              Type <span className="font-medium text-[#EDE6DA]">{user?.email}</span>{' '}
              to confirm. This cannot be undone.
            </p>
            <div className="space-y-2">
              <Label htmlFor="confirm-delete-email">Confirm email</Label>
              <Input
                id="confirm-delete-email"
                type="email"
                autoComplete="off"
                value={confirmEmail}
                onChange={(e) => setConfirmEmail(e.target.value)}
                placeholder={user?.email ?? 'you@example.com'}
                className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A]"
              />
            </div>
            {deleteError ? (
              <p role="alert" className="text-sm text-red-300">
                {deleteError}
              </p>
            ) : null}
            <div className="flex flex-wrap gap-3">
              <Button
                type="button"
                variant="outline"
                className="border-red-400/50 bg-red-500/15 text-red-200 hover:bg-red-500/25"
                disabled={
                  deleting ||
                  !user?.email ||
                  confirmEmail.trim().toLowerCase() !==
                    user.email.toLowerCase()
                }
                onClick={() => void onDelete()}
              >
                {deleting ? 'Deleting…' : 'Permanently delete'}
              </Button>
              <Button
                type="button"
                variant="ghost"
                disabled={deleting}
                onClick={() => {
                  setShowDelete(false)
                  setConfirmEmail('')
                  setDeleteError(null)
                }}
              >
                Cancel
              </Button>
            </div>
          </div>
        )}
      </SettingsSection>
    </AccountSettingsShell>
  )
}
