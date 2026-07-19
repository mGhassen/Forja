import type { SupabaseClient } from '@supabase/supabase-js'
import { exchangeAuthCode } from '../callback'
import { checkRequiresMfa } from '../mfa'

export type RunAuthCallbackResult =
  | { status: 'ok'; nextPath: string; needsMfa: boolean }
  | { status: 'error'; message: string }

/** Shared PKCE callback runner for portal + admin. */
export async function runAuthCallback(options: {
  client: SupabaseClient
  configured: boolean
  unavailableMessage: string
  defaultNext?: string
  errorPath?: string
  search?: string
}): Promise<RunAuthCallbackResult> {
  const result = await exchangeAuthCode(options.client, options.configured, {
    search: options.search,
    defaultNext: options.defaultNext ?? '/',
    errorPath: options.errorPath ?? '/login',
    unavailableMessage: options.unavailableMessage,
  })
  if (result.status === 'error') {
    return { status: 'error', message: result.message }
  }
  const needsMfa = await checkRequiresMfa(options.client)
  return { status: 'ok', nextPath: result.nextPath, needsMfa }
}
