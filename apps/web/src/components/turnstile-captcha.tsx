import { useEffect, useState } from 'react'
import { Turnstile } from '@marsidev/react-turnstile'
import { captchaConfigured, turnstileSiteKey } from '@/lib/captcha'
import { cn } from '@/lib/utils'

type TurnstileCaptchaProps = {
  onToken: (token: string | null) => void
  className?: string
}

/**
 * Client-only Turnstile widget. Renders nothing when `VITE_TURNSTILE_SITE_KEY`
 * is unset (local without captcha). Resets token on expire / error.
 */
export function TurnstileCaptcha({ onToken, className }: TurnstileCaptchaProps) {
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  useEffect(() => {
    if (!captchaConfigured) onToken(null)
  }, [onToken])

  if (!captchaConfigured) return null

  if (!mounted) {
    return (
      <div
        className={cn(
          'flex h-[65px] items-center rounded-lg border border-[rgba(237,230,218,0.12)] bg-[#0B0A0A] px-3 text-xs text-[rgba(237,230,218,0.4)]',
          className,
        )}
      >
        Loading captcha…
      </div>
    )
  }

  return (
    <div className={cn('overflow-hidden rounded-lg', className)}>
      <Turnstile
        siteKey={turnstileSiteKey!}
        options={{ theme: 'dark', size: 'flexible' }}
        onSuccess={(token) => onToken(token)}
        onExpire={() => onToken(null)}
        onError={() => onToken(null)}
        onTimeout={() => onToken(null)}
      />
    </div>
  )
}
