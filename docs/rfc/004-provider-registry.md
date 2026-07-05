# RFC-004: Provider registry + resolver

**Version:** v1.0 core / v1.1 expansion  
**Status:** Partial — registry + resolver shipped; in-player switch UI pending

## Summary

Pluggable web stream providers with user-configurable order and mid-playback switching.

## Registry

Location: `packages/forja_streaming/lib/src/provider_registry.dart`

```dart
enum ProviderKind { template, extractor, api }

class StreamProviderDef {
  final String id;
  final String displayName;
  final ProviderKind kind;
  final bool enabledByDefault;
  Future<ResolvedStream?> resolve(ResolveContext ctx);
}
```

Resolver: `packages/forja_streaming/lib/src/stream_resolver.dart`

- `getActiveProviders()` — respects user order + enabled list
- `resolve(movie, season, episode)` — tries providers in order
- `switchProvider(id, ctx)` — re-extract at current position (v1.1 UI)

## Settings

Repo: `packages/forja_storage/lib/src/provider_settings_repo.dart`

| Setting | Key |
|---------|-----|
| Provider order | `provider_order[]` |
| Enabled ids | `enabled_provider_ids[]` |
| Last used | `last_used_provider_id` |

UI: Settings → Streaming providers (reorder + toggles)

## Provider rollout

| Provider | v1.0 | v1.1 |
|----------|------|------|
| Videasy | yes | yes |
| Vidsrc | yes | yes |
| VidLink | yes | yes |
| VixSrc | yes | yes |
| Vidnest | yes | yes |
| 111477 | yes | yes |
| Vidzee | yes | yes |
| VidRock | yes | yes |
| RiveEmbed | | add |
| SmashyStream, VidFast | | add |
| 2Embed, AutoEmbed, MultiEmbed | | add |
| PrimeSrc, VidSrc.wtf | | add |

Stremio addon streams are separate from built-in provider grid (torrent/debrid path).

## Acceptance

**v1.0:**
- [x] Registry with core providers
- [x] Resolver tries enabled providers in order
- [x] Settings persist order + enabled state

**v1.1:**
- [ ] In-player switch via ServerGrid (RFC-003)
- [ ] Expanded provider list
- [ ] `last_used_provider_id` remembered per title
