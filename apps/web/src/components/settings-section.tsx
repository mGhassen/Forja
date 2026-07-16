import type { ReactNode } from 'react'

type SettingsSectionProps = {
  label: string
  description?: string
  children: ReactNode
}

export function SettingsSection({
  label,
  description,
  children,
}: SettingsSectionProps) {
  return (
    <section className="mb-10">
      <div className="mb-1 flex items-center gap-2.5">
        <span className="h-0.5 w-3.5 bg-forja-green" />
        <h3 className="text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green">
          {label}
        </h3>
      </div>
      {description ? (
        <p className="mb-3 ml-6 text-xs leading-5 text-forja-muted">{description}</p>
      ) : null}
      <div className="divide-y divide-forja-border">{children}</div>
    </section>
  )
}
