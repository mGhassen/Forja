import { supabase } from '@/lib/supabase'

/**
 * Catalog-ops tables/RPCs land with RFC-040 migrations; generated
 * `Database` types may lag until regenerating. Untyped access for ops only.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const adminDb = supabase as any
