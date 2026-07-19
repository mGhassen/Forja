import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export function useIsAdmin() {
  const { user } = useAuth()

  return useQuery({
    queryKey: ['is_admin', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async (): Promise<boolean> => {
      const { data, error } = await supabase.rpc('is_admin')
      if (error) {
        const { data: row, error: rowError } = await supabase
          .from('accounts')
          .select('is_admin')
          .eq('id', user!.id)
          .maybeSingle()
        if (rowError) throw rowError
        return Boolean(row?.is_admin)
      }
      return Boolean(data)
    },
    staleTime: 60_000,
  })
}
