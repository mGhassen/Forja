# 003 — Match Stremio platform playback model

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `apps/forja`, `packages/streaming`, `packages/api`, `crates/torrent`, `crates/stremio-core`  
**Reported:** 2026-07-06

## Summary

Forja implements the Stremio **addon protocol** (manifest, catalog, meta, stream, subtitles) but does not follow Stremio's **platform-constrained playback model**. On every native target, `infoHash` streams always route through the local torrent engine (librqbit + axum localhost URL). Stremio restricts that path to desktop and Android; TV apps resolve streams to direct URLs only. Forja has no TV targets yet, but web (RFC-010) and future constrained platforms need the same split before shipping.

## Reference: how Stremio does it

| Platform | Torrent engine | Playback model |
|----------|----------------|----------------|
| Desktop, Android | Built-in (local HTTP from pieces) | `url` → native player; `infoHash` → local engine |
| Samsung Tizen (2021+), LG webOS (2020+, webOS 5.0+) | None | Resolve addon stream to a **direct URL**; TV native player only |
| NuvioTV (Tizen / webOS) | None | Web shell; metadata browse + addon-resolved URLs only |

Forja today maps to **desktop Stremio everywhere** — there is no URL-only profile.

## Current behavior

### Stremio addon playback (`details_screen.dart`, `_playStremioStream`)

1. `stream['url']` → `PlayerScreen` with `activeProvider: 'stremio_direct'`.
2. `stream['infoHash']` → magnet → debrid (if enabled) **or** `TorrentStreamService().streamTorrent()` (librqbit).
3. `stream['externalUrl']` → `stremio://` deep links or web URLs.

No platform gate. Torrentio-style addons require librqbit on iOS, macOS, Windows, Linux, and Android alike.

### Direct streaming mode (`streaming_details_screen.dart`)

- Primary path: WebStreamr / VidLink / Nuvio / 111477 provider chain — URL resolution, no torrent list UI.
- Stremio addons are loaded (`getAddonsForResource('stream')`) but secondary; default source is `'forja'`.
- Stremio extraction in this screen fetches streams but does not mirror the full `_playStremioStream` branching (no torrent/debrid resolve wired the same way as torrent details).

### What already aligns

- Addon install, catalog rails, search, subtitles — same Stremio manifest protocol.
- Desktop/Android torrent path — librqbit session + axum localhost stream URL (same pattern as Stremio desktop).
- Debrid bypass for `infoHash` — produces a direct URL without local torrent engine.

### Gaps

| Gap | Detail |
|-----|--------|
| No playback capability profile | Engine starts on all platforms; no `canPlayTorrents` / `urlOnly` flag |
| Web / WASM (RFC-010) | Planned torrent-less client; no shared abstraction yet |
| TV (Tizen / webOS) | Not in repo; no issue-tracked playback constraints |
| `infoHash` on constrained platforms | Would fail or need debrid — no graceful fallback or UI |
| Direct streaming ≠ Stremio TV mode | WebStreamr-first, not addon-ecosystem-only; torrent engine still ships |
| Inconsistent Stremio play paths | `details_screen` vs `streaming_details_screen` handle addons differently |

## Impact

- **Future TV / web builds** cannot ship without either bundling librqbit (infeasible on Tizen/webOS) or hiding hash-based addons with no alternative.
- **iOS** users on hash-only addons (Torrentio without debrid) hit a heavy local engine where Stremio may prefer Real-Debrid or direct-URL addons.
- **UX mismatch** — users expecting Stremio TV behavior (pick addon → play URL) get torrent engine spinners on `infoHash` streams even in direct streaming mode.
- **RFC-010 duplication** — web client capability matrix redefines constraints ad hoc instead of one engine-level profile.

## Proposed fix

Introduce a **playback capability profile** consumed by UI and stream resolution — not a new feature, a platform gate.

### 1. Capability model

```text
PlaybackProfile {
  localTorrentEngine: bool   // librqbit + axum
  stremioInfoHash: enum { LocalEngine, DebridOnly, Hidden }
  stremioUrl: bool           // always true where playback exists
  builtinTorrentSearch: bool // Jackett, Prowlarr, scrapers
}
```

| Profile | `localTorrentEngine` | `stremioInfoHash` | `builtinTorrentSearch` |
|---------|----------------------|-------------------|------------------------|
| `desktop` (win/mac/linux) | yes | LocalEngine | yes |
| `mobile` (android) | yes | LocalEngine | yes |
| `mobile` (ios) | yes* | LocalEngine | yes |
| `constrained` (web, TV) | no | DebridOnly or Hidden | no |

\*iOS keeps engine today; profile allows tightening later.

Expose via `PlatformPlayback.capabilities` (Dart) backed by compile-time flags (`kIsWeb`, future `Platform.isTizen`) and settings override for testing.

### 2. Stremio stream resolver (single path)

Centralize `_playStremioStream` logic into one service used by both details screens:

```text
resolveStremioStream(stream, profile) → PlayableSource | StremioPlaybackError
```

| `stream` shape | `desktop` / `android` | `constrained` |
|----------------|----------------------|---------------|
| `url` | play direct | play direct |
| `infoHash` + debrid on | debrid URL | debrid URL |
| `infoHash` + debrid off | librqbit localhost URL | error: "Requires debrid" or hide stream |
| `externalUrl` | existing handler | existing handler |

Filter stream list in UI when `stremioInfoHash == Hidden` — don't show Torrentio rows on TV/web.

### 3. Direct streaming mode alignment

When **Direct streaming mode** is on, treat profile as `constrained` for torrent UI even on desktop (optional setting), or document that mode as WebStreamr-first only and keep Stremio hash playback on desktop.

Pick one product rule and enforce consistently in `streaming_details_screen.dart`.

### 4. Engine / bootstrap

- Skip `TorrentStreamService().start()` on `constrained` profile (RFC-010 already implies this).
- Hide torrent settings, magnet tab, Jackett/Prowlarr chips when `builtinTorrentSearch == false`.
- Stremio catalog + stream addons remain available (HTTP-only).

### 5. Future TV (out of scope for v1, document here)

- Tizen / webOS Flutter or web shell.
- Same `constrained` profile as NuvioTV: browse metadata, resolve addon `url` streams, debrid for `infoHash` if user configures it.
- No librqbit binary on device.

## Acceptance

- [ ] `PlaybackProfile` defined; `desktop` and `constrained` profiles implemented
- [ ] Single `resolveStremioStream()` used by `details_screen` and `streaming_details_screen`
- [ ] On `constrained`: `infoHash` streams without debrid show clear message, not torrent spinner
- [ ] On `constrained`: torrent engine does not start; torrent UI hidden
- [ ] On `desktop`/`android`: behavior unchanged (url direct, infoHash → librqbit or debrid)
- [ ] RFC-010 web build uses `constrained` profile without duplicating guards
- [ ] Docs: `docs/features/sources/stremio-addons.md` notes platform limits for hash-based addons

## Related

- `apps/forja/lib/features/home/details_screen.dart` — `_playStremioStream`
- `apps/forja/lib/features/home/streaming_details_screen.dart` — `_startStremioExtraction`
- `packages/streaming/lib/src/torrent_stream_service.dart` — engine lifecycle
- `packages/api/lib/api/stremio_service.dart` — addon HTTP
- `crates/torrent/src/lib.rs` — librqbit + axum
- `crates/stremio-core/` — manifest/stream parse
- [RFC-010](../rfc/010-web-client.md) — web capability matrix (torrent hidden)
- [Direct streaming mode](../features/movies-tv/direct-streaming-mode.md)
- [Stremio addons](../features/sources/stremio-addons.md)
- [002](002-torrent-disk-cache-not-cleaned.md) — torrent lifecycle (desktop profile only)
