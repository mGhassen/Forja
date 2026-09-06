import { useMemo } from 'react'
import { useProfileSettings } from '@/hooks/use-profile-settings'
import type {
  PreferencesPayload,
  StremioPayload,
  NuvioPayload,
  ForjaPayload,
  NavigationPayload,
} from '@/lib/sync-domains'
import {
  navigationAfterForjaPacksChange,
} from '@/lib/sync-domains'

/**
 * Slice `profile_settings` into per-page hooks.
 *
 * `data` must be referentially stable across renders — settings pages hydrate
 * local drafts from `useEffect(..., [data])`. A fresh object every render
 * resets the draft and makes toggles / edits appear stuck.
 */
export function usePlaybackSetting() {
  const settings = useProfileSettings()
  const data = useMemo(
    () =>
      settings.data
        ? {
            payload: settings.data.payload.playback ?? {},
            updated_at: settings.data.updated_at,
          }
        : undefined,
    [settings.data],
  )
  return {
    ...settings,
    data,
    save: async (payload: PreferencesPayload) => {
      await settings.patch({ playback: payload })
    },
  }
}

export function useStremioSetting() {
  const settings = useProfileSettings()
  const data = useMemo(
    () =>
      settings.data
        ? {
            payload: settings.data.payload.connectedServices?.stremio ?? {
              addons: [],
            },
            updated_at: settings.data.updated_at,
          }
        : undefined,
    [settings.data],
  )
  return {
    ...settings,
    data,
    save: async (payload: StremioPayload) => {
      await settings.patch({
        connectedServices: {
          ...settings.data?.payload.connectedServices,
          stremio: payload,
        },
      })
    },
  }
}

export function useNuvioSetting() {
  const settings = useProfileSettings()
  const data = useMemo(
    () =>
      settings.data
        ? {
            payload: settings.data.payload.connectedServices?.nuvio ?? {
              addons: [],
            },
            updated_at: settings.data.updated_at,
          }
        : undefined,
    [settings.data],
  )
  return {
    ...settings,
    data,
    save: async (payload: NuvioPayload) => {
      await settings.patch({
        connectedServices: {
          ...settings.data?.payload.connectedServices,
          nuvio: payload,
        },
      })
    },
  }
}

export function useForjaSetting() {
  const settings = useProfileSettings()
  const data = useMemo(
    () =>
      settings.data
        ? {
            payload: settings.data.payload.connectedServices?.forja ?? {
              packs: [],
            },
            updated_at: settings.data.updated_at,
          }
        : undefined,
    [settings.data],
  )
  return {
    ...settings,
    data,
    save: async (payload: ForjaPayload) => {
      const current = settings.data?.payload
      const navigation = navigationAfterForjaPacksChange({
        navigation: current?.navigation,
        prevPacks: current?.connectedServices?.forja?.packs ?? [],
        nextPacks: payload.packs ?? [],
        addonFeatureIptv: current?.playback?.addon_feature_iptv,
        addonFeatureLiveMatches: current?.playback?.addon_feature_live_matches,
      })
      await settings.patch({
        connectedServices: {
          ...current?.connectedServices,
          forja: payload,
        },
        navigation,
      })
    },
  }
}

export function useNavigationSetting() {
  const settings = useProfileSettings()
  const data = useMemo(
    () =>
      settings.data
        ? {
            payload: settings.data.payload.navigation ?? {},
            updated_at: settings.data.updated_at,
          }
        : undefined,
    [settings.data],
  )
  return {
    ...settings,
    data,
    save: async (payload: NavigationPayload) => {
      await settings.patch({ navigation: payload })
    },
  }
}
