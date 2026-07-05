# RFC-002: IPTV portal groups

## Models

- `PortalGroup { id, name, colorArgb, portalKeys[] }`
- `PortalMeta { portalKey, groupId, lastVerifiedAt, expiry, maxConnections, activeConnections }`

## Storage keys

- `forja_iptv_groups`
- `forja_iptv_portal_meta`

Implemented in `packages/forja_storage/lib/src/iptv_settings_repo.dart`.
