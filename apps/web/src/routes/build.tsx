import { createFileRoute } from '@tanstack/react-router'
import { BuildPage } from '@/pages/build-page'

export const Route = createFileRoute('/build')({
  component: BuildPage,
})
