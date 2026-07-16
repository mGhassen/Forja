import { useEffect, useRef } from 'react'

/** Difference-blend custom cursor (fine pointer + motion OK only). */
export function CustomCursor() {
  const dotRef = useRef<HTMLDivElement>(null)
  const ringRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    if (!fine || reduced) return

    document.body.classList.add('cursor-on')
    const dot = dotRef.current
    const ring = ringRef.current
    if (!dot || !ring) return

    let mx = window.innerWidth / 2
    let my = window.innerHeight / 2
    let rx = mx
    let ry = my
    let raf = 0

    const onMove = (e: MouseEvent) => {
      mx = e.clientX
      my = e.clientY
      dot.style.left = `${mx}px`
      dot.style.top = `${my}px`
    }

    const loop = () => {
      rx += (mx - rx) * 0.18
      ry += (my - ry) * 0.18
      ring.style.left = `${rx}px`
      ring.style.top = `${ry}px`
      raf = requestAnimationFrame(loop)
    }

    const onEnter = () => ring.classList.add('big')
    const onLeave = () => ring.classList.remove('big')

    window.addEventListener('mousemove', onMove)
    raf = requestAnimationFrame(loop)

    const bindHoverables = () => {
      document.querySelectorAll('a, button, [data-hover]').forEach((el) => {
        el.addEventListener('mouseenter', onEnter)
        el.addEventListener('mouseleave', onLeave)
      })
    }
    bindHoverables()

    const mo = new MutationObserver(bindHoverables)
    mo.observe(document.body, { childList: true, subtree: true })

    return () => {
      document.body.classList.remove('cursor-on')
      window.removeEventListener('mousemove', onMove)
      cancelAnimationFrame(raf)
      mo.disconnect()
      document.querySelectorAll('a, button, [data-hover]').forEach((el) => {
        el.removeEventListener('mouseenter', onEnter)
        el.removeEventListener('mouseleave', onLeave)
      })
    }
  }, [])

  return (
    <>
      <div ref={dotRef} className="cur-dot" aria-hidden />
      <div ref={ringRef} className="cur-ring" aria-hidden />
    </>
  )
}
