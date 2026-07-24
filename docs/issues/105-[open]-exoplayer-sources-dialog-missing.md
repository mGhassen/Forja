# 105 — ExoPlayer missing Sources button / server-stream dialog

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/player` · ExoPlayer · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I105-T01 | Show Sources chrome button when providers or session streams exist (not only when 2+ URLs) | ✅ |
| 2 | I105-T02 | 2-column Sources dialog — left servers, right streams; check server then list streams | ✅ |
| 3 | I105-T03 | Pick stream → `ExoPlayerBridge.open` (resolve via `PlayerSourceResolve`) + TV focus restore | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I105-A01 | Android TV Exo: anime/webstream with providers → Sources button visible with one playing stream | ⬜ |
| 2 | I105-A02 | Open dialog → left servers → select → right fills with checked streams → pick plays in Exo | ⬜ |
| 3 | I105-A03 | Back closes dialog and returns focus to chrome; catalog/magnet session hides this button | ⬜ |

---

## Summary

Android TV defaults to ExoPlayer. That screen never got a **Sources** control: the button only appeared when `_sources.length > 1`, and the menu was a flat URL list — not servers + streams. MediaKit already had the accordion Source panel.

**Fix:** Exo shows a **Sources** button whenever providers (or current streams) exist, and opens a **2-column** dialog (servers | streams). Selecting a server resolves/checks it; picking a stream opens it in Exo. Catalog torrent/Stremio/Nuvio sessions still hide this button (link **Sources** panel remains a follow-up).

## Related

- [032](032-[draft]-exoplayer-parity-gaps.md) — broader Exo parity
- [Player](../features/playback/player.md)
