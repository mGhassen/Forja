import { useEffect, useRef, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

type RevealVariant = 'up' | 'left' | 'right' | 'scale' | 'fade'

export function Reveal({
  children,
  className = '',
  delayMs = 0,
  variant = 'up',
}: {
  children: ReactNode
  className?: string
  delayMs?: number
  variant?: RevealVariant
}) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduced) {
      el.classList.add('is-visible')
      return
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          el.classList.add('is-visible')
          observer.unobserve(el)
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -10% 0px' },
    )

    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <div
      ref={ref}
      className={cn('reveal', `reveal-${variant}`, className)}
      style={delayMs ? { transitionDelay: `${delayMs}ms` } : undefined}
    >
      {children}
    </div>
  )
}
