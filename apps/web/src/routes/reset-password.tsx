import { createFileRoute } from '@tanstack/react-router'
import { ResetPasswordPage } from '@/pages/reset-password-page'

type ResetPasswordSearch = {
  email?: string
}

export const Route = createFileRoute('/reset-password')({
  validateSearch: (search: Record<string, unknown>): ResetPasswordSearch => ({
    email: typeof search.email === 'string' ? search.email : undefined,
  }),
  component: ResetPasswordPage,
})
