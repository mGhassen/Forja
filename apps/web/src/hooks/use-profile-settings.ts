import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { Json, IptvPortal } from '@/lib/database.types'
import type { ProfileSettingsPayload } from '@/lib/sync-domains'
import {
  compactProfileSettingsPayload,
  emptyProfileSettingsPayload,
  expandProfileSettingsPayload,
} from '@/lib/sync-domains'

export function useProfileSettings() {
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['profile_settings', user?.id, activeProfile?.id],
    enabled: Boolean(user?.id && activeProfile?.id && supabaseConfigured),
    queryFn: async (): Promise<{
      payload: ProfileSettingsPayload
      updated_at: string | null
    }> => {
      const { data, error } = await supabase
        .from('profile_settings')
        .select('payload, updated_at')
        .eq('account_id', user!.id)
        .eq('profile_id', activeProfile!.id)
        .maybeSingle()
      if (error) throw error
      return {
        payload: expandProfileSettingsPayload(data?.payload),
        updated_at: data?.updated_at ?? null,
      }
    },
  })

  const saveMutation = useMutation({
    mutationFn: async (payload: ProfileSettingsPayload) => {
      if (!activeProfile || !user) throw new Error('Select a profile first')
      const now = new Date().toISOString()
      const lean = compactProfileSettingsPayload(payload)
      const { error } = await supabase.from('profile_settings').upsert({
        profile_id: activeProfile.id,
        account_id: user.id,
        payload: lean as Json,
        updated_at: now,
        updated_by: user.id,
      })
      if (error) throw error
      return now
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['profile_settings', user?.id, activeProfile?.id],
      })
    },
  })

  const patchMutation = useMutation({
    mutationFn: async (patch: Partial<ProfileSettingsPayload>) => {
      const current = query.data?.payload ?? emptyProfileSettingsPayload()
      const next: ProfileSettingsPayload = {
        ...current,
        ...patch,
        connectedServices: {
          ...current.connectedServices,
          ...patch.connectedServices,
          stremio:
            patch.connectedServices?.stremio ??
            current.connectedServices?.stremio,
          nuvio:
            patch.connectedServices?.nuvio ?? current.connectedServices?.nuvio,
        },
        navigation: patch.navigation
          ? { ...current.navigation, ...patch.navigation }
          : current.navigation,
      }
      await saveMutation.mutateAsync(next)
      return expandProfileSettingsPayload(compactProfileSettingsPayload(next))
    },
  })

  const profileId = activeProfile?.id ?? null
  // Never surface another profile's cached row while this profile is pending.
  const data = !profileId || query.isPending ? undefined : query.data

  return {
    ...query,
    data,
    isLoading: !profileId || query.isPending || query.isLoading,
    profileId,
    save: saveMutation.mutateAsync,
    patch: patchMutation.mutateAsync,
    isSaving: saveMutation.isPending || patchMutation.isPending,
    saveError: saveMutation.error ?? patchMutation.error,
  }
}

export async function upsertIptvPortal(args: {
  url: string
  username: string
  password: string
  source?: string | null
  expiry?: string | null
  maxConnections?: string | null
}): Promise<string> {
  const { data, error } = await supabase.rpc('upsert_iptv_portal', {
    p_url: args.url,
    p_username: args.username,
    p_password: args.password,
    p_source: args.source ?? null,
    p_expiry: args.expiry ?? null,
    p_max_connections: args.maxConnections ?? null,
  })
  if (error) throw error
  return data as string
}

export async function fetchIptvPortals(ids: string[]): Promise<IptvPortal[]> {
  if (!ids.length) return []
  const { data, error } = await supabase.rpc('get_iptv_portals', { p_ids: ids })
  if (error) throw error
  return (data ?? []) as IptvPortal[]
}
