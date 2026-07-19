import { createFileRoute } from '@tanstack/react-router'
import { MfaVerifyPage } from '@/pages/mfa-verify-page'

export const Route = createFileRoute('/_auth/login/mfa')({
  component: MfaVerifyPage,
})
