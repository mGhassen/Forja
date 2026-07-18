import { createFileRoute, redirect } from '@tanstack/react-router'
import { AccountSettingsPage } from '@/pages/account-settings-page'
import { isPasswordRecoveryLockActive } from '@/lib/supabase'

export const Route = createFileRoute('/account/settings')({
  beforeLoad: () => {
    if (isPasswordRecoveryLockActive()) {
      throw redirect({ to: '/reset-password' })
    }
  },
  component: AccountSettingsPage,
})
