# RFC-107: IPTV multi-engine (AVPlayer Mac · VLC Windows · Exo Android)

**Status:** open  
**Depends on:** [RFC-029](029-[open]-dual-built-in-playback-engines.md)  
**Area:** `apps/forja/lib/features/iptv/`, `apps/forja/macos/`, `apps/forja/windows/`, `packages/rust/lib/src/built_in_player_engine.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** components · **19 / 20** acceptance (1 manual QA) · **5 / 5** catalog VOD slice |
| **Current slice** | Catalog VOD AVPlayer/VLC + seek/progress — manual Mac/Win XUMO QA still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R107-C01 | `BuiltInPlayerEngine.avPlayer` + `.vlc` + platform-gated UI options | ✅ |
| 2 | R107-C02 | macOS AVPlayer MethodChannel + PlatformView for IPTV HLS | ✅ |
| 3 | R107-C03 | Windows libVLC bridge (system install) + Flutter Texture | ✅ |
| 4 | R107-C04 | IPTV player backend branches (AVPlayer / VLC / Exo / MediaKit) | ✅ |
| 5 | R107-C05 | HLS auto-route + one-hop engine failover | ✅ |
| 6 | R107-C06 | Feature docs + changelog | ✅ |
| 7 | R107-C07 | In-player engine fit: grey + reason (no hide) | ✅ |
| 8 | R107-C08 | In-player Player menu omits unsuitable engines (no grey/reason) | ✅ |
| 9 | R107-C09 | Native seek + `progress` events on AVPlayer / VLC bridges | ✅ |
| 10 | R107-C10 | Catalog VOD `DesktopNativePlayerScreen` (PlayerScreen route) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R107-A01 | Settings / in-player menu: Mac shows AVPlayer · MediaKit · VLC (when available) | ✅ |
| 2 | R107-A02 | Settings / in-player menu: Windows shows VLC · MediaKit | ✅ |
| 3 | R107-A03 | Android IPTV HLS defaults to Exo; MediaKit remains selectable | ✅ |
| 4 | R107-A04 | macOS `.m3u8` opens AVPlayer (no continuity proxy; native ABR) | ✅ |
| 5 | R107-A05 | Windows `.m3u8` opens VLC when available; else MediaKit | ✅ |
| 6 | R107-A06 | Progressive MPEG-TS / continuity-proxy sources stay on MediaKit | ✅ |
| 7 | R107-A07 | Hard open / no first frame → one failover hop then stop | ✅ |
| 8 | R107-A08 | MediaKit never removed from Player menu | ✅ |
| 9 | R107-A09 | Host unit tests for engine storage keys + platform UI lists | ✅ |
| 10 | R107-A10 | Feature docs list engines per OS | ✅ |
| 11 | R107-A11 | Changelog Add bullets for AVPlayer (Mac) / VLC (Windows) | ✅ |
| 12 | R107-A12 | Manual QA: Mac AVPlayer + Win VLC XUMO/CBS; Xtream TS MediaKit | ⬜ |
| 13 | R107-A13 | Player menu greys AVPlayer/VLC on catalog VOD + MPEG-TS IPTV with reason | ✅ |
| 14 | R107-A14 | Hot-swap / select blocked for unsuitable engines (toast); MediaKit stays | ✅ |
| 15 | R107-A15 | Player menu omits unsuitable engines (no grey subtitle); Settings still lists all | ✅ |

---

## Acceptance (catalog VOD slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R107-A16 | AVPlayer / VLC bridges expose `seek` + `progress` (position/duration) | ✅ |
| 2 | R107-A17 | IPTV VOD scrubber works on AVPlayer / VLC (native seek + progress) | ✅ |
| 3 | R107-A18 | Catalog desktop routes AVPlayer / VLC to `DesktopNativePlayerScreen` | ✅ |
| 4 | R107-A19 | Catalog Player menu allows AVPlayer / VLC except torrent / dual-audio / DRM | ✅ |
| 5 | R107-A20 | Host fit tests cover catalog allow + torrent/dual-audio unfit | ✅ |

---

## Summary

IPTV live HLS needs native stack engines: **AVPlayer on macOS** (majority users), **libVLC on Windows** (system VLC install), **Exo on Android**. MediaKit + continuity proxy remains the progressive MPEG-TS path and the universal fallback. User can always pick MediaKit; engines are additive ([no-hide-as-fix](../../.cursor/rules/no-hide-as-fix.mdc)).

**Catalog VOD slice:** desktop movies/series can use the same AVPlayer (Mac) / VLC (Mac/Win) engines via a thin native player screen. Seek/progress land on the bridges (also fixes IPTV Movies/Series scrubber). Torrent localhost, separate audio URL, and DRM still require MediaKit / Exo. R107-A13 remains the historical IPTV-era catalog grey row; R107-A19 supersedes that for catalog.

### Related

- [RFC-029](029-[open]-dual-built-in-playback-engines.md) — Exo + MediaKit
- [RFC-103](103-[planned]-shahid-desktop-fairplay.md) — FairPlay may reuse AVPlayer later
- [iptv-m3u.md](../features/live/iptv-m3u.md) · [iptv-xtream.md](../features/live/iptv-xtream.md)
