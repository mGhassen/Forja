import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Fingerprint, Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  useAuth,
  type ForjaMfaFactor,
  type ForjaPasskey,
} from '@/hooks/use-auth'
import { authConfig } from '@forja/auth'

export function AccountSettingsAccountPage() {
  const navigate = useNavigate()
  const {
    user,
    deleteAccount,
    listPasskeys,
    registerPasskey,
    deletePasskey,
    listMfaFactors,
    enrollMfaTotp,
    challengeAndVerifyMfa,
    unenrollMfa,
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

  const [mfaFactors, setMfaFactors] = useState<ForjaMfaFactor[]>([])
  const [mfaLoading, setMfaLoading] = useState(true)
  const [mfaError, setMfaError] = useState<string | null>(null)
  const [enrollFactorId, setEnrollFactorId] = useState<string | null>(null)
  const [enrollQr, setEnrollQr] = useState<string | null>(null)
  const [enrollSecret, setEnrollSecret] = useState<string | null>(null)
  const [enrollCode, setEnrollCode] = useState('')
  const [mfaBusy, setMfaBusy] = useState(false)
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

  const refreshMfa = useCallback(async () => {
    if (!authConfig.mfaTotp) {
      setMfaLoading(false)
      return
    }
    setMfaLoading(true)
    setMfaError(null)
    const { error, factors } = await listMfaFactors()
    setMfaLoading(false)
    if (error) {
      setMfaError(error)
      setMfaFactors([])
      return
    }
    setMfaFactors(factors)
  }, [listMfaFactors])

  useEffect(() => {
    void refreshPasskeys()
  }, [refreshPasskeys])

  useEffect(() => {
    void refreshMfa()
  }, [refreshMfa])

  async function onStartMfaEnroll() {
    setMfaError(null)
    setMfaBusy(true)
    const result = await enrollMfaTotp()
    setMfaBusy(false)
    if (result.error) {
      setMfaError(result.error)
      return
    }
    setEnrollFactorId(result.factorId)
    setEnrollQr(result.qrCode)
    setEnrollSecret(result.secret)
    setEnrollCode('')
  }

  async function onConfirmMfaEnroll() {
    if (!enrollFactorId) return
    setMfaError(null)
    setMfaBusy(true)
    const { error } = await challengeAndVerifyMfa(enrollFactorId, enrollCode)
    setMfaBusy(false)
    if (error) {
      setMfaError(error)
      return
    }
    setEnrollFactorId(null)
    setEnrollQr(null)
    setEnrollSecret(null)
    setEnrollCode('')
    await refreshMfa()
  }

  async function onRemoveMfa(factorId: string) {
    setMfaError(null)
    setMfaBusy(true)
    const { error } = await unenrollMfa(factorId)
    setMfaBusy(false)
    if (error) {
      setMfaError(error)
      return
    }
    await refreshMfa()
  }

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
      description="Manage the Forja cloud account used for sync. Profile settings (Addons, Forja Packs, Features) stay under Profile in the sidebar."
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

      {authConfig.mfaTotp ? (
        <SettingsSection
          label="Authenticator (TOTP)"
          description="Optional second factor. After you enable it, every sign-in asks for a 6-digit code (including Web login for the desktop app)."
        >
          <div className="space-y-4">
            {mfaLoading ? (
              <p className="text-sm text-[rgba(237,230,218,0.55)]">
                Loading authenticator…
              </p>
            ) : mfaFactors.some((f) => f.status === 'verified') ? (
              <ul className="space-y-2">
                {mfaFactors
                  .filter((f) => f.status === 'verified')
                  .map((factor) => (
                    <li
                      key={factor.id}
                      className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-[rgba(237,230,218,0.12)] bg-forja-bg/40 px-3 py-2.5"
                    >
                      <p className="text-sm text-[#EDE6DA]">
                        {factor.friendlyName ?? 'Authenticator app'}
                      </p>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-300 hover:text-red-200"
                        disabled={mfaBusy}
                        onClick={() => void onRemoveMfa(factor.id)}
                      >
                        Remove
                      </Button>
                    </li>
                  ))}
              </ul>
            ) : enrollFactorId && enrollQr ? (
              <div className="space-y-4 rounded-lg border border-[rgba(237,230,218,0.12)] bg-forja-bg/40 p-4">
                <p className="text-sm text-[rgba(237,230,218,0.7)]">
                  Scan this QR with your authenticator app, then enter the code
                  to finish setup.
                </p>
                <img
                  src={enrollQr}
                  alt="Authenticator QR code"
                  className="mx-auto size-40 rounded-lg bg-white p-2"
                />
                {enrollSecret ? (
                  <p className="break-all text-center font-mono-ui text-xs text-[rgba(237,230,218,0.55)]">
                    {enrollSecret}
                  </p>
                ) : null}
                <div className="space-y-2">
                  <Label htmlFor="mfa-enroll-code">Confirm code</Label>
                  <Input
                    id="mfa-enroll-code"
                    inputMode="numeric"
                    maxLength={6}
                    value={enrollCode}
                    onChange={(e) =>
                      setEnrollCode(
                        e.target.value.replace(/\D/g, '').slice(0, 6),
                      )
                    }
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg tracking-[0.3em]"
                    placeholder="000000"
                  />
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    type="button"
                    disabled={mfaBusy || enrollCode.length < 6}
                    onClick={() => void onConfirmMfaEnroll()}
                  >
                    {mfaBusy ? 'Verifying…' : 'Enable authenticator'}
                  </Button>
                  <Button
                    type="button"
                    variant="ghost"
                    disabled={mfaBusy}
                    onClick={() => {
                      setEnrollFactorId(null)
                      setEnrollQr(null)
                      setEnrollSecret(null)
                      setEnrollCode('')
                    }}
                  >
                    Cancel
                  </Button>
                </div>
              </div>
            ) : (
              <Button
                type="button"
                variant="outline"
                className="border-[rgba(237,230,218,0.22)]"
                disabled={mfaBusy}
                onClick={() => void onStartMfaEnroll()}
              >
                {mfaBusy ? 'Starting…' : 'Set up authenticator'}
              </Button>
            )}
            {mfaError ? (
              <p role="alert" className="text-sm text-red-300">
                {mfaError}
              </p>
            ) : null}
          </div>
        </SettingsSection>
      ) : null}

      <SettingsSection
        label="Connections"
        description="See every signed-in browser and Forja app session — where it is, since when, and revoke one or all."
      >
        <Button
          type="button"
          variant="outline"
          className="border-[rgba(237,230,218,0.22)]"
          onClick={() => void navigate({ to: '/account/settings/connections' })}
        >
          Open connections
        </Button>
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
