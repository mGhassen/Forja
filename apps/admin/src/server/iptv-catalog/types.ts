export type CatalogPortal = {
  url: string
  username: string
  password: string
  source: string
}

export type PortalStatus = {
  alive: boolean
  status: string
  expiry: string | null
  maxConnections: string | null
  timezone: string | null
  categoryNames: string[]
  error?: string
}

export type RegionGuess = {
  primary: string
  tags: string[]
  confidence: number
}

export function portalKey(p: CatalogPortal): string {
  return `${p.url}|${p.username}|${p.password}`.toLowerCase()
}
