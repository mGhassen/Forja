import { useProfileSettings } from '@/hooks/use-profile-settings'
import type {
  PreferencesPayload,
  StremioPayload,
  NuvioPayload,
  NavigationPayload,
} from '@/lib/sync-domains'

export function usePlaybackSetting() {
  const settings = useProfileSettings()
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.playback ?? {},
          updated_at: settings.data.updated_at,
        }
      : undefined,
    save: async (payload: PreferencesPayload) => {
      await settings.patch({ playback: payload })
    },
  }
}

export function useStremioSetting() {
  const settings = useProfileSettings()
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.connectedServices?.stremio ?? { addons: [] },
          updated_at: settings.data.updated_at,
        }
      : undefined,
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
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.connectedServices?.nuvio ?? { addons: [] },
          updated_at: settings.data.updated_at,
        }
      : undefined,
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

export function useNavigationSetting() {
  const settings = useProfileSettings()
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.navigation ?? {},
          updated_at: settings.data.updated_at,
        }
      : undefined,
    save: async (payload: NavigationPayload) => {
      await settings.patch({ navigation: payload })
    },
  }
}
