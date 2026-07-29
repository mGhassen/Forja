# 131 — Android TV Live Matches Exo player: D-pad dead

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · IPTV Exo handoff · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I131-T01 | ATV: release underlay WebView / PlayerView leanback focus before native player chrome claims Play | ✅ |
| 2 | I131-T02 | IPTV bottom transport: explicit FocusNodes + ←/→ edges (Play ↔ Replay ↔ Search/Guide/Source) | ✅ |
| 3 | I131-T03 | Exo PlayerView: clearFocus + non-focusable children after inflate (SurfaceView remount) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I131-A01 | Android TV Live Matches Streamed/PPV → Exo: after open, D-pad lands on Play; ←/→ moves Replay / top **Player**; Select toggles play/pause | ⬜ |
| 2 | I131-A02 | Android TV IPTV live (no Live Matches underlay): same transport ←/→ still works | ⬜ |

---

## Summary

On **Android TV**, after Live Matches hands a Streamed/PPV stream to the native **Exo** IPTV player, the remote looked dead: chrome might show on Play, but D-pad arrows did nothing.

**Root causes:**

1. **Streamed underlay WebView** — handoff uses `Navigator.push` (not replacement) so Chromium can keep fetching CDN segments. That WebView platform view kept leanback focus, so Flutter chrome never saw keys (same class of bug as issue 104 / 122).
2. **Transport ←/→** — IPTV bottom row relied on geometric `focusInDirection` across a full-screen chrome `FocusScope` and a wide `Spacer`; top bar already used explicit edges (issue 110). Bottom did not.

**Root fix:** `PlatformChannel.releaseUnderlayPlatformViewFocus` (block WebView/PlayerView focus, request `FlutterView` focus) on handoff + IPTV boot / Play claim; explicit bottom-row FocusNodes + edges; harden Exo inflate.

## Related

- [104](104-[open]-android-tv-live-matches-embed-dpad.md) — embed WebView D-pad chrome
- [110](110-[open]-android-tv-iptv-player-top-bar-dpad.md) — top-bar explicit edges
- [122](122-[open]-android-tv-iptv-player-lost-dpad.md) — IPTV player D-pad parity
- [130](130-[open]-android-tv-player-dpad-stuck-on-play.md) — focused-node `focusInDirection`
- [Live Matches](../features/live/live-matches.md) · [Player](../features/playback/player.md)
