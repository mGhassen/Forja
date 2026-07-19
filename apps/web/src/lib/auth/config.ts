/**
 * Feature flags for portal auth methods (Guepard-style config object).
 *
 * OAuth providers: comma-separated `VITE_AUTH_OAUTH_PROVIDERS` (e.g. `google`).
 * Empty / unset → OAuth UI hidden.
 */

export type OAuthProviderId = 'google' | 'github' | 'apple'

const ALL_OAUTH: OAuthProviderId[] = ['google', 'github', 'apple']

function parseOAuthProviders(raw: string | undefined): OAuthProviderId[] {
  if (!raw?.trim()) return []
  const allowed = new Set<string>(ALL_OAUTH)
  return raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter((s): s is OAuthProviderId => allowed.has(s))
}

export const authConfig = {
  password: true,
  passkeys: true,
  /** Optional TOTP MFA enroll + challenge. */
  mfaTotp: true,
  /** Magic link — built but off until product wants it. */
  magicLink: false,
  oauthProviders: parseOAuthProviders(
    import.meta.env.VITE_AUTH_OAUTH_PROVIDERS as string | undefined,
  ),
} as const

export function oauthEnabled(): boolean {
  return authConfig.oauthProviders.length > 0
}

export function oauthProviderLabel(id: OAuthProviderId): string {
  switch (id) {
    case 'google':
      return 'Google'
    case 'github':
      return 'GitHub'
    case 'apple':
      return 'Apple'
  }
}
