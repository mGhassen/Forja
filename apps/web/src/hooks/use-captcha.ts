import { useCaptcha as useSharedCaptcha } from '@forja/auth/react'
import { captchaConfigured } from '@/lib/captcha'

export function useCaptcha() {
  return useSharedCaptcha(captchaConfigured)
}
