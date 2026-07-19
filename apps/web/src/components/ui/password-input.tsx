import {
  useState,
  useRef,
  forwardRef,
  useCallback,
  type InputHTMLAttributes,
  type MouseEvent,
} from 'react'
import { Eye, EyeOff } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'

export const PasswordInput = forwardRef<
  HTMLInputElement,
  Omit<InputHTMLAttributes<HTMLInputElement>, 'type'>
>(({ className, disabled, ...props }, ref) => {
  const [visible, setVisible] = useState(false)
  const inputRef = useRef<HTMLInputElement | null>(null)

  const setRefs = useCallback(
    (node: HTMLInputElement | null) => {
      inputRef.current = node
      if (typeof ref === 'function') ref(node)
      else if (ref) ref.current = node
    },
    [ref],
  )

  const toggleVisible = () => {
    const input = inputRef.current
    const start = input?.selectionStart ?? null
    const end = input?.selectionEnd ?? null
    setVisible((v) => !v)
    // type flip selects-all in some browsers; restore caret
    requestAnimationFrame(() => {
      if (input && start != null && end != null) {
        input.setSelectionRange(start, end)
      }
    })
  }

  return (
    <div className="relative">
      <Input
        ref={setRefs}
        type={visible ? 'text' : 'password'}
        disabled={disabled}
        className={cn('pr-11', className)}
        {...props}
      />
      <button
        type="button"
        tabIndex={-1}
        disabled={disabled}
        aria-label={visible ? 'Hide password' : 'Show password'}
        onMouseDown={(e: MouseEvent<HTMLButtonElement>) => e.preventDefault()}
        onClick={toggleVisible}
        className="absolute top-1/2 right-2.5 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-[rgba(237,230,218,0.45)] transition-colors hover:text-[#EDE6DA] disabled:pointer-events-none disabled:opacity-40"
      >
        {visible ? (
          <EyeOff className="h-4 w-4" aria-hidden />
        ) : (
          <Eye className="h-4 w-4" aria-hidden />
        )}
      </button>
    </div>
  )
})
PasswordInput.displayName = 'PasswordInput'
