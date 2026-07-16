import { ChevronDown, ChevronUp } from 'lucide-react'
import { Button } from '@/components/ui/button'

type ProviderOrderListProps = {
  items: string[]
  onChange: (items: string[]) => void
  disabled?: boolean
}

export function ProviderOrderList({ items, onChange, disabled }: ProviderOrderListProps) {
  const move = (index: number, delta: -1 | 1) => {
    const next = [...items]
    const target = index + delta
    if (target < 0 || target >= next.length) return
    const tmp = next[index]!
    next[index] = next[target]!
    next[target] = tmp
    onChange(next)
  }

  return (
    <ul className="divide-y divide-forja-border">
      {items.map((id, index) => (
        <li
          key={id}
          className="flex min-h-[52px] items-center justify-between gap-3 px-0.5 py-2.5"
        >
          <div className="min-w-0">
            <span className="text-xs text-forja-muted">#{index + 1}</span>
            <span className="ml-2 font-mono text-sm">{id}</span>
          </div>
          <div className="flex shrink-0 gap-1">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="h-8 w-8 p-0"
              disabled={disabled || index === 0}
              onClick={() => move(index, -1)}
              aria-label={`Move ${id} up`}
            >
              <ChevronUp className="size-4" />
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="h-8 w-8 p-0"
              disabled={disabled || index === items.length - 1}
              onClick={() => move(index, 1)}
              aria-label={`Move ${id} down`}
            >
              <ChevronDown className="size-4" />
            </Button>
          </div>
        </li>
      ))}
    </ul>
  )
}
