import { useState, type FormEvent } from 'react'
import { ArrowLeft, Check, Pencil, Plus, Trash2, UserRound } from 'lucide-react'
import { Link } from '@tanstack/react-router'
import { RequireAuth } from '@/components/require-auth'
import { SiteHeader } from '@/components/site-header'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useProfiles } from '@/hooks/use-profiles'

export function AccountProfilesPage() {
  const {
    profiles,
    activeProfile,
    loading,
    selectProfile,
    createProfile,
    renameProfile,
    deleteProfile,
    creating,
  } = useProfiles()
  const [newName, setNewName] = useState('')
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editingName, setEditingName] = useState('')
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const handleCreate = async (event: FormEvent) => {
    event.preventDefault()
    setError(null)
    try {
      await createProfile(newName)
      setNewName('')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not create profile')
    }
  }

  const handleRename = async (profileId: string) => {
    setError(null)
    try {
      await renameProfile(profileId, editingName)
      setEditingId(null)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not rename profile')
    }
  }

  const handleDelete = async (profileId: string) => {
    setError(null)
    try {
      await deleteProfile(profileId)
      setDeletingId(null)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not delete profile')
    }
  }

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-3xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <div className="flex items-center gap-3">
            <Link
              to="/account"
              className="flex size-9 items-center justify-center text-forja-muted hover:text-forja-text"
              aria-label="Back to account"
            >
              <ArrowLeft className="size-5" />
            </Link>
            <h1 className="font-display text-3xl tracking-tight">Profiles</h1>
          </div>
          <p className="ml-12 mt-2 text-sm text-forja-muted">
            Each profile has its own IPTV portals, playback preferences, providers,
            and addons.
          </p>

          <section className="mt-10">
            <div className="mb-2 flex items-center gap-2.5">
              <span className="h-0.5 w-3.5 bg-forja-green" />
              <h2 className="text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green">
                Your profiles
              </h2>
            </div>

            {loading ? <p className="py-5 text-sm text-forja-muted">Loading…</p> : null}
            <div className="divide-y divide-forja-border border-t border-forja-border">
              {profiles.map((profile) => {
                const selected = profile.id === activeProfile?.id
                const editing = editingId === profile.id
                const deleting = deletingId === profile.id
                return (
                  <div
                    key={profile.id}
                    className="flex min-h-20 items-center gap-4 px-0.5 py-3"
                  >
                    <button
                      type="button"
                      className="relative flex size-11 shrink-0 items-center justify-center rounded-full text-black"
                      style={{ backgroundColor: profile.color }}
                      onClick={() => selectProfile(profile.id)}
                      aria-label={`Use ${profile.name}`}
                    >
                      <UserRound className="size-5" />
                      {selected ? (
                        <span className="absolute -bottom-0.5 -right-0.5 flex size-4 items-center justify-center rounded-full bg-forja-text text-forja-bg">
                          <Check className="size-3" />
                        </span>
                      ) : null}
                    </button>

                    <div className="min-w-0 flex-1">
                      {editing ? (
                        <Input
                          autoFocus
                          value={editingName}
                          maxLength={40}
                          onChange={(event) => setEditingName(event.target.value)}
                          onKeyDown={(event) => {
                            if (event.key === 'Enter') void handleRename(profile.id)
                            if (event.key === 'Escape') setEditingId(null)
                          }}
                        />
                      ) : (
                        <>
                          <p className="font-semibold">{profile.name}</p>
                          <p className="mt-0.5 text-xs text-forja-muted">
                            {selected ? 'Active on this browser' : 'Select profile'}
                          </p>
                        </>
                      )}
                    </div>

                    {deleting ? (
                      <div className="flex items-center gap-2">
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => setDeletingId(null)}
                        >
                          Cancel
                        </Button>
                        <Button
                          size="sm"
                          className="bg-red-500 text-white hover:bg-red-400"
                          onClick={() => void handleDelete(profile.id)}
                        >
                          Delete
                        </Button>
                      </div>
                    ) : editing ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => void handleRename(profile.id)}
                      >
                        <Check className="size-4" />
                      </Button>
                    ) : (
                      <div className="flex items-center gap-1">
                        <Button
                          size="sm"
                          variant="ghost"
                          aria-label={`Rename ${profile.name}`}
                          onClick={() => {
                            setEditingId(profile.id)
                            setEditingName(profile.name)
                          }}
                        >
                          <Pencil className="size-4" />
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          disabled={profiles.length <= 1}
                          aria-label={`Delete ${profile.name}`}
                          onClick={() => setDeletingId(profile.id)}
                        >
                          <Trash2 className="size-4 text-red-300" />
                        </Button>
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </section>

          <section className="mt-10">
            <div className="mb-3 flex items-center gap-2.5">
              <span className="h-0.5 w-3.5 bg-forja-green" />
              <h2 className="text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green">
                Add profile
              </h2>
            </div>
            <form className="flex gap-3" onSubmit={handleCreate}>
              <Input
                aria-label="New profile name"
                placeholder="Profile name"
                maxLength={40}
                value={newName}
                onChange={(event) => setNewName(event.target.value)}
              />
              <Button type="submit" disabled={creating || !newName.trim()}>
                <Plus className="mr-2 size-4" />
                Add
              </Button>
            </form>
          </section>

          {error ? <p className="mt-5 text-sm text-red-300">{error}</p> : null}
        </main>
      </div>
    </RequireAuth>
  )
}
