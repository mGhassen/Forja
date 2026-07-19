import { useCallback, useState } from 'react'

/**
 * Turnstile wiring: token + reset + readiness.
 * Host passes whether captcha is configured (from its env).
 */
export function useCaptcha(captchaConfigured: boolean) {
  const [token, setToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)

  const onToken = useCallback((next: string | null) => {
    setToken(next)
  }, [])

  const reset = useCallback(() => {
    setToken(null)
    setCaptchaKey((k) => k + 1)
  }, [])

  return {
    configured: captchaConfigured,
    token,
    captchaKey,
    onToken,
    reset,
    isReady: !captchaConfigured || !!token,
  }
}
