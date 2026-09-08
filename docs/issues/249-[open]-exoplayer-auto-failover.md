# 249 — ExoPlayer Auto failover on stream failure

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/screens/exo_player_*.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I249-T01 | Queue native Exo errors during open/failover (stop swallowing) | ✅ |
| 2 | I249-T02 | Sibling hop + Auto provider / `onReloadStreams` recovery on Exo | ✅ |
| 3 | I249-T03 | Wire `pinSource` / `streamsPrevalidated` / `onReloadStreams` into Exo | ✅ |
| 4 | I249-T04 | Mid-watch hop resumes near prior position (seek override) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I249-A01 | Auto On: dead first Exo CDN (SSL / 404) hops next sibling then next provider until READY — no hard fail on source 1/1 when other servers exist | ⬜ |
| 2 | I249-A02 | Auto Off / pinned: dead stream stops for Retry / Sources (no silent provider hop) | ⬜ |

---

## Summary

Exo opened with one URL (`Trying source 1/1`), hit TLS/CDN death, and either hard-failed or ignored the native error while `_opening`. MediaKit already hops siblings then Auto providers (issues [037](037-[open]-webstreaming-all-providers-open-validate.md), [175](175-[open]-mid-watch-auto-failover.md)). Exo now matches: queue open-time errors, try remaining mirrors, then reload / next provider when Auto is on.

**Root fix:** `exo_player_failover.dart` + open/error wiring in `exo_player_screen.dart`.

---

## Related

- [037](037-[open]-webstreaming-all-providers-open-validate.md) — Auto vs pin
- [175](175-[open]-mid-watch-auto-failover.md) — mid-watch MediaKit hop
- [032](032-[draft]-exoplayer-parity-gaps.md) — Exo parity tracker
- [Player](../features/playback/player.md)
