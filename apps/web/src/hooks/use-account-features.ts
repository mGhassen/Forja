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
      const { data, error } = await supabase
        .from('accounts')
        .select('features')
        .eq('id', user!.id)
        .maybeSingle()
      if (error) throw error
      return expandAccountFeatures(data?.features)
    },
    staleTime: 60_000,
    placeholderData: emptyAccountFeatures(),
  })
}
