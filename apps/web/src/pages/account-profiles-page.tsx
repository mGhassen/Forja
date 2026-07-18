import { useEffect, useState, type FormEvent } from 'react'
import { ArrowLeft, Check, Plus, Trash2 } from 'lucide-react'
import { Link, useNavigate } from '@tanstack/react-router'
import { RequireAuth } from '@/components/require-auth'
import { SiteHeader } from '@/components/site-header'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  PROFILE_AVATAR_CATEGORIES,
  PROFILE_AVATARS,
  ProfileAvatar,
  normalizeAvatarKey,
  type ProfileAvatarKey,
} from '@/components/profile-avatar'
import { useProfiles } from '@/hooks/use-profiles'
import { useAuth } from '@/hooks/use-auth'

type Screen = 'choose' | 'manage' | 'create' | 'edit'

export function AccountProfilesPage() {
  const navigate = useNavigate()
  const { signOut } = useAuth()
  const {
    profiles,
    activeProfile,
    loading,
    canAddProfile,
    selectProfile,
    createProfile,
    renameProfile,
    updateProfileAvatar,
    deleteProfile,
    creating,
  } = useProfiles()
  const [screen, setScreen] = useState<Screen>('choose')
  const [editingId, setEditingId] = useState<string | null>(null)
  const [name, setName] = useState('')
  const [avatarKey, setAvatarKey] = useState<ProfileAvatarKey>('forge')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const editingProfile = profiles.find((profile) => profile.id === editingId) ?? null

  useEffect(() => {
    if (!editingProfile || screen !== 'edit') return
    setName(editingProfile.name)
    setAvatarKey(normalizeAvatarKey(editingProfile.avatar_key))
  }, [editingProfile, screen])

  useEffect(() => {
    if (loading || screen !== 'choose' || profiles.length > 0) return
    setName('')
    setAvatarKey(PROFILE_AVATARS[0]!.key)
    setError(null)
    setScreen('create')
  }, [loading, profiles.length, screen])

  const chooseProfile = (profileId: string) => {
    selectProfile(profileId)
    void navigate({ to: '/account/settings' })
  }

  const beginCreate = () => {
    if (!canAddProfile) {
      setError('Maximum of 5 profiles per account')
      return
    }
    setName('')
    setAvatarKey(
      PROFILE_AVATARS[profiles.length % PROFILE_AVATARS.length].key,
    )
    setError(null)
    setScreen('create')
  }

  const beginEdit = (profileId: string) => {
    setEditingId(profileId)
    setError(null)
    setScreen('edit')
  }

  const handleSave = async (event: FormEvent) => {
    event.preventDefault()
    setError(null)
    setSaving(true)
    const creatingFirst = screen === 'create' && profiles.length === 0
    try {
      if (screen === 'create') {
        const profile = await createProfile(name, avatarKey)
        if (creatingFirst) {
          selectProfile(profile.id)
          void navigate({ to: '/account/settings' })
          return
        }
      } else if (editingProfile) {
        await Promise.all([
          renameProfile(editingProfile.id, name),
          updateProfileAvatar(editingProfile.id, avatarKey),
        ])
      }
      setScreen('manage')
      setEditingId(null)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save profile')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!editingProfile) return
    setSaving(true)
    setError(null)
    try {
      await deleteProfile(editingProfile.id)
      setScreen('manage')
      setEditingId(null)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not delete profile')
    } finally {
      setSaving(false)
    }
  }

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto flex min-h-screen max-w-6xl flex-col items-center justify-center px-5 pb-20 pt-28 sm:px-8">
          {screen === 'create' || screen === 'edit' ? (
            <ProfileEditor
              title={
                screen === 'create'
                  ? profiles.length === 0
                    ? 'Create your profile'
                    : 'Add profile'
                  : 'Edit profile'
              }
              name={name}
              avatarKey={avatarKey}
              saving={saving || creating}
              canDelete={screen === 'edit' && profiles.length > 1}
              canCancel={profiles.length > 0 || screen === 'edit'}
              error={error}
              onNameChange={setName}
              onAvatarChange={setAvatarKey}
              onSave={handleSave}
              onDelete={() => void handleDelete()}
              onCancel={() => {
                setScreen(profiles.length === 0 ? 'choose' : 'manage')
                setEditingId(null)
              }}
            />
          ) : (
            <>
              <div className="relative w-full text-center">
                {profiles.length > 0 ? (
                  <Link
                    to="/account/settings"
                    className="absolute left-0 top-1/2 hidden -translate-y-1/2 items-center gap-2 text-sm text-forja-muted hover:text-forja-text sm:flex"
                  >
                    <ArrowLeft className="size-4" />
                    Settings
                  </Link>
                ) : null}
                <h1 className="font-display text-4xl tracking-tight sm:text-5xl">
                  {screen === 'manage' ? 'Manage profiles' : "Who's watching?"}
                </h1>
                {profiles.length === 0 ? (
                  <p className="mt-3 text-forja-muted">
                    Create a profile to sync settings across devices.
                  </p>
                ) : null}
              </div>

              {loading ? (
                <p className="mt-12 text-forja-muted">Loading profiles…</p>
              ) : (
                <div className="mt-12 flex max-w-5xl flex-wrap justify-center gap-x-5 gap-y-9 sm:gap-x-7">
                  {profiles.map((profile) => {
                    const selected = profile.id === activeProfile?.id
                    return (
                      <button
                        key={profile.id}
                        type="button"
                        className="group w-28 text-center sm:w-36"
                        onClick={() =>
                          screen === 'manage'
                            ? beginEdit(profile.id)
                            : chooseProfile(profile.id)
                        }
                      >
                        <ProfileAvatar
                          avatarKey={profile.avatar_key}
                          name={profile.name}
                          editing={screen === 'manage'}
                          className={`w-full border-[3px] transition duration-200 group-hover:scale-[1.04] group-hover:border-white ${
                            selected && screen === 'choose'
                              ? 'border-forja-green'
                              : 'border-transparent'
                          }`}
                        />
                        <span
                          className={`mt-3 block truncate text-base transition group-hover:text-white ${
                            selected && screen === 'choose'
                              ? 'text-forja-text'
                              : 'text-forja-muted'
                          }`}
                        >
                          {profile.name}
                        </span>
                      </button>
                    )
                  })}

                  {(screen === 'manage' || profiles.length === 0) &&
                  canAddProfile ? (
                    <button
                      type="button"
                      className="group w-28 text-center sm:w-36"
                      onClick={beginCreate}
                    >
                      <span className="flex aspect-square w-full items-center justify-center rounded-[4px] border-[3px] border-dashed border-white/25 text-forja-muted transition group-hover:scale-[1.04] group-hover:border-white group-hover:text-white">
                        <Plus className="size-14" strokeWidth={1.25} />
                      </span>
                      <span className="mt-3 block text-base text-forja-muted group-hover:text-white">
                        Add profile
                      </span>
                    </button>
                  ) : null}
                </div>
              )}

              <div className="mt-14 flex flex-wrap items-center justify-center gap-3">
                {profiles.length > 0 ? (
                  <Button
                    type="button"
                    variant={screen === 'manage' ? 'default' : 'secondary'}
                    className="min-w-40 uppercase tracking-[0.12em]"
                    onClick={() =>
                      setScreen((current) =>
                        current === 'manage' ? 'choose' : 'manage',
                      )
                    }
                  >
                    {screen === 'manage' ? 'Done' : 'Manage profiles'}
                  </Button>
                ) : null}
                <Button
                  type="button"
                  variant="outline"
                  className="min-w-40 uppercase tracking-[0.12em]"
                  onClick={() => {
                    void (async () => {
                      await signOut()
                      void navigate({ to: '/' })
                    })()
                  }}
                >
                  Log out
                </Button>
              </div>
            </>
          )}
        </main>
      </div>
    </RequireAuth>
  )
}

type ProfileEditorProps = {
  title: string
  name: string
  avatarKey: ProfileAvatarKey
  saving: boolean
  canDelete: boolean
  canCancel?: boolean
  error: string | null
  onNameChange: (name: string) => void
  onAvatarChange: (avatar: ProfileAvatarKey) => void
  onSave: (event: FormEvent) => void
  onDelete: () => void
  onCancel: () => void
}

function ProfileEditor({
  title,
  name,
  avatarKey,
  saving,
  canDelete,
  canCancel = true,
  error,
  onNameChange,
  onAvatarChange,
  onSave,
  onDelete,
  onCancel,
}: ProfileEditorProps) {
  return (
    <section className="w-full max-w-5xl">
      <h1 className="border-b border-forja-border pb-5 font-display text-4xl tracking-tight sm:text-5xl">
        {title}
      </h1>

      <form onSubmit={onSave}>
        <div className="grid gap-8 border-b border-forja-border py-8 sm:grid-cols-[150px_1fr]">
          <ProfileAvatar
            avatarKey={avatarKey}
            name={name || 'New profile'}
            className="w-36 border-2 border-white/20"
          />
          <div>
            <Input
              autoFocus
              aria-label="Profile name"
              placeholder="Profile name"
              maxLength={40}
              value={name}
              onChange={(event) => onNameChange(event.target.value)}
              className="h-12 text-base"
            />
            <p className="mb-4 mt-7 text-xs font-bold uppercase tracking-[0.16em] text-forja-muted">
              Choose an avatar
            </p>
            <div className="space-y-6">
              {PROFILE_AVATAR_CATEGORIES.map((category) => (
                <fieldset key={category.key}>
                  <legend className="mb-2 text-sm font-semibold text-forja-text">
                    {category.label}
                    <span className="ml-2 font-normal text-forja-muted">
                      {category.avatars.length}
                    </span>
                  </legend>
                  <div className="grid grid-cols-4 gap-2.5 sm:grid-cols-8">
                    {category.avatars.map((avatar) => {
                      const selected = avatar.key === avatarKey
                      return (
                        <button
                          key={avatar.key}
                          type="button"
                          onClick={() => onAvatarChange(avatar.key)}
                          aria-label={`Use ${avatar.label} avatar`}
                          title={avatar.label}
                        >
                          <ProfileAvatar
                            avatarKey={avatar.key}
                            name={avatar.label}
                            className={`w-full border-[3px] transition hover:scale-105 hover:border-white ${
                              selected
                                ? 'border-forja-green'
                                : 'border-transparent'
                            }`}
                          />
                          {selected ? (
                            <span className="mx-auto mt-1 flex size-4 items-center justify-center rounded-full bg-forja-green text-black">
                              <Check className="size-3" />
                            </span>
                          ) : (
                            <span className="mt-1 block h-4" />
                          )}
                        </button>
                      )
                    })}
                  </div>
                </fieldset>
              ))}
            </div>
          </div>
        </div>

        {error ? <p className="mt-4 text-sm text-red-300">{error}</p> : null}

        <div className="mt-6 flex flex-wrap gap-3">
          <Button type="submit" disabled={saving || !name.trim()}>
            {saving ? 'Saving…' : 'Save profile'}
          </Button>
          {canCancel ? (
            <Button type="button" variant="secondary" onClick={onCancel}>
              Cancel
            </Button>
          ) : null}
          {canDelete ? (
            <Button
              type="button"
              variant="ghost"
              className="sm:ml-auto"
              onClick={onDelete}
              disabled={saving}
            >
              <Trash2 className="mr-2 size-4 text-red-300" />
              Delete profile
            </Button>
          ) : null}
        </div>
      </form>
    </section>
  )
}
