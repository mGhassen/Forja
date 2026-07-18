import { createFileRoute, redirect } from '@tanstack/react-router'
import { AccountPage } from '@/pages/account-page'
import { isPasswordRecoveryLockActive } from '@/lib/supabase'

export const Route = createFileRoute('/account')({
  beforeLoad: () => {
    // Recovery JWT must never open the account portal.
    if (isPasswordRecoveryLockActive()) {
      throw redirect({ to: '/reset-password' })
    }
  },
  component: AccountPage,
})
