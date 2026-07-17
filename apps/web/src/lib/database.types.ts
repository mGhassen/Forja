export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      accounts: {
        Row: {
          id: string
          email: string | null
          is_admin: boolean
          features: Json
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          id: string
          email?: string | null
          is_admin?: boolean
          features?: Json
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          id?: string
          email?: string | null
          is_admin?: boolean
          features?: Json
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
      profiles: {
        Row: {
          id: string
          account_id: string
          name: string
          color: string
          avatar_key: string
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          id?: string
          account_id: string
          name: string
          color?: string
          avatar_key?: string
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          id?: string
          account_id?: string
          name?: string
          color?: string
          avatar_key?: string
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
      profile_settings: {
        Row: {
          profile_id: string
          account_id: string
          payload: Json
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          profile_id: string
          account_id: string
          payload?: Json
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          profile_id?: string
          account_id?: string
          payload?: Json
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
      iptv_portals: {
        Row: {
          id: string
          url: string
          username: string
          password: string
          source: string | null
          expiry: string | null
          max_connections: string | null
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          id?: string
          url: string
          username: string
          password: string
          source?: string | null
          expiry?: string | null
          max_connections?: string | null
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          id?: string
          url?: string
          username?: string
          password?: string
          source?: string | null
          expiry?: string | null
          max_connections?: string | null
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
      user_iptv_portals: {
        Row: {
          id: string
          account_id: string
          profile_id: string
          portal_id: string
          /** Per-profile display name for this assignment. */
          portal_name: string
          favorite: boolean
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          id?: string
          account_id: string
          profile_id: string
          portal_id: string
          portal_name?: string
          favorite?: boolean
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          id?: string
          account_id?: string
          profile_id?: string
          portal_id?: string
          portal_name?: string
          favorite?: boolean
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
    }
    Functions: {
      is_admin: { Args: Record<string, never>; Returns: boolean }
      upsert_iptv_portal: {
        Args: {
          p_url: string
          p_username: string
          p_password: string
          p_source?: string | null
          p_expiry?: string | null
          p_max_connections?: string | null
        }
        Returns: string
      }
      get_iptv_portals: {
        Args: { p_ids: string[] }
        Returns: Database['public']['Tables']['iptv_portals']['Row'][]
      }
    }
  }
}

export type Account = Database['public']['Tables']['accounts']['Row']
export type Profile = Database['public']['Tables']['profiles']['Row']
export type ProfileSetting = Database['public']['Tables']['profile_settings']['Row']
export type IptvPortal = Database['public']['Tables']['iptv_portals']['Row']
export type UserIptvPortal = Database['public']['Tables']['user_iptv_portals']['Row']

/** Local shape for download page (GitHub Releases only). */
export type ReleaseAsset = {
  id: string
  release_id: string
  platform: string
  name: string
  download_url: string
  size_bytes: number | null
}

export type Release = {
  id: string
  tag: string
  version: string
  body: string | null
  published_at: string
  html_url: string | null
  source: string
  synced_at: string
}
