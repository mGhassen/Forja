import {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { createPortal } from 'react-dom'
import { MoreHorizontal } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

export type RowActionItem =
  | {
      type?: 'item'
      label: string
      icon?: ReactNode
      disabled?: boolean
      destructive?: boolean
      onSelect: () => void
    }
  | {
      type: 'link'
      label: string
      icon?: ReactNode
      href: string
    }
  | { type: 'separator' }

export function RowActionsMenu({
  items,
  disabled,
  align = 'end',
}: {
  items: RowActionItem[]
  disabled?: boolean
  align?: 'start' | 'end'
}) {
  const [open, setOpen] = useState(false)
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  const menuId = useId()

  useLayoutEffect(() => {
    if (!open || !triggerRef.current) {
      setPos(null)
      return
    }
    const place = () => {
      const r = triggerRef.current!.getBoundingClientRect()
      const menuW = menuRef.current?.offsetWidth ?? 176
      const menuH = menuRef.current?.offsetHeight ?? 0
      let left = align === 'end' ? r.right - menuW : r.left
      left = Math.max(8, Math.min(left, window.innerWidth - menuW - 8))
      let top = r.bottom + 4
      if (top + menuH > window.innerHeight - 8 && r.top > menuH + 8) {
        top = r.top - menuH - 4
      }
      setPos({ top, left })
    }
    place()
    window.addEventListener('scroll', place, true)
    window.addEventListener('resize', place)
    return () => {
      window.removeEventListener('scroll', place, true)
      window.removeEventListener('resize', place)
    }
  }, [open, align, items.length])

  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => {
      const t = e.target as Node
      if (triggerRef.current?.contains(t) || menuRef.current?.contains(t)) {
        return
      }
      setOpen(false)
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  const menu =
    open && typeof document !== 'undefined'
      ? createPortal(
          <div
            ref={menuRef}
            id={menuId}
            role="menu"
            style={
              pos
                ? { top: pos.top, left: pos.left }
                : { top: -9999, left: -9999 }
            }
            className="fixed z-[80] min-w-44 overflow-hidden rounded-md border border-forja-border bg-forja-elevated p-1 text-forja-text shadow-xl"
          >
            {items.map((item, i) => {
              if (item.type === 'separator') {
                return (
                  <div
                    key={`sep-${i}`}
                    role="separator"
                    className="my-1 h-px bg-forja-border"
                  />
                )
              }
              if (item.type === 'link') {
                return (
                  <a
                    key={item.href + item.label}
                    role="menuitem"
                    href={item.href}
                    target="_blank"
                    rel="noreferrer"
                    className="flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none transition-colors hover:bg-white/8 focus:bg-white/8"
                    onClick={() => setOpen(false)}
                  >
                    {item.icon}
                    {item.label}
                  </a>
                )
              }
              return (
                <button
                  key={item.label}
                  type="button"
                  role="menuitem"
                  disabled={item.disabled}
                  className={cn(
                    'flex w-full cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-left text-sm outline-none transition-colors hover:bg-white/8 focus:bg-white/8 disabled:pointer-events-none disabled:opacity-50',
                    item.destructive && 'text-red-400 hover:text-red-300',
                  )}
                  onClick={() => {
                    setOpen(false)
                    item.onSelect()
                  }}
                >
                  {item.icon}
                  {item.label}
                </button>
              )
            })}
          </div>,
          document.body,
        )
      : null

  return (
    <>
      <Button
        ref={triggerRef}
        type="button"
        size="sm"
        variant="ghost"
        className="size-8 px-0"
        disabled={disabled}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        aria-label="Row actions"
        onClick={() => setOpen((v) => !v)}
      >
        <MoreHorizontal className="size-4" />
      </Button>
      {menu}
    </>
  )
}
