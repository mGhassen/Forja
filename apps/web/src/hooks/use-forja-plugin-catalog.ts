import { useQuery } from '@tanstack/react-query'
import {
  fetchPluginCatalog,
  hydratePluginCatalog,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'

export function useForjaPluginCatalog() {
  return useQuery({
    queryKey: ['forja-plugin-catalog'],
    queryFn: async (): Promise<ForjaPluginPackLive[]> => {
      const catalog = await fetchPluginCatalog()
      return hydratePluginCatalog(catalog)
    },
    staleTime: 5 * 60_000,
  })
}
