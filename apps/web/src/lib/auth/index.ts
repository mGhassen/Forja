export {
  authConfig,
  oauthEnabled,
  oauthProviderLabel,
  type OAuthProviderId,
  mapAuthError,
  checkRequiresMfa,
} from '@forja/auth'
export { startOAuthSignIn } from '@/lib/auth/oauth'
export { exchangeAuthCode, type AuthCallbackResult } from '@/lib/auth/callback'
