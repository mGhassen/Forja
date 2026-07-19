import type { SupabaseClient } from '@supabase/supabase-js'

const AAL2 = 'aal2'

/**
 * True when the user has MFA enrolled but this session is still AAL1
 * (must complete TOTP challenge before accessing the app).
 */
export async function checkRequiresMfa(
  client: SupabaseClient,
): Promise<boolean> {
  const { data, error } = await client.auth.mfa.getAuthenticatorAssuranceLevel()
  if (error) return false
  const { currentLevel, nextLevel } = data
  return nextLevel === AAL2 && currentLevel !== AAL2
}
