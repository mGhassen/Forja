# RFC-028: Adaptive shell profiles

**Status:** draft  
**Depends on:** RFC-023 (app shell), RFC-025 (flat cinematic shell)  
**Area:** `apps/forja/lib/shared/design/`, `apps/forja/lib/shell/adapters/`

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **10 / 10** acceptance (slice 1) · **4 / 4** acceptance (slice 1b TV tabs) · **4 / 4** acceptance (slice 1c TV coordinator) · **3 / 4** acceptance (slice 1d TV desktop visual parity) · **1 / 1** acceptance (slice 1e card motion) · **0 / 4** acceptance (slice 2 mobile) |
| **Current slice** | Slice 1e shared card play motion shipped in code; slice 1d leanback manual smoke still blocks `[fixed]` ([issue 025](../issues/025-[open]-android-tv-leanback-smoke-unverified.md)) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R28-C01 | `ShellProfile` resolver + `ShellPlatformConfig` registry | ✅ |
| 2 | R28-C02 | `ShellMetrics` + `ShellInputPolicy` per profile (mobile, desktop, tv) | ✅ |
| 3 | R28-C03 | `ShellScope` InheritedWidget | ✅ |
| 4 | R28-C04 | Shell adapters — `ShellHost`, `DesktopShell`, `TvShell`, `MobileShell` | ✅ |
| 5 | R28-C05 | Slice 1 migration — desktop hero restored, TV focus isolated | ✅ |
| 6 | R28-C06 | Slice 2 mobile — width-check branches → `ShellScope.metrics` | ⏭️ |

---

## Acceptance (slice 1 — desktop + TV)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R28-A01 | `resolveShellProfile` returns mobile / desktop / tv; feature code does not call `ShellTokens.isTvLayout` | ✅ |
| 2 | R28-A02 | `ShellHost` switches adapters; `MainScreen` has no `shellAsDesktop` coupling | ✅ |
| 3 | R28-A03 | Desktop hero restored (no global `FittedBox`, min title height, compact inset) | ✅ |
| 4 | R28-A04 | TV focus ring, D-pad traversal, hero Play focus — TV policy only | ✅ |
| 5 | R28-A05 | Torrent/sources/player panels use `ShellScope.metrics` not `isTvLayout` | ✅ |
| 6 | R28-A06 | Navbar defaults + legacy migration; no forced Home on startup | ✅ |
| 7 | R28-A07 | `shell_profile_test` + `shell_metrics_test` + `shell_scaffold_test` + `shell_adapters_test` + `shell_profile_behavior_test` | ✅ |
| 8 | R28-A08 | Desktop profile — nav rail hover-only, hero pills full size (no `FittedBox`) | ✅ |
| 9 | R28-A09 | TV profile — focus rings, focusable mood chips, nav rail focus scale | ✅ |
| 10 | R28-A10 | Mobile profile — bottom nav, no app-root traversal wrapper when disabled | ✅ |

---

## Acceptance (slice 1b — Android TV tabs, pre-player)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 15 | R28-A15 | `ShellLayout` helpers + extended `ShellMetrics` (hub CW, card title); `shellFocusableTap` | ✅ |
| 16 | R28-A16 | Search, anime, asian drama, mylist, lists, settings — TV focus + wide layout | ✅ |
| 17 | R28-A17 | IPTV stream cards + live matches cards/sheet — D-pad focus on TV | ✅ |
| 18 | R28-A18 | `shell_tv_tabs_test` + details collection rows policy-gated | ✅ |

---

## Acceptance (slice 1c — TV D-pad coordinator)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 19 | R28-A19 | `ShellTvFocusCoordinator` — nav vertical trap, per-tab memory, row column preserve, hero LEFT → active nav tab | ✅ |
| 20 | R28-A20 | In-scope tabs register rows/zones; `FocusableControl` / `shellFocusableTap` unified Select keys; `TvRemoteDebug` log-only | ✅ |
| 21 | R28-A21 | `shell_tv_coordinator_test` — nav trap, hero nav, row index, activate keys | ✅ |
| 22 | R28-A22 | Nav RIGHT restores tab focus; tab switch in rail does not steal content focus until RIGHT | ✅ |

---

## Acceptance (slice 1d — TV desktop visual parity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 23 | R28-A23 | TV leanback density — smaller `ShellMetrics.tv`, tighter row spacing, larger hero share; fixed nav rail | ✅ |
| 24 | R28-A24 | No `usesTvDensity` / `ShellProfile.tv` visual layout branches in in-scope tabs, details, player sources panels | ✅ |
| 25 | R28-A25 | TV `ShellInputPolicy` unchanged — focus rings, D-pad coordinator, hero Play autofocus | ✅ |
| 26 | R28-A26 | Manual leanback smoke — all tabs + details + player sources at desktop sizing | ⬜ |

---

## Acceptance (slice 1e — shared card play motion)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 27 | R28-A27 | Shared card play controls enlarge and float upward on desktop hover / TV focus, including compact IPTV list rows | ✅ |

---

## Acceptance (slice 2 — mobile, deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 11 | R28-A11 | `HomeMovieCard`, search, scroller use `ShellScope.metrics` not `width > 900` | ⏭️ |
| 12 | R28-A12 | Mobile metrics row verified against production layout | ⏭️ |
| 13 | R28-A13 | `MobileShell` owns bottom-nav spacing tokens | ⏭️ |
| 14 | R28-A14 | No raw width breakpoints in migrated mobile widgets | ⏭️ |

---

## Architecture

Three layers — feature code must not bypass them:

| Layer | API | Used for |
|-------|-----|----------|
| **Boot** | `PlatformChannel`, `PlatformProfile`, `PlatformInfo` | Leanback detection, defaults seeding, no-context routes (player, webview, bootstrap) |
| **Resolver** | `resolveShellProfile()` only | Maps boot flag + layout → `ShellProfile` (`ShellTokens.isTvLayout` allowed here only) |
| **Feature** | `ShellScope.metricsOf` / `inputPolicyOf`, `isTvProfile`, `shellFocusableTap` | All in-tree widgets with `BuildContext` |

CI: `scripts/check_tv_shell_boundary.sh` (melos `rust:check-tv-shell`, Rust workflow).

---

## Summary

Replace scattered `if (isTvLayout)` / `width > 900` checks with a four-layer adaptive shell: shared semantics, profile resolution, platform config registry (metrics + input policy), and shell adapters. Slice 1 fully separates desktop and Android TV; mobile uses passthrough shell with metrics table ready for slice 2.

## Problem

Recent Android TV work changed shared hero/nav layout globally, regressing macOS desktop. Platform logic is inlined in ~15 files with no single switch point.

## Goals

- One resolver, one registry, one shell switch per platform profile
- Desktop and TV fully isolated in slice 1
- Mobile architecture ready; migration deferred to slice 2

## Related

- [RFC-023](fixed/023-[fixed]-app-shell-redesign.md) — original shell extraction
- [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md) — design tokens
