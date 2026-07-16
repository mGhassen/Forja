import { cn } from '@/lib/utils'

type SettingsToggleProps = {
  label: string
  description?: string
  checked: boolean
  onChange: (checked: boolean) => void
  disabled?: boolean
}

export function SettingsToggle({
  label,
  description,
  checked,
  onChange,
  disabled,
}: SettingsToggleProps) {
  return (
    <label
      className={cn(
        'flex cursor-pointer items-start justify-between gap-4 rounded-lg border border-forja-border bg-forja-surface/60 px-4 py-3',
        disabled && 'cursor-not-allowed opacity-60',
      )}
    >
      <span className="min-w-0">
        <span className="block text-sm font-medium">{label}</span>
        {description ? (
          <span className="mt-1 block text-sm text-forja-muted">{description}</span>
        ) : null}
      </span>
      <input
        type="checkbox"
        className="mt-1 size-4 shrink-0 accent-forja-green"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
    </label>
  )
}
