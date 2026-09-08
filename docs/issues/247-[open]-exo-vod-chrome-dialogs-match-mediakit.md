# 247 — Exo VOD chrome / dialogs must match MediaKit

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/` — ExoPlayerScreen vs MobilePlayerScreen

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **1 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I247-T01 | Extract shared VOD chrome overlay + TV transport from MediaKit; Exo + MediaKit call one builder | ✅ |
| 2 | I247-T02 | Exo Source opens `PlayerStreamMenu` (same side panel as MediaKit), not `PlayerServerStreamDialog` | ✅ |
| 3 | I247-T03 | Exo Subtitles use MediaKit popup shape (`PlayerSubtitleMenu` / shared presenter), not 2-col `PlayerSubtitleDialog` | ✅ |
| 4 | I247-T04 | Exo Settings match MediaKit drill-in (auto selection + speed + fit; hide MediaKit-only decode) | ✅ |
| 5 | I247-T05 | Exo TV transport prev/next episode buttons + D-pad edges match MediaKit | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I247-A01 | Android TV Exo chrome layout matches MediaKit (top bar, seek, transport cluster including prev/next ep) | ⬜ |
| 2 | I247-A02 | Exo Source / Subs / Settings menus match MediaKit UX and D-pad overlay trapping | ⬜ |
| 3 | I247-A03 | Exo ↔ MediaKit Player menu switch shows the same chrome controls | ⬜ |
| 4 | I247-A04 | Phone Exo bottom bar matches MediaKit (minus Cast/PiP until issue 032) | ⬜ |
| 5 | I247-A05 | Feature doc `player.md` describes one chrome contract for both engines | ✅ |

---

## Summary

RFC-029 shipped Exo as a parallel `ExoPlayerScreen` that reused chrome **widgets** but forked the overlay tree and menus. MediaKit (`MobilePlayerScreen` / `TvPlayerScreen`) remains the design source of truth.

**Shipped:** shared `PlayerVodTvTransportRow` (MediaKit + Exo); Exo Source → `PlayerStreamMenu`; Exo Subtitles → language-folder `PlayerPopupPanel` (same shape as MediaKit); Exo Settings → auto selection + speed + aspect; prev/next episode on Exo transport; `player.md` one chrome contract.

**Manual QA still open** (A01–A04). Engine-only gaps (ASS, PiP, seek preview, `audioUrl`) stay on [032](032-[draft]-exoplayer-parity-gaps.md).

**Related:** [RFC-029](../rfc/029-[open]-dual-built-in-playback-engines.md) · [032](032-[draft]-exoplayer-parity-gaps.md)
