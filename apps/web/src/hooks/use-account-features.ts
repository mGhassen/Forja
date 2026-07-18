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
      let data: { features?: unknown; iptv_credits?: number | null } | null =
        null
      const withCredits = await supabase
        .from('accounts')
        .select('features, iptv_credits')
        .eq('id', user!.id)
        .maybeSingle()
      if (withCredits.error) {
        // Column missing until RFC-040 migration is applied.
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
      return expandAccountFeatures(
        data?.features,
        Number.isFinite(credits) ? credits : 0,
      )
    },
    staleTime: 60_000,
    placeholderData: emptyAccountFeatures(),
  })
}
