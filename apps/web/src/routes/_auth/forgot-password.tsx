import { createFileRoute } from '@tanstack/react-router'
import { ForgotPasswordPage } from '@/pages/forgot-password-page'

type ForgotPasswordSearch = {
  /** Set after a reset email is sent — keeps the confirmation screen across refresh. */
  sent?: string
}

export const Route = createFileRoute('/_auth/forgot-password')({
  validateSearch: (search: Record<string, unknown>): ForgotPasswordSearch => ({
    sent: typeof search.sent === 'string' && search.sent.includes('@')
      ? search.sent.trim()
      : undefined,
  }),
  component: ForgotPasswordPage,
})
