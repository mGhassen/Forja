import { useQuery } from '@tanstack/react-query'
import {
  loadLivePluginCatalog,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'

export function useForjaPluginCatalog() {
  return useQuery({
    queryKey: ['forja-plugin-catalog'],
    queryFn: async (): Promise<ForjaPluginPackLive[]> => loadLivePluginCatalog(),
    staleTime: 5 * 60_000,
  })
}
