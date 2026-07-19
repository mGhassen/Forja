import type { ReactNode } from 'react'
import {
  authConfig,
  oauthEnabled,
  oauthProviderLabel,
  type OAuthProviderId,
} from '../config'
import { useAuth } from './auth-provider'

export function useOAuthSignIn() {
  const { signInWithOAuth } = useAuth()
  return {
    enabled: oauthEnabled(),
    providers: authConfig.oauthProviders,
    label: oauthProviderLabel,
    signIn: (provider: OAuthProviderId) => signInWithOAuth(provider),
  }
}

/** Host renders buttons; this only exposes providers + handler. */
export function OAuthProviders({
  children,
}: {
  children: (api: {
    providers: OAuthProviderId[]
    label: (id: OAuthProviderId) => string
    signIn: (id: OAuthProviderId) => Promise<{ error: string | null }>
    enabled: boolean
  }) => ReactNode
}) {
  const api = useOAuthSignIn()
  if (!api.enabled) return null
  return <>{children(api)}</>
}
