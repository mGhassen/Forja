import { createFileRoute } from '@tanstack/react-router'
import { SignupPage } from '@/pages/signup-page'

export const Route = createFileRoute('/signup')({
  component: SignupPage,
})
