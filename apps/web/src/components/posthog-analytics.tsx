import { useEffect, type ReactNode } from 'react'
import { useRouter } from '@tanstack/react-router'
import {
  capturePageview,
  initWebPostHog,
  posthogConfigured,
} from '@/lib/posthog'

/**
 * Starts PostHog on the client when `VITE_POSTHOG_KEY` is set and records
 * SPA pageviews on TanStack Router navigations.
 */
export function PostHogAnalytics({ children }: { children: ReactNode }) {
  const router = useRouter()

  useEffect(() => {
    if (!posthogConfigured) return
    if (!initWebPostHog()) return

    capturePageview(window.location.href)

    return router.subscribe('onResolved', ({ toLocation }) => {
      const href = toLocation.href.startsWith('http')
        ? toLocation.href
        : `${window.location.origin}${toLocation.href}`
      capturePageview(href)
    })
  }, [router])

  return children
}
