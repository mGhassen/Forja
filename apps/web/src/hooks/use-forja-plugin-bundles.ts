import { useQuery } from '@tanstack/react-query'
import {
  fetchPublishedPluginBundlesFromSupabase,
  type ForjaPluginBundleMeta,
} from '@/lib/forja-plugin-catalog'

export function useForjaPluginBundles() {
  return useQuery({
    queryKey: ['forja-plugin-bundles'],
    queryFn: async (): Promise<ForjaPluginBundleMeta[]> =>
      fetchPublishedPluginBundlesFromSupabase(),
    staleTime: 5 * 60_000,
  })
}
