export const LOCALES = ['en', 'fr', 'ar'] as const

export type AppLocale = (typeof LOCALES)[number]

export const LOCALE_STORAGE_KEY = 'forja.locale'

export function isAppLocale(value: string | null | undefined): value is AppLocale {
  return value === 'en' || value === 'fr' || value === 'ar'
}

export function localeDir(locale: AppLocale): 'ltr' | 'rtl' {
  return locale === 'ar' ? 'rtl' : 'ltr'
}

export function detectBrowserLocale(): AppLocale {
  if (typeof navigator === 'undefined') return 'en'
  const candidates = [navigator.language, ...(navigator.languages ?? [])]
  for (const raw of candidates) {
    const code = raw.toLowerCase().split('-')[0]
    if (code === 'fr') return 'fr'
    if (code === 'ar') return 'ar'
  }
  return 'en'
}

export function readStoredLocale(): AppLocale | null {
  if (typeof localStorage === 'undefined') return null
  try {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY)
    return isAppLocale(stored) ? stored : null
  } catch {
    return null
  }
}

export function writeStoredLocale(locale: AppLocale): void {
  if (typeof localStorage === 'undefined') return
  try {
    localStorage.setItem(LOCALE_STORAGE_KEY, locale)
  } catch {
    // Ignore quota / private-mode failures.
  }
}

export function resolveInitialLocale(): AppLocale {
  return readStoredLocale() ?? detectBrowserLocale()
}

export function applyDocumentLocale(locale: AppLocale): void {
  if (typeof document === 'undefined') return
  document.documentElement.lang = locale
  document.documentElement.dir = localeDir(locale)
}
