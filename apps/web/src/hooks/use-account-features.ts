import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import {
  emptyAccountFeatures,
  expandAccountFeatures,
  type AccountFeaturesExpanded,
} from '@/lib/sync-domains'

export function useAccountFeatures() {
  const { user } = useAuth()

  return useQuery({
    queryKey: ['account_features', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async (): Promise<AccountFeaturesExpanded> => {
      let data: {
        features?: unknown
        iptv_credits?: number | null
        is_admin?: boolean | null
      } | null = null

      const withCredits = await supabase
        .from('accounts')
        .select('features, iptv_credits, is_admin')
        .eq('id', user!.id)
        .maybeSingle()
      if (withCredits.error) {
        const fallback = await supabase
          .from('accounts')
          .select('features')
          .eq('id', user!.id)
          .maybeSingle()
        if (fallback.error) throw fallback.error
        data = fallback.data
      } else {
        data = withCredits.data
      }

      const credits = Number(data?.iptv_credits ?? 0)
      return expandAccountFeatures(data?.features, {
        iptvCredits: Number.isFinite(credits) ? credits : 0,
        isAdmin: data?.is_admin === true,
      })
    },
    staleTime: 60_000,
    placeholderData: emptyAccountFeatures(),
  })
}

/** Whether the account can add another portal to a profile inventory. */
export function canAddIptvPortal(
  features: AccountFeaturesExpanded | undefined,
  currentCount: number,
): boolean {
  if (!features) return currentCount < 5
  if (features.isAdmin) return true
  return currentCount < features.maxIptvPortals
}
