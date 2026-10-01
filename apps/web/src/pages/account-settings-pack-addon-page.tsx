import { useEffect, useMemo, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { SettingsToggle } from '@/components/settings-toggle'
import { Label } from '@/components/ui/label'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import {
  useForjaSetting,
  usePackSettingsSetting,
} from '@/hooks/use-user-setting'
import {
  defaultValueForField,
  isSecretField,
  listHubSelectOptions,
  loadPackAddonBucket,
  type HubSelectOption,
  type PackAddonBucket,
  type PackSettingsField,
} from '@/lib/pack-addon-discovery'
import {
  emptyForjaPayload,
  type ForjaPayload,
  type PackSettingsPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return {
    packs: payload?.packs ?? [],
    ...(payload?.onboarded === true ? { onboarded: true as const } : {}),
  }
}

function packSettingsFromServer(value: unknown): PackSettingsPayload {
  if (!value || typeof value !== 'object') return {}
  return value as PackSettingsPayload
}

function emptyPackSettings(): PackSettingsPayload {
  return {}
}

function readFieldValue(
  draft: PackSettingsPayload,
  field: PackSettingsField,
): boolean | string | string[] {
  const plugin = draft[field.pluginId]
  if (plugin && field.id in plugin) {
    return plugin[field.id]!
  }
  return defaultValueForField(field)
}

function hubOptionsForField(
  field: PackSettingsField,
  hubs: HubSelectOption[],
): Array<{ id: string; label: string }> {
  const want = new Set(
    (field.hubTypes ?? []).map((t) => t.trim()).filter(Boolean),
  )
  const out: Array<{ id: string; label: string }> = [
    { id: '', label: 'Auto' },
  ]
  for (const hub of hubs) {
    if (want.size > 0 && !hub.types.some((t) => want.has(t))) continue
    out.push({ id: hub.pluginId, label: hub.label })
  }
  return out
}

function FieldControl({
  field,
  value,
  disabled,
  hubOptions,
  onChange,
}: {
  field: PackSettingsField
  value: boolean | string | string[]
  disabled?: boolean
  hubOptions: HubSelectOption[]
  onChange: (next: boolean | string | string[]) => void
}) {
  if (field.type === 'toggle') {
    return (
      <SettingsToggle
        label={field.label}
        description={field.subtitle}
        checked={value === true}
        onChange={(v) => onChange(v)}
        disabled={disabled}
      />
    )
  }

  if (field.type === 'select') {
    const options = field.options ?? []
    const current = typeof value === 'string' ? value : ''
    return (
      <div className="flex min-h-14.5 flex-col gap-2 px-0.5 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <p className="text-sm font-medium text-forja-text">{field.label}</p>
          {field.subtitle ? (
            <p className="mt-1 text-sm text-forja-muted">{field.subtitle}</p>
          ) : null}
        </div>
        <select
          className="h-9 min-w-40 rounded-none border border-forja-border bg-forja-bg px-2 text-sm text-forja-text"
          value={current}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
          aria-label={field.label}
        >
          {options.map((o) => (
            <option key={o.id} value={o.id}>
              {o.label}
            </option>
          ))}
        </select>
      </div>
    )
  }

  if (field.type === 'hub_select') {
    const options = hubOptionsForField(field, hubOptions)
    const current = typeof value === 'string' ? value : ''
    return (
      <div className="flex min-h-14.5 flex-col gap-2 px-0.5 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <p className="text-sm font-medium text-forja-text">{field.label}</p>
          {field.subtitle ? (
            <p className="mt-1 text-sm text-forja-muted">{field.subtitle}</p>
          ) : null}
        </div>
        <select
          className="h-9 min-w-40 rounded-none border border-forja-border bg-forja-bg px-2 text-sm text-forja-text"
          value={current}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
          aria-label={field.label}
        >
          {options.map((o) => (
            <option key={o.id || '__none'} value={o.id}>
              {o.label}
            </option>
          ))}
        </select>
      </div>
    )
  }

  if (field.type === 'multi_select') {
    const selected = new Set(
      Array.isArray(value) ? value.map(String) : [],
    )
    const options = field.options ?? []
    return (
      <div className="px-0.5 py-3">
        <p className="text-sm font-medium text-forja-text">{field.label}</p>
        {field.subtitle ? (
          <p className="mt-1 text-sm text-forja-muted">{field.subtitle}</p>
        ) : null}
        <div className="mt-3 flex flex-wrap gap-2">
          {options.map((o) => {
            const on = selected.has(o.id)
            return (
              <button
                key={o.id}
                type="button"
                disabled={disabled}
                onClick={() => {
                  const next = new Set(selected)
                  if (on) next.delete(o.id)
                  else next.add(o.id)
                  onChange([...next])
                }}
                className={cn(
                  'rounded-none border px-2.5 py-1 text-xs transition',
                  on
                    ? 'border-forja-green bg-forja-green/15 text-forja-green'
                    : 'border-forja-border text-forja-muted hover:border-forja-green/40',
                  disabled && 'opacity-60',
                )}
              >
                {o.label}
              </button>
            )
          })}
        </div>
      </div>
    )
  }

  if (field.type === 'text') {
    const current = typeof value === 'string' ? value : ''
    return (
      <div className="px-0.5 py-3">
        <Label htmlFor={`pack-${field.pluginId}-${field.id}`}>
          {field.label}
        </Label>
        {field.subtitle ? (
          <p className="mt-1 text-sm text-forja-muted">{field.subtitle}</p>
        ) : null}
        <input
          id={`pack-${field.pluginId}-${field.id}`}
          type="text"
          className="mt-2 h-9 w-full rounded-none border border-forja-border bg-forja-bg px-2 text-sm"
          value={current}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
        />
      </div>
    )
  }

  return null
}

export type AccountSettingsPackAddonPageProps = {
  addonId: string
}

/**
 * Pack-contributed Addon detail — RFC-089 fields synced via packSettings.
 */
export function AccountSettingsPackAddonPage({
  addonId,
}: AccountSettingsPackAddonPageProps) {
  const forja = useForjaSetting()
  const packSettings = usePackSettingsSetting()
  const [bucket, setBucket] = useState<PackAddonBucket | null>(null)
  const [hubOptions, setHubOptions] = useState<HubSelectOption[]>([])
  const [loading, setLoading] = useState(true)

  const packsDraft = useCommitDraft({
    profileId: forja.profileId,
    updatedAt: forja.data?.updated_at,
    isReady: Boolean(forja.data) && !forja.isLoading,
    serverValue: forja.data?.payload,
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save: forja.save,
  })

  const {
    draft,
    commit,
    controlsLocked,
    isSaving,
    savedFlash,
    saveError,
  } = useCommitDraft({
    profileId: packSettings.profileId,
    updatedAt: packSettings.data?.updated_at,
    isReady: Boolean(packSettings.data) && !packSettings.isLoading,
    serverValue: packSettings.data?.payload,
    mapServer: packSettingsFromServer,
    makeEmpty: emptyPackSettings,
    save: packSettings.save,
  })

  const packs = packsDraft.draft.packs
  const packsKey = useMemo(
    () =>
      packs
        .map((p) => `${p.manifestUrl}|${p.enabled !== false ? 1 : 0}`)
        .sort()
        .join('\n'),
    [packs],
  )

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      try {
        const [hit, hubs] = await Promise.all([
          loadPackAddonBucket(packs, addonId),
          listHubSelectOptions(packs),
        ])
        if (!cancelled) {
          setBucket(hit)
          setHubOptions(hubs)
        }
      } catch {
        if (!cancelled) {
          setBucket(null)
          setHubOptions([])
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [addonId, packsKey, packs])

  const setField = (field: PackSettingsField, value: boolean | string | string[]) => {
    void commit((prev) => {
      const plugin = { ...(prev[field.pluginId] ?? {}) }
      plugin[field.id] = value
      return { ...prev, [field.pluginId]: plugin }
    })
  }

  const editableFields = (bucket?.fields ?? []).filter((f) => !isSecretField(f))
  const secretFields = (bucket?.fields ?? []).filter((f) => isSecretField(f))

  const groups = useMemo(() => {
    const map = new Map<string, PackSettingsField[]>()
    for (const f of editableFields) {
      const list = map.get(f.group) ?? []
      list.push(f)
      map.set(f.group, list)
    }
    return [...map.entries()]
  }, [editableFields])

  const title = bucket?.title ?? addonId
  const busy = controlsLocked || isSaving

  return (
    <AccountSettingsShell
      title={title}
      description={`Addons → ${title} — pack settings for this profile. Changes sync to your Forja devices.`}
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={saveError}
        />
      }
    >
      {loading ? (
        <p className="text-sm text-forja-muted">Loading pack settings…</p>
      ) : !bucket ? (
        <SettingsSection label="Not on this profile">
          <p className="text-sm text-forja-muted">
            This pack settings page only appears when the matching pack is
            enabled under{' '}
            <Link
              to="/account/settings/forja"
              className="text-forja-green hover:underline"
            >
              Forja Packs
            </Link>
            .
          </p>
        </SettingsSection>
      ) : (
        <>
          {groups.length === 0 && secretFields.length === 0 ? (
            <SettingsSection label="Pack">
              <p className="text-sm text-forja-muted">
                This pack contributes an Addons row but has no cloud-editable
                fields. Use the Forja app for any local options.
              </p>
            </SettingsSection>
          ) : null}

          {groups.map(([group, fields]) => (
            <SettingsSection key={group} label={group}>
              {fields.map((field) => (
                <div
                  key={`${field.pluginId}:${field.id}`}
                  className="border-b border-forja-border/60 last:border-b-0"
                >
                  <FieldControl
                    field={field}
                    value={readFieldValue(draft, field)}
                    disabled={busy}
                    hubOptions={hubOptions}
                    onChange={(v) => setField(field, v)}
                  />
                </div>
              ))}
            </SettingsSection>
          ))}

          {secretFields.length > 0 ? (
            <SettingsSection
              label="App only"
              description="API keys and passwords stay on the device — they do not sync to the web portal."
            >
              <ul className="space-y-2 px-0.5 py-2 text-sm text-forja-muted">
                {secretFields.map((f) => (
                  <li key={`${f.pluginId}:${f.id}`}>
                    <span className="font-medium text-forja-text">
                      {f.group}: {f.label}
                    </span>
                    {f.subtitle ? ` — ${f.subtitle}` : ''}
                    {' · '}
                    configure in the Forja app under Addons → {title}
                  </li>
                ))}
              </ul>
            </SettingsSection>
          ) : null}
        </>
      )}
    </AccountSettingsShell>
  )
}
