import { createFileRoute } from '@tanstack/react-router'
import { DmcaPage } from '@/pages/dmca-page'

export const Route = createFileRoute('/dmca')({
  component: DmcaPage,
  head: () => ({
    meta: [{ title: 'DMCA & copyright - Forja' }],
  }),
})
