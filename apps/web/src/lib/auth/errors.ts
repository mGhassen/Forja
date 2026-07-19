/**
 * Map Supabase Auth codes / messages to short user-facing copy.
 * Never leak env keys, paths, or internal provider names.
 */

export function mapAuthError(params: {
  message?: string | null
  code?: string | null
  fallback?: string
}): string {
  const code = (params.code ?? '').toLowerCase()
  const message = (params.message ?? '').trim()
  const lower = message.toLowerCase()

  if (code === 'otp_expired' || lower.includes('otp_expired')) {
    return 'That link expired. Request a new one and try again.'
  }
  if (
    lower.includes('both auth code and code verifier should be non-empty') ||
    code === 'bad_code_verifier'
  ) {
    return 'Open the sign-in link in the same browser where you started. Then try again.'
  }
  if (
    code === 'refresh_token_already_used' ||
    (lower.includes('refresh token') && lower.includes('already used'))
  ) {
    return 'Your session was refreshed elsewhere. Sign in again.'
  }
  if (code === 'session_not_found' || lower.includes('session_not_found')) {
    return 'That session is no longer valid. Sign in again.'
  }
  if (
    code === 'invalid_credentials' ||
    lower.includes('invalid login credentials')
  ) {
    return 'Email or password is incorrect.'
  }
  if (code === 'user_already_exists' || lower.includes('already registered')) {
    return 'An account with this email already exists. Sign in instead.'
  }
  if (code === 'over_request_rate_limit' || lower.includes('rate limit')) {
    return 'Too many attempts. Wait a moment and try again.'
  }
  if (code === 'mfa_verification_failed' || lower.includes('invalid totp')) {
    return 'That code is incorrect. Try again.'
  }
  if (message) return message
  return params.fallback ?? 'Something went wrong. Try again.'
}
