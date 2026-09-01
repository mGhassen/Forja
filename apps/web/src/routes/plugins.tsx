import { createFileRoute } from '@tanstack/react-router'
import { PluginsPage } from '@/pages/plugins-page'

export type PluginsSearch = {
  add?: string
}

export const Route = createFileRoute('/plugins')({
  validateSearch: (search: Record<string, unknown>): PluginsSearch => ({
    add: typeof search.add === 'string' && search.add.length > 0 ? search.add : undefined,
  }),
  component: PluginsPage,
})
