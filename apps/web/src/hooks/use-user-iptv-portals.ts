import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { IptvPortal, UserIptvPortal } from '@/lib/database.types'
import { fetchIptvPortals, upsertIptvPortal } from '@/hooks/use-profile-settings'

export type AssignedIptvPortal = UserIptvPortal & {
  portal: IptvPortal
}

export function useUserIptvPortals() {
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['user_iptv_portals', user?.id, activeProfile?.id],
    enabled: Boolean(user?.id && activeProfile?.id && supabaseConfigured),
    queryFn: async (): Promise<AssignedIptvPortal[]> => {
      const { data: rows, error } = await supabase
        .from('user_iptv_portals')
        .select('*')
        .eq('account_id', user!.id)
        .eq('profile_id', activeProfile!.id)
        .order('created_at')
      if (error) throw error
      const assignments = (rows ?? []) as UserIptvPortal[]
      const portals = await fetchIptvPortals(assignments.map((a) => a.portal_id))
      const byId = new Map(portals.map((p) => [p.id, p]))
      return assignments
        .map((a) => {
          const portal = byId.get(a.portal_id)
          if (!portal) return null
          return { ...a, portal }
        })
        .filter((a): a is AssignedIptvPortal => a != null)
    },
  })

  const replaceAll = useMutation({
    mutationFn: async (
      rows: Array<{
        url: string
        username: string
        password: string
        source?: string
        expiry?: string
        maxConnections?: string
        portalName: string
        favorite?: boolean
      }>,
    ) => {
      if (!user || !activeProfile) throw new Error('Select a profile first')
      // Cloud is master — empty Save must not delete every assignment.
      if (rows.length === 0) {
        throw new Error(
          'Refusing to save an empty portal list (would wipe cloud assignments). Delete portals individually or keep at least one.',
        )
      }
      const now = new Date().toISOString()
      const portalIds: string[] = []
      const assignments: Array<{
        account_id: string
        profile_id: string
        portal_id: string
        portal_name: string
        favorite: boolean
        updated_at: string
        updated_by: string
      }> = []

      for (const row of rows) {
        const portalId = await upsertIptvPortal({
          url: row.url,
          username: row.username,
          password: row.password,
          source: row.source,
          expiry: row.expiry,
          maxConnections: row.maxConnections,
        })
        portalIds.push(portalId)
        assignments.push({
          account_id: user.id,
          profile_id: activeProfile.id,
          portal_id: portalId,
          portal_name: row.portalName.trim() || row.username,
          favorite: row.favorite === true,
          updated_at: now,
          updated_by: user.id,
        })
      }

      const { error: delError } = await supabase
        .from('user_iptv_portals')
        .delete()
        .eq('account_id', user.id)
        .eq('profile_id', activeProfile.id)
      if (delError) throw delError

      if (assignments.length) {
        const { error: insError } = await supabase
          .from('user_iptv_portals')
          .insert(assignments)
        if (insError) throw insError
      }
      return portalIds
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ['user_iptv_portals', user?.id, activeProfile?.id],
      })
    },
  })

  const profileId = activeProfile?.id ?? null
  const data = !profileId || query.isPending ? undefined : query.data

  return {
    ...query,
    data,
    isLoading: !profileId || query.isPending || query.isLoading,
    profileId,
    replaceAll: replaceAll.mutateAsync,
    isSaving: replaceAll.isPending,
    saveError: replaceAll.error,
  }
}
