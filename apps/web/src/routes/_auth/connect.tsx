import { createFileRoute } from '@tanstack/react-router'
import { ConnectPage } from '@/pages/connect-page'

type ConnectSearch = {
  code?: string
}

export const Route = createFileRoute('/_auth/connect')({
  validateSearch: (search: Record<string, unknown>): ConnectSearch => ({
    code: typeof search.code === 'string' ? search.code : undefined,
  }),
  component: function ConnectRoute() {
    const { code } = Route.useSearch()
    return <ConnectPage initialCode={code ?? ''} />
  },
})
