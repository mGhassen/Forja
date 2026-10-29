/**
 * Installer filename → release platform key.
 *
 * Keys match the R2 / update manifest `platforms` map. Pure module (no `@/`
 * imports) so `node --test` can load it directly.
 */

export type ReleasePlatformKey =
  | 'windows'
  | 'macos'
  | 'linux'
  | 'android_tv'
  | 'android_mobile'
  | 'ios'
  | 'other'

export function detectPlatformFromFilename(name: string): ReleasePlatformKey {
  const lower = name.toLowerCase()
  if (lower.includes('windows') || lower.endsWith('.exe') || lower.endsWith('.msi')) {
    return 'windows'
  }
  if (lower.includes('macos') || lower.includes('darwin') || lower.endsWith('.dmg')) {
    return 'macos'
  }
  if (
    lower.includes('linux') ||
    lower.endsWith('.appimage') ||
    lower.endsWith('.deb') ||
    lower.endsWith('.rpm')
  ) {
    return 'linux'
  }
  // Phone APK: `Forja-<v>-android-mobile-<abi>.apk`.
  if (lower.includes('android-mobile') || lower.includes('android_mobile')) {
    return 'android_mobile'
  }
  if (
    lower.includes('android-tv') ||
    lower.includes('android_tv') ||
    lower.includes('androidtv')
  ) {
    return 'android_tv'
  }
  // Unlabelled APKs predate the phone build and are all Android TV.
  if (lower.endsWith('.apk') || lower.includes('android')) {
    return 'android_tv'
  }
  if (lower.includes('ios') || lower.endsWith('.ipa')) {
    return 'ios'
  }
  return 'other'
}
