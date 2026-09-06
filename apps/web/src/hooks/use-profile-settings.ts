import { useEffect, useRef } from 'react'
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

type ProfileSettingsRow = {
  payload: ProfileSettingsPayload
  updated_at: string | null
}

function profileSettingsKey(userId: string | undefined, profileId: string | undefined) {
  return ['profile_settings', userId, profileId] as const
}

/**
 * One Realtime channel per profile. Multiple `useProfileSettings` mounts
 * (section hooks + Addons page) must not call `.on()` on an already-subscribed
 * topic — supabase-js throws:
 * "cannot add postgres_changes callbacks … after subscribe()".
 */
const profileSettingsListeners = new Map<string, Set<() => void>>()
const profileSettingsChannels = new Map<
  string,
  ReturnType<typeof supabase.channel>
>()

function subscribeProfileSettingsRealtime(
  profileId: string,
  onChange: () => void,
): () => void {
  let listeners = profileSettingsListeners.get(profileId)
  if (!listeners) {
    listeners = new Set()
    profileSettingsListeners.set(profileId, listeners)
  }
  listeners.add(onChange)

  if (!profileSettingsChannels.has(profileId)) {
    for (const ch of supabase.getChannels()) {
      if (ch.topic.includes(`profile_settings:${profileId}`)) {
        void supabase.removeChannel(ch)
      }
    }
    const channel = supabase
      .channel(`profile_settings:${profileId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'profile_settings',
          filter: `profile_id=eq.${profileId}`,
        },
        () => {
          const set = profileSettingsListeners.get(profileId)
          if (!set) return
          for (const fn of set) fn()
        },
      )
      .subscribe()
    profileSettingsChannels.set(profileId, channel)
  }

  return () => {
    listeners!.delete(onChange)
    if (listeners!.size === 0) {
      profileSettingsListeners.delete(profileId)
      const channel = profileSettingsChannels.get(profileId)
      if (channel) {
        void supabase.removeChannel(channel)
        profileSettingsChannels.delete(profileId)
      }
    }
  }
}

function mergeProfilePatch(
  current: ProfileSettingsPayload,
  patch: Partial<ProfileSettingsPayload>,
): ProfileSettingsPayload {
  return {
    ...current,
    ...patch,
    playback: patch.playback
      ? {
          ...current.playback,
          ...patch.playback,
          addon_feature_iptv:
            patch.playback.addon_feature_iptv !== undefined
              ? patch.playback.addon_feature_iptv
              : current.playback?.addon_feature_iptv,
          addon_feature_live_matches:
            patch.playback.addon_feature_live_matches !== undefined
              ? patch.playback.addon_feature_live_matches
              : current.playback?.addon_feature_live_matches,
        }
      : current.playback,
    connectedServices: {
      ...current.connectedServices,
      ...patch.connectedServices,
      stremio:
        patch.connectedServices?.stremio ?? current.connectedServices?.stremio,
      nuvio:
        patch.connectedServices?.nuvio ?? current.connectedServices?.nuvio,
      forja:
        patch.connectedServices?.forja ?? current.connectedServices?.forja,
    },
    // Replace Features wholesale — shallow merge kept stale visibleIds when
    // clearing tabs (empty array must win; issue 221).
    navigation: patch.navigation ?? current.navigation,
  }
}

export function useProfileSettings() {
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const queryClient = useQueryClient()
  const patchChain = useRef(Promise.resolve<void>(undefined))

  const queryKey = profileSettingsKey(user?.id, activeProfile?.id)

  const query = useQuery({
    queryKey,
    enabled: Boolean(user?.id && activeProfile?.id && supabaseConfigured),
    // Soft-pull parity with the app: refetch when the tab is focused / remounted
    // so app → web Features land without a hard reload.
    staleTime: 0,
    refetchOnWindowFocus: true,
    refetchOnReconnect: true,
    queryFn: async (): Promise<ProfileSettingsRow> => {
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

  // Visibility soft-pull + Realtime (async cloud → web).
  useEffect(() => {
    const userId = user?.id
    const profileId = activeProfile?.id
    if (!userId || !profileId || !supabaseConfigured) return

    const key = profileSettingsKey(userId, profileId)
    const softPull = () => {
      void queryClient.invalidateQueries({ queryKey: key })
    }

    const onVisibility = () => {
      if (document.visibilityState === 'visible') softPull()
    }
    document.addEventListener('visibilitychange', onVisibility)
    const unsubscribe = subscribeProfileSettingsRealtime(profileId, softPull)

    return () => {
      document.removeEventListener('visibilitychange', onVisibility)
      unsubscribe()
    }
  }, [user?.id, activeProfile?.id, queryClient])

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
      return { payload: expandProfileSettingsPayload(lean), updated_at: now }
    },
    onSuccess: (row) => {
      queryClient.setQueryData(queryKey, row)
    },
  })

  const patchMutation = useMutation({
    mutationFn: async (patch: Partial<ProfileSettingsPayload>) => {
      // Serialize patches — parallel commits were merging from a stale
      // query.data and wiping the previous toggle (web looked “not async”).
      const run = patchChain.current.then(async () => {
        const cached = queryClient.getQueryData<ProfileSettingsRow>(queryKey)
        const current = cached?.payload ?? emptyProfileSettingsPayload()
        const next = mergeProfilePatch(current, patch)
        // Optimistic cache so UI / sibling hooks see the edit immediately.
        queryClient.setQueryData<ProfileSettingsRow>(queryKey, {
          payload: next,
          updated_at: cached?.updated_at ?? new Date().toISOString(),
        })
        const saved = await saveMutation.mutateAsync(next)
        return saved.payload
      })
      patchChain.current = run.then(
        () => undefined,
        () => undefined,
      )
      return run
    },
  })

  const profileId = activeProfile?.id ?? null
  // Never surface another profile's cached row while this profile is pending.
  // Keep prior data during background refetch so drafts are not treated as "loading".
  const data =
    !profileId || (query.isPending && !query.data) ? undefined : query.data

  return {
    ...query,
    data,
    isLoading: !profileId || (query.isPending && !query.data),
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
  platform?: 'xtream' | 'm3u' | 'stalker' | null
}): Promise<string> {
  const { data, error } = await supabase.rpc('upsert_iptv_portal', {
    p_url: args.url,
    p_username: args.username,
    p_password: args.password,
    p_source: args.source ?? undefined,
    p_expiry: args.expiry ?? undefined,
    p_max_connections: args.maxConnections ?? undefined,
    p_platform: args.platform ?? 'xtream',
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
