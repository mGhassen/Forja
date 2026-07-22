# RFC-004: Provider registry + resolver

**Status:** partial — registry + resolver shipped; in-player switch UI pending  
**Area:** `packages/streaming/lib/src/provider_registry.dart`, `packages/streaming/lib/src/stream_resolver.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** acceptance (core) · **7 / 10** acceptance (expansion slice) |
| **Current slice** | VidLove + VidSrc + VidSrc.sbs + VidAPI hosts shipped; VidLink anime (MAL) shipped; retired SmashyStream + PrimeWire; in-player switch + remaining expansion not started |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R04-A01 | Registry with core providers | ✅ |
| 2 | R04-A02 | Resolver tries enabled providers in order | ✅ |
| 3 | R04-A03 | Settings persist order + enabled state | ✅ |

---

## Acceptance (v1.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R04-A04 | In-player switch via ServerGrid (RFC-003) | ⬜ |
| 2 | R04-A05 | Expanded provider list | ⬜ |
| 3 | R04-A06 | `last_used_provider_id` remembered per title | ⬜ |
| 4 | R04-A07 | VidLove as separate template embed (`player.vidlove.cc`) | ✅ |
| 5 | R04-A08 | VidSrc.sbs as separate template embed (`vidsrc.sbs`) | ✅ |
| 6 | R04-A09 | Remove SmashyStream from registry, resolver, settings, and extraction | ✅ |
| 7 | R04-A10 | Remove PrimeWire from registry, resolver, settings, and extraction | ✅ |
| 8 | R04-A11 | VidSrc.win as a separate multi-server host provider; relabel the existing `vsembed.su` provider VSEmbed | ✅ |
| 9 | R04-A12 | VidAPI as template embed (`vidapi.xyz/embed/movie|tv/…`, TMDB) | ✅ |
| 10 | R04-A13 | VidLink anime embeds via AniList `idMal` (`vidlink.pro/anime/{mal}/{ep}/{sub\|dub}`) + WebView sniff | ✅ |

---

## Summary

Pluggable web stream providers with user-configurable order and mid-playback switching.

## Registry

Location: `packages/streaming/lib/src/provider_registry.dart`

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

Resolver: `packages/streaming/lib/src/stream_resolver.dart`

- `getActiveProviders()` — respects user order + enabled list
- `resolve(movie, season, episode)` — tries providers in order
- `switchProvider(id, ctx)` — re-extract at current position (v1.1 UI)

## Settings

Repo: `packages/storage/lib/src/provider_settings_repo.dart`

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
| VidLink | yes | yes (movies/TV + anime MAL) |
| VixSrc | yes | yes |
| Vidnest | yes | yes |
| 111477 | yes | yes |
| Vidzee | yes | yes |
| VidRock | yes | yes |
| RiveEmbed | | add |
| SmashyStream, VidFast | | add |
| 2Embed, AutoEmbed, MultiEmbed | | add |
| PrimeSrc, VidSrc.wtf | | add |
| VidSrc.sbs | | yes (R04-A08) |
| VidSrc.win | | yes (R04-A11) |
| VidAPI | | yes (R04-A12) |

SmashyStream was implemented during the expansion work and later retired in
R04-A09. The rollout row above is retained as historical scope.

Stremio addon streams are separate from built-in provider grid (torrent/debrid path).
