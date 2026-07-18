import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export function useIsAdmin() {
  const { user } = useAuth()
  return useQuery({
    queryKey: ['admin', 'is_admin', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async () => {
      const { data, error } = await supabase.rpc('is_admin')
      if (!error) return Boolean(data)
      const { data: row } = await supabase
        .from('accounts')
        .select('is_admin')
        .eq('id', user!.id)
        .maybeSingle()
      return Boolean(row?.is_admin)
    },
    staleTime: 60_000,
  })
}
