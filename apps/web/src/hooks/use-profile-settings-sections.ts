import { useProfileSettings } from '@/hooks/use-profile-settings'
import type {
  PreferencesPayload,
  ProvidersPayload,
  StremioPayload,
  IptvSettingsPayload,
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

export function useProvidersSetting() {
  const settings = useProfileSettings()
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.connectedServices?.providers ?? {},
          updated_at: settings.data.updated_at,
        }
      : undefined,
    save: async (payload: ProvidersPayload) => {
      await settings.patch({
        connectedServices: {
          ...settings.data?.payload.connectedServices,
          providers: payload,
        },
      })
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

/** M3U URL metadata only — portal assignments use `useUserIptvPortals`. */
export function useIptvSetting() {
  const settings = useProfileSettings()
  return {
    ...settings,
    data: settings.data
      ? {
          payload: settings.data.payload.iptv ?? { m3uPlaylists: [] },
          updated_at: settings.data.updated_at,
        }
      : undefined,
    save: async (payload: IptvSettingsPayload) => {
      await settings.patch({ iptv: { m3uPlaylists: payload.m3uPlaylists } })
    },
  }
}
