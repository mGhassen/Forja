import { createFileRoute } from '@tanstack/react-router'
import { TermsPage } from '@/pages/terms-page'

export const Route = createFileRoute('/terms')({
  component: TermsPage,
  head: () => ({
    meta: [{ title: 'Terms of use — Forja' }],
  }),
})
