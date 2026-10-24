import { createFileRoute } from '@tanstack/react-router'
import { ConnectPage } from '@/pages/connect-page'

type ConnectSearch = {
  code?: string
  /** `switch_account=1`: the device is adding another account — ask first. */
  switch_account?: '1'
}

export const Route = createFileRoute('/_auth/connect')({
  validateSearch: (search: Record<string, unknown>): ConnectSearch => ({
    code: typeof search.code === 'string' ? search.code : undefined,
    switch_account: search.switch_account === '1' ? '1' : undefined,
  }),
  component: function ConnectRoute() {
    const { code, switch_account } = Route.useSearch()
    return (
      <ConnectPage
        initialCode={code ?? ''}
        switchAccount={switch_account === '1'}
      />
    )
  },
})
