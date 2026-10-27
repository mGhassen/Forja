# 505 — Android TV player: restore “Press Back again to exit” hint

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android TV · player Back · `PlayerBackExitGate`  
**Reported:** 2026-10-27 (leanback player Back)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV, while playing, Back hides chrome then the next Back leaves — with no on-screen hint that the next Back will exit. User expects the “Press Back again to exit” notification (same idea as desktop Escape arm / pre–RFC-122 player ladder).

## Root cause

RFC-122 `R122-C02` removed the arm / toast step from `PlayerBackExitGate.consumeChromeOrExit` (hide → leave only). Desktop Escape and shell quit still arm; TV player Back did not.

## Root fix

`consumeChromeOrExit` again supports an arm step (`exitArmed` / `armExit`). All TV player surfaces wire it and paint `PlayerEscapeExitHint` (“Press Back again to exit” on TV density). Loading / failed still one-press leave.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I505-T01 | Restore arm step in `consumeChromeOrExit` (`exitArmed` / `armExit`) | ✅ |
| 2 | I505-T02 | Wire Exo / Mobile / IPTV / Live Sports / Trailer / Desktop TV Back + `PlayerEscapeExitHint` | ✅ |
| 3 | I505-T03 | Gate unit/widget tests: hide → arm → leave; twins stay | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I505-A01 | Leanback VOD: Back hides chrome → Back shows “Press Back again to exit” → Back leaves | ⬜ |
| 2 | I505-A02 | Leanback while resolving: one Back still leaves (no arm) | ⬜ |

## Links

- [RFC-122](../../rfc/122-[draft]-android-tv-remote-ux.md) — `R122-C15` restores arm after `R122-C02`
- [Issue 119](../119-[open]-android-tv-double-back-exit.md) — shell quit toast (separate)
- Changelog 1.5.21 — original “Press again to exit” player arm
