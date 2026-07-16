import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { SyncDomain } from '@/lib/sync-domains'
import type { Json } from '@/lib/database.types'

export function useUserSettings() {
  const { user } = useAuth()

  return useQuery({
    queryKey: ['user_settings', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async () => {
      const { data, error } = await supabase
        .from('user_settings')
        .select('domain, payload, updated_at')
        .eq('user_id', user!.id)
        .order('domain')
      if (error) throw error
      return data ?? []
    },
  })
}

export function useUserSetting<T extends Record<string, unknown>>(domain: SyncDomain) {
  const { user } = useAuth()
  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['user_setting', domain, user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async (): Promise<{ payload: T; updated_at: string | null }> => {
      const { data, error } = await supabase
        .from('user_settings')
        .select('payload, updated_at')
        .eq('user_id', user!.id)
        .eq('domain', domain)
        .maybeSingle()
      if (error) throw error
      return {
        payload: (data?.payload as T | undefined) ?? ({} as T),
        updated_at: data?.updated_at ?? null,
      }
    },
  })

  const saveMutation = useMutation({
    mutationFn: async (payload: T) => {
      const now = new Date().toISOString()
      const { error } = await supabase.from('user_settings').upsert({
        user_id: user!.id,
        domain,
        payload: payload as Json,
        updated_at: now,
      })
      if (error) throw error
      return now
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['user_settings', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['user_setting', domain, user?.id] })
    },
  })

  return {
    ...query,
    save: saveMutation.mutateAsync,
    isSaving: saveMutation.isPending,
    saveError: saveMutation.error,
  }
}
