import { createFileRoute, redirect } from '@tanstack/react-router'
import { AccountProfilesPage } from '@/pages/account-profiles-page'
import { isPasswordRecoveryLockActive } from '@/lib/supabase'

export const Route = createFileRoute('/account/profiles')({
  beforeLoad: () => {
    if (isPasswordRecoveryLockActive()) {
      throw redirect({ to: '/reset-password' })
    }
  },
  component: AccountProfilesPage,
})
