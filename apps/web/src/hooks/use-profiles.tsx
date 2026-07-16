import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { Profile } from '@/lib/database.types'

const PROFILE_COLORS = [
  '#1ce783',
  '#ff4d1c',
  '#5aa9ff',
  '#c084fc',
  '#facc15',
  '#fb7185',
] as const

type ProfilesContextValue = {
  profiles: Profile[]
  activeProfile: Profile | null
  loading: boolean
  error: Error | null
  selectProfile: (profileId: string) => void
  createProfile: (name: string) => Promise<Profile>
  renameProfile: (profileId: string, name: string) => Promise<void>
  deleteProfile: (profileId: string) => Promise<void>
  creating: boolean
}

const ProfilesContext = createContext<ProfilesContextValue | null>(null)

function storageKey(userId: string) {
  return `forja.active-profile.${userId}`
}

export function ProfilesProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [activeProfileId, setActiveProfileId] = useState<string | null>(null)

  const profilesQuery = useQuery({
    queryKey: ['profiles', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async (): Promise<Profile[]> => {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', user!.id)
        .order('created_at')
      if (error) throw error
      return data ?? []
    },
  })

  const profiles = profilesQuery.data ?? []

  useEffect(() => {
    if (!user) {
      setActiveProfileId(null)
      return
    }
    if (profiles.length === 0) return

    const saved = window.localStorage.getItem(storageKey(user.id))
    const next =
      (saved && profiles.some((profile) => profile.id === saved) && saved) ||
      profiles[0]!.id
    setActiveProfileId(next)
    window.localStorage.setItem(storageKey(user.id), next)
  }, [profiles, user])

  const selectProfile = (profileId: string) => {
    if (!user || !profiles.some((profile) => profile.id === profileId)) return
    setActiveProfileId(profileId)
    window.localStorage.setItem(storageKey(user.id), profileId)
  }

  const createMutation = useMutation({
    mutationFn: async (name: string): Promise<Profile> => {
      const cleanName = name.trim()
      if (!user || !cleanName) throw new Error('Enter a profile name')
      const color = PROFILE_COLORS[profiles.length % PROFILE_COLORS.length]
      const { data, error } = await supabase
        .from('profiles')
        .insert({ user_id: user.id, name: cleanName, color })
        .select('*')
        .single()
      if (error) throw error
      return data
    },
    onSuccess: (profile) => {
      void queryClient.invalidateQueries({ queryKey: ['profiles', user?.id] })
      setActiveProfileId(profile.id)
      if (user) window.localStorage.setItem(storageKey(user.id), profile.id)
    },
  })

  const renameMutation = useMutation({
    mutationFn: async ({ profileId, name }: { profileId: string; name: string }) => {
      const cleanName = name.trim()
      if (!user || !cleanName) throw new Error('Enter a profile name')
      const { error } = await supabase
        .from('profiles')
        .update({ name: cleanName, updated_at: new Date().toISOString() })
        .eq('id', profileId)
        .eq('user_id', user.id)
      if (error) throw error
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['profiles', user?.id] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: async (profileId: string) => {
      if (!user) return
      if (profiles.length <= 1) throw new Error('Every account needs one profile')
      const { error } = await supabase
        .from('profiles')
        .delete()
        .eq('id', profileId)
        .eq('user_id', user.id)
      if (error) throw error
    },
    onSuccess: (_, deletedId) => {
      if (activeProfileId === deletedId && user) {
        const next = profiles.find((profile) => profile.id !== deletedId)
        setActiveProfileId(next?.id ?? null)
        if (next) window.localStorage.setItem(storageKey(user.id), next.id)
      }
      void queryClient.invalidateQueries({ queryKey: ['profiles', user?.id] })
    },
  })

  const activeProfile =
    profiles.find((profile) => profile.id === activeProfileId) ?? profiles[0] ?? null

  const value = useMemo<ProfilesContextValue>(
    () => ({
      profiles,
      activeProfile,
      loading: profilesQuery.isLoading,
      error:
        profilesQuery.error instanceof Error
          ? profilesQuery.error
          : profilesQuery.error
            ? new Error('Failed to load profiles')
            : null,
      selectProfile,
      createProfile: createMutation.mutateAsync,
      renameProfile: async (profileId, name) => {
        await renameMutation.mutateAsync({ profileId, name })
      },
      deleteProfile: deleteMutation.mutateAsync,
      creating: createMutation.isPending,
    }),
    [
      profiles,
      activeProfile,
      profilesQuery.isLoading,
      profilesQuery.error,
      createMutation.mutateAsync,
      createMutation.isPending,
      renameMutation.mutateAsync,
      deleteMutation.mutateAsync,
    ],
  )

  return <ProfilesContext.Provider value={value}>{children}</ProfilesContext.Provider>
}

export function useProfiles() {
  const context = useContext(ProfilesContext)
  if (!context) throw new Error('useProfiles must be used within ProfilesProvider')
  return context
}
