export {
  usePlaybackSetting,
  useStremioSetting,
  useNuvioSetting,
  useNavigationSetting,
} from '@/hooks/use-profile-settings-sections'

// Re-export profile settings for callers that need the full payload.
export { useProfileSettings } from '@/hooks/use-profile-settings'
