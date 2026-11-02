/**
 * Run: npx --yes tsx packages/forja-auth/src/callback.relocate.test.ts
 */
import { relocateAuthRedirectToCallback } from './callback.ts'

function fakeLocation(init: {
  pathname: string
  search?: string
  hash?: string
}): Pick<Location, 'pathname' | 'search' | 'hash' | 'replace'> & {
  replaced: string | null
} {
  const loc = {
    pathname: init.pathname,
    search: init.search ?? '',
    hash: init.hash ?? '',
    replaced: null as string | null,
    replace(url: string) {
      loc.replaced = url
    },
  }
  return loc
}

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(msg)
}

{
  const loc = fakeLocation({ pathname: '/connect', search: '?code=ABCD1234' })
  assert(
    relocateAuthRedirectToCallback({ location: loc }) === false,
    'device-link /connect?code= must not relocate',
  )
  assert(loc.replaced === null, 'must not call replace on /connect')
}

{
  const loc = fakeLocation({
    pathname: '/login',
    search: '?next=/connect&code=ABCD1234',
  })
  assert(
    relocateAuthRedirectToCallback({ location: loc }) === false,
    'login return with device-link code must not relocate',
  )
  assert(loc.replaced === null, 'must not call replace on device-link login')
}

{
  const loc = fakeLocation({ pathname: '/', search: '?code=pkce-auth-code' })
  assert(
    relocateAuthRedirectToCallback({
      location: loc,
      defaultNext: '/account/profiles',
    }) === true,
    'Site URL ?code= (PKCE) must relocate',
  )
  assert(
    loc.replaced ===
      '/auth/callback?code=pkce-auth-code&next=%2Faccount%2Fprofiles',
    `unexpected relocate target: ${loc.replaced}`,
  )
}

{
  const loc = fakeLocation({
    pathname: '/connect',
    search: '?code=ABCD1234',
    hash: '#access_token=tok&refresh_token=rt&type=signup',
  })
  assert(
    relocateAuthRedirectToCallback({
      location: loc,
      defaultNext: '/account/profiles',
    }) === true,
    'implicit hash on /connect still relocates',
  )
  assert(
    !!loc.replaced?.startsWith('/auth/callback?') &&
      loc.replaced.includes('code=ABCD1234') &&
      loc.replaced.includes('#access_token=tok'),
    `unexpected relocate with hash: ${loc.replaced}`,
  )
}

console.log('callback.relocate.test.ts: ok')
