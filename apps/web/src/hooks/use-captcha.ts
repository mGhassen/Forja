import { useCallback, useState } from 'react'
import { captchaConfigured } from '@/lib/captcha'

/**
 * Turnstile wiring shape (Guepard-style): token + reset + readiness.
 * Pair with `<TurnstileCaptcha key={captchaKey} onToken={onToken} />`.
 */
export function useCaptcha() {
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
