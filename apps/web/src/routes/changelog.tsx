import { createFileRoute } from '@tanstack/react-router'
import { ChangelogPage } from '@/pages/changelog-page'

export type ChangelogSearch = {
  v?: string
}

export const Route = createFileRoute('/changelog')({
  validateSearch: (search: Record<string, unknown>): ChangelogSearch => ({
    v: typeof search.v === 'string' && search.v.length > 0 ? search.v : undefined,
  }),
  component: ChangelogPage,
})
