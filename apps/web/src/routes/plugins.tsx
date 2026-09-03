import { createFileRoute } from '@tanstack/react-router'
import { PluginsPage } from '@/pages/plugins-page'

export type PluginsSearch = {
  add?: string
  batchInstall?: boolean
}

export const Route = createFileRoute('/plugins')({
  validateSearch: (search: Record<string, unknown>): PluginsSearch => ({
    add: typeof search.add === 'string' && search.add.length > 0 ? search.add : undefined,
    batchInstall:
      search.batchInstall === true ||
      search.batchInstall === '1' ||
      search.batchInstall === 'true'
        ? true
        : undefined,
  }),
  component: PluginsPage,
})
