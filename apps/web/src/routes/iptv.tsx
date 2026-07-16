import { createFileRoute } from '@tanstack/react-router'
import { IptvPage } from '@/pages/iptv-page'

export const Route = createFileRoute('/iptv')({
  component: IptvPage,
})
