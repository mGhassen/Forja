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
      user_settings: {
        Row: {
          user_id: string
          profile_id: string
          domain: string
          payload: Json
          updated_at: string
        }
        Insert: {
          user_id: string
          profile_id: string
          domain: string
          payload: Json
          updated_at?: string
        }
        Update: {
          user_id?: string
          profile_id?: string
          domain?: string
          payload?: Json
          updated_at?: string
        }
      }
      profiles: {
        Row: {
          id: string
          user_id: string
          name: string
          color: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          name: string
          color?: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          name?: string
          color?: string
          created_at?: string
          updated_at?: string
        }
      }
      releases: {
        Row: {
          id: string
          tag: string
          version: string
          body: string | null
          published_at: string
          html_url: string | null
          source: string
          synced_at: string
        }
        Insert: {
          id?: string
          tag: string
          version: string
          body?: string | null
          published_at: string
          html_url?: string | null
          source?: string
          synced_at?: string
        }
        Update: {
          id?: string
          tag?: string
          version?: string
          body?: string | null
          published_at?: string
          html_url?: string | null
          source?: string
          synced_at?: string
        }
      }
      release_assets: {
        Row: {
          id: string
          release_id: string
          platform: string
          name: string
          download_url: string
          size_bytes: number | null
        }
        Insert: {
          id?: string
          release_id: string
          platform: string
          name: string
          download_url: string
          size_bytes?: number | null
        }
        Update: {
          id?: string
          release_id?: string
          platform?: string
          name?: string
          download_url?: string
          size_bytes?: number | null
        }
      }
      announcements: {
        Row: {
          id: string
          title: string
          body: string
          severity: string
          starts_at: string | null
          ends_at: string | null
          active: boolean
          created_at: string
        }
        Insert: {
          id?: string
          title: string
          body: string
          severity?: string
          starts_at?: string | null
          ends_at?: string | null
          active?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          title?: string
          body?: string
          severity?: string
          starts_at?: string | null
          ends_at?: string | null
          active?: boolean
          created_at?: string
        }
      }
    }
  }
}

export type Release = Database['public']['Tables']['releases']['Row']
export type ReleaseAsset = Database['public']['Tables']['release_assets']['Row']
export type UserSetting = Database['public']['Tables']['user_settings']['Row']
export type Profile = Database['public']['Tables']['profiles']['Row']
export type Announcement = Database['public']['Tables']['announcements']['Row']
