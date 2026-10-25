# RFC-122: Android TV remote: one-level Back, fixed-column rows, unified focus, faster first frame

**Status:** draft  
**Depends on:** RFC-028 (TV shell Back policy, `R28-A29`), RFC-048 (TV focus graph)  
**Area:** `apps/forja/lib/shell/tv/`, `apps/forja/lib/shared/theme/app_theme.dart` (`FocusableControl`), `apps/forja/lib/shared/player/controls/chrome/`, `packages/forja_foundation/lib/tokens/`  
**Issues:** [101](../issues/101-[open]-player-back-lands-on-loading.md) · [119](../issues/119-[open]-android-tv-double-back-exit.md) · [135](../issues/135-[open]-android-tv-spatial-dpad-all-screens.md) · [139](../issues/139-[open]-android-tv-shell-focus-chrome-stutter.md) · [156](../issues/156-[open]-android-tv-hold-scroll-accel.md) · [171](../issues/171-[open]-android-tv-details-focus-after-player.md) · [180](../issues/180-[open]-android-tv-details-back-loses-catalog-focus.md) · [457](../issues/457-[open]-security-hardening-pack-trust-sandbox-proxy-stream-logs.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **14 / 14** components · **10 / 12** acceptance (leanback slice) |
| **Current slice** | T06 green unified focus chrome reverted (C14) — per-zone chrome restored; other C01–C13 work stays; A06 Live Sports and A09 security still owed on-device |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components (tasks T01–T12)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R122-C01 | T01 — Details Back pops in one press (drop the Back-chevron focus step); keep last-card restore on the catalog | ✅ |
| 2 | R122-C02 | T02 — Player Back while resolving / loading exits in one press; while playing: hide chrome, then leave (no third arm / toast step) | ✅ |
| 3 | R122-C03 | T03 — Horizontal rows: focused card held at a fixed column with animated scroll (150–200 ms); next card always visible; column / duration tokens in foundation | ✅ |
| 4 | R122-C04 | T04 — Horizontal hold acceleration: reuse the `ShellTvHoldAccel` curve for ←/→ in rows and grids | ✅ |
| 5 | R122-C05 | T05 — Column memory when moving ↑/↓ between rows and chip strips (nearest-x target, not first item) | ✅ |
| 6 | R122-C06 | T06 — Unified focus chrome tokens (ring + scale + glow) across cards, chips, top menu, nav rail; rail pill behind the focused icon | ✅ |
| 7 | R122-C07 | T07 — Honest loading states: centered spinner + label on details load and player resolve; "Back cancels" hint | ✅ |
| 8 | R122-C08 | T08 — Layout stability: top-menu scrim over scrolled posters; sticky chip strip never clipped; hero carousel pauses while focus is outside the hero; fixed-width hero buttons | ✅ |
| 9 | R122-C09 | T09 — Live Sports: no empty-state copy while catalog loaders are still running | ✅ |
| 10 | R122-C10 | T10 — Faster first frame: measure resolve → first frame on a profile build; start on the first verified source while others continue; tighten per-server timeouts | ✅ |
| 11 | R122-C11 | T11 — Long-press OK on a poster opens a quick menu (Play / Details / My List); MENU key opens the same | ✅ |
| 12 | R122-C12 | T12 — Security review of the branch diff plus the deep-link install and stream URL paths | ✅ |
| 13 | R122-C13 | T13 — Keep the next verified sources as fallbacks after the first probe win (no "Playback failed" dead end when the first source dies); provider hop after fallbacks are exhausted | ✅ |
| 14 | R122-C14 | Revert T06 green unified focus chrome — restore white card ring, label-only nav (no rail pill), pre-T06 chip / top-menu / mood chrome | ✅ |

---

## Acceptance (leanback slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R122-A01 | Leanback: Back from details lands on the last selected catalog card in one press; Back in the player while loading leaves in one press; Back while playing hides chrome, then leaves on the second press (T01, T02) | ✅ |
| 2 | R122-A02 | Leanback: focused card stays at the fixed column with animated scroll and the next card visible; held ←/→ accelerates; ↑/↓ between rows and chip strips keeps the nearest column (T03–T05) | ✅ |
| 3 | R122-A03 | Leanback: cards, chips, top menu, and nav rail show the same ring + scale + glow focus chrome; rail pill sits behind the focused icon (T06) | ✅ |
| 4 | R122-A04 | Leanback: details load and player resolve show a centered spinner with a label and a "Back cancels" hint; no black screen with a lone dot or edge text (T07) | ✅ |
| 5 | R122-A05 | Leanback: top menu stays legible over scrolled posters; sticky chip strip is never clipped; hero carousel does not rotate while focus is outside the hero; hero buttons keep their width on focus (T08) | ✅ |
| 6 | R122-A06 | Leanback: Live Sports shows no "No matches" copy while any schedule loader is still running (T09) | ⬜ |
| 7 | R122-A07 | Leanback: player opens on the first verified source while remaining servers keep checking; no multi-second "0 / N checked" wait before the first frame (T10) | ✅ |
| 8 | R122-A08 | Leanback: long-press OK on a poster and the MENU key open the same quick menu (Play / Details / My List); Back closes it (T11) | ✅ |
| 9 | R122-A09 | Security review of the branch diff, deep-link install path, and stream URL path recorded in this RFC with findings fixed or filed as issues (T12) | ⬜ |
| 10 | R122-A10 | Unit / widget tests for each coordinator change (details Back, player Back gate, row column hold, horizontal hold accel, column memory) | ✅ |
| 11 | R122-A11 | Profile-build timing before / after (resolve → first frame) recorded in this RFC | ✅ |
| 12 | R122-A12 | Leanback focus chrome matches pre-T06: white ring on posters, no green plate behind nav icons, chips / top menu / mood circles without the shared green ring + glow (C14) | ✅ |

---

## Summary

Android TV remote navigation and performance pass. Verified on the Android TV emulator on 2026-10-21 (screenshots) and in code. One RFC; the seven linked issues stay open and are cross-referenced here rather than cloned.

## Problem

| Area | Today (verified) | Target |
|------|------------------|--------|
| **Details Back** | First Back only focuses the top-left chevron (`_tryFocusDetailBack`, `shell_tv_coordinator.dart:308`); second Back leaves. [navigation.md](../features/getting-started/navigation.md) documents Back as player → detail → tab page → nav rail, so the chevron step is an undocumented extra level | One Back pops details; focus restores to the last catalog card |
| **Player Back while loading** | Back #1 hides chrome, Back #2 shows "Press again to exit" (`player_escape_exit_hint.dart` / `player_back_exit_gate.dart`), Back #3 leaves. Documented behavior is "hides chrome, then leaves" | While resolving / loading: one Back leaves. While playing: hide chrome, then leave |
| **Horizontal rows** | `Scrollable.ensureVisible` with `Duration.zero` plus `keepVisibleAtStart` / `keepVisibleAtEnd` edge nudge (`app_theme.dart:498-514`). The focused card ends up clipped at the right edge; the next card is never visible. No fixed focus column, no animation | Focused card held at a fixed column; 150–200 ms animated scroll; next card always visible; tokens in foundation |
| **Hold acceleration** | ↑/↓ only (`shell_tv_hold_accel.dart:16-17`); ←/→ step once per OS key repeat | Same curve for ←/→ in rows and grids |
| **Column memory** | ↓ from card 6 of a row lands on the first chip of the mood strip | Nearest-x target when moving ↑/↓ between rows and chip strips |
| **Focus chrome** | Differs per zone: white ring + 1.08 scale on cards, underline on the top menu, colored text on mood chips, label-only on the nav rail. Painter is host-side (`FocusableControl` in `app_theme.dart`), not foundation | One token set (ring + scale + glow) across cards, chips, top menu, rail; rail pill behind the focused icon |
| **Loading states** | Details while loading = black screen with a tiny centered dot; player while resolving = black screen with small "Checking sources" text at the right, no spinner, no hint that Back cancels | Centered spinner + label; "Back cancels" hint |
| **Layout stability** | Top menu (Search / Films / TV Shows / Categories) painted over scrolled posters without a scrim; sticky mood-chip strip clipped at the top edge after scrolling; hero carousel keeps auto-rotating while the user navigates rows; "My List" hero button changes width on focus | Scrim; strip never clipped; carousel pauses while focus is outside the hero; fixed-width hero buttons |
| **Live Sports empty state** | "No matches in this schedule" shown while the catalog loader still reports 2/9 | No empty-state copy while loaders run |
| **Stream start** | "Checking servers… 0 / 73 checked · 0 up" sat for 12 s before the player opened on the first good source; player then stayed black with "Checking sources" | Start on the first verified source while others continue; tighter per-server timeouts; timing measured on a profile build |
| **Remote keys** | No long-press OK on posters (OK-hold exists only on rail items); no MENU / INFO handling outside the player | Long-press OK and MENU open a poster quick menu (Play / Details / My List) |

## Goals

- Back travels exactly one shell level per press, matching the documented policy in RFC-028 `R28-A29` and [navigation.md](../features/getting-started/navigation.md).
- D-pad browsing feels like a leanback launcher: fixed focus column, animated rows, hold acceleration in every axis, column memory.
- One focus language on every TV surface, painted from foundation tokens.
- Loading and empty states tell the truth about what is running and how to cancel.
- Stream start opens the player on the first verified source; the delay is measured, not guessed.

## Non-goals

- Phone and desktop input policy (unchanged).
- Player overlay menus beyond the Back gate (RFC-048 `TvOverlayScope` covers them).
- New Live Sports catalog or stream sources.

## Timing record (Android TV emulator, API 34 arm64, profile build, 73 providers)

| Run | Play → race start | → first probe ok | → player route | → first frame |
|-----|------------------:|-----------------:|---------------:|--------------:|
| Baseline (817c2181e), cold | 10.7 s | 11.5 s | 11.6 s | 20.2 s |
| After T10 (secure-store gate, script memo, parallel subtitles, cache warm), cold | 0.4 s | 2.3 s | 2.3 s | 3.2 s |
| After T10, warm second title | 0.0 s | 5.2 s (provider latency) | 5.2 s | 8.0 s, then source 404 with no fallback (T13) |

Marks come from `[play-trace]` lines (debug/profile builds only).

## Related

- [RFC-028](028-[draft]-adaptive-shell-profiles.md) — TV shell Back policy (`R28-A29`), `ShellTvFocusCoordinator`
- [RFC-048](fixed/048-[fixed]-tv-focus-graph.md) — TV focus graph + screen recipes (`TvKitRow`, `TvChipStrip`, `TvGrid`)
- [Issue 101](../issues/101-[open]-player-back-lands-on-loading.md) — Player Back lands on stream loading
- [Issue 119](../issues/119-[open]-android-tv-double-back-exit.md) — Android TV double Back / Exit to quit
- [Issue 135](../issues/135-[open]-android-tv-spatial-dpad-all-screens.md) — ATV spatial 2D D-pad (all screens)
- [Issue 139](../issues/139-[open]-android-tv-shell-focus-chrome-stutter.md) — ATV shell / catalog focus chrome stutter
- [Issue 156](../issues/156-[open]-android-tv-hold-scroll-accel.md) — ATV hold ↑/↓ scroll acceleration
- [Issue 171](../issues/171-[open]-android-tv-details-focus-after-player.md) — ATV details empty focus after player
- [Issue 180](../issues/180-[open]-android-tv-details-back-loses-catalog-focus.md) — ATV details Back lands on Home top menu
- [Issue 457](../issues/457-[open]-security-hardening-pack-trust-sandbox-proxy-stream-logs.md) — Security hardening from the T12 review: pack install trust, sandbox limits, proxy token, stream URL allowlist, log redaction
- [Issue 484](../issues/484-[open]-android-tv-details-episode-ok-hold-mark-watched.md) — details episode OK-hold marks watched (same hold / MENU contract as catalog posters)
- [Navigation guide](../features/getting-started/navigation.md) — documented TV Back policy
