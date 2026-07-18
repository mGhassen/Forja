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
 * is unset. Clips Cloudflare’s iframe rim; the plate itself is Cloudflare’s
 * dark theme (not restylable cross-origin).
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
          'flex h-[65px] items-center text-xs text-[rgba(237,230,218,0.4)]',
          className,
        )}
      >
        Loading captcha…
      </div>
    )
  }

  return (
    <div className={cn('forja-turnstile w-fit max-w-full', className)}>
      <div className="forja-turnstile__clip">
        <Turnstile
          siteKey={turnstileSiteKey!}
          options={{ theme: 'dark', size: 'normal' }}
          onSuccess={(token) => onToken(token)}
          onExpire={() => onToken(null)}
          onError={() => onToken(null)}
          onTimeout={() => onToken(null)}
        />
      </div>
    </div>
  )
}
