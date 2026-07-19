import { createFileRoute } from '@tanstack/react-router'
import { AuthShell } from '@/components/auth-shell'

export const Route = createFileRoute('/_auth')({
  component: AuthShell,
})
