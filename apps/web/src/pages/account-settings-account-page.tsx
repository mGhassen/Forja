import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Fingerprint, Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth, type ForjaPasskey } from '@/hooks/use-auth'

export function AccountSettingsAccountPage() {
  const navigate = useNavigate()
  const {
    user,
    deleteAccount,
    listPasskeys,
    registerPasskey,
    deletePasskey,
  } = useAuth()
  const [confirmEmail, setConfirmEmail] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [showDelete, setShowDelete] = useState(false)

  const [passkeys, setPasskeys] = useState<ForjaPasskey[]>([])
  const [passkeysLoading, setPasskeysLoading] = useState(true)
  const [passkeysError, setPasskeysError] = useState<string | null>(null)
  const [registering, setRegistering] = useState(false)
  const [deletingPasskeyId, setDeletingPasskeyId] = useState<string | null>(
    null,
  )

  const refreshPasskeys = useCallback(async () => {
    setPasskeysLoading(true)
    setPasskeysError(null)
    const { error, passkeys: next } = await listPasskeys()
    setPasskeysLoading(false)
    if (error) {
      setPasskeysError(error)
      setPasskeys([])
      return
    }
    setPasskeys(next)
  }, [listPasskeys])

  useEffect(() => {
    void refreshPasskeys()
  }, [refreshPasskeys])

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

  async function onAddPasskey() {
    setPasskeysError(null)
    setRegistering(true)
    const { error } = await registerPasskey()
    setRegistering(false)
    if (error) {
      setPasskeysError(error)
      return
    }
    await refreshPasskeys()
  }

  async function onRemovePasskey(passkeyId: string) {
    setPasskeysError(null)
    setDeletingPasskeyId(passkeyId)
    const { error } = await deletePasskey(passkeyId)
    setDeletingPasskeyId(null)
    if (error) {
      setPasskeysError(error)
      return
    }
    await refreshPasskeys()
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
        label="Passkeys"
        description="Sign in with Touch ID, Face ID, Windows Hello, or a security key. Works on this site and on Forja for macOS and Windows."
      >
        <div className="space-y-4">
          <Button
            type="button"
            variant="outline"
            className="gap-2 border-[rgba(237,230,218,0.22)]"
            disabled={registering || passkeysLoading}
            onClick={() => void onAddPasskey()}
          >
            <Fingerprint className="size-4" />
            {registering ? 'Waiting for authenticator…' : 'Add passkey'}
          </Button>

          {passkeysLoading ? (
            <p className="text-sm text-[rgba(237,230,218,0.55)]">
              Loading passkeys…
            </p>
          ) : passkeys.length === 0 ? (
            <p className="text-sm text-[rgba(237,230,218,0.55)]">
              No passkeys yet. Add one to sign in without a password.
            </p>
          ) : (
            <ul className="space-y-2">
              {passkeys.map((passkey) => (
                <li
                  key={passkey.id}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-[rgba(237,230,218,0.12)] bg-forja-bg/40 px-3 py-2.5"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-[#EDE6DA]">
                      {passkey.friendlyName ?? 'Passkey'}
                    </p>
                    <p className="text-xs text-[rgba(237,230,218,0.45)]">
                      Added{' '}
                      {new Date(passkey.createdAt).toLocaleDateString(undefined, {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                      })}
                      {passkey.lastUsedAt
                        ? ` · Last used ${new Date(passkey.lastUsedAt).toLocaleDateString()}`
                        : null}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="text-red-300 hover:text-red-200"
                    disabled={deletingPasskeyId === passkey.id}
                    onClick={() => void onRemovePasskey(passkey.id)}
                  >
                    {deletingPasskeyId === passkey.id ? 'Removing…' : 'Remove'}
                  </Button>
                </li>
              ))}
            </ul>
          )}

          {passkeysError ? (
            <p role="alert" className="text-sm text-red-300">
              {passkeysError}
            </p>
          ) : null}
        </div>
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
                className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg"
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
