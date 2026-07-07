# RFC-002: IPTV portal groups

**Version:** v1.0  
**Status:** fixed  
**Target version:** [0.0.1](../backlog/done/0.0.1-[done].md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** acceptance (v1.0) |
| **Backlog** | [0.0.1](../backlog/done/0.0.1-[done].md) |

## Summary

Organize Xtream portals into color-coded groups with metadata (expiry, connections) persisted locally.

## Models

```dart
class PortalGroup {
  final String id;
  final String name;
  final int colorArgb;
  final List<String> portalKeys;
}

class PortalMeta {
  final String portalKey;
  final String? groupId;
  final DateTime? lastVerifiedAt;
  final DateTime? expiry;
  final int? maxConnections;
  final int? activeConnections;
}
```

## Storage

| Key | Repo |
|-----|------|
| `forja_iptv_groups` | `IptvSettingsRepo` |
| `forja_iptv_portal_meta` | `IptvSettingsRepo` |

Implementation: `packages/storage/lib/src/iptv_settings_repo.dart`

## UI

Feature code: `apps/forja/lib/features/iptv/`

- `iptv/screens/iptv_pt_screen.dart` — portal dashboard, Live/VOD/Series
- `iptv/m3u/` — M3U playlists, parser, store
- `iptv/controller/iptv_controller.dart` — session state
- `iptv/data/` — models, network, storage, decryptor

## v1.2 extension

Portal credentials sync via RFC-006 (encrypted blob in Supabase).

## Acceptance (v1.0)

- [x] Create/rename/delete groups
- [x] Assign portals to groups
- [x] Portal meta displayed on dashboard
- [x] M3U playlists alongside Xtream
