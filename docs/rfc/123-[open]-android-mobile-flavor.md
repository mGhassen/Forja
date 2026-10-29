# RFC-123: Android phone app — separate `tv` and `mobile` flavors

**Status:** open  
**Depends on:** RFC-028 (adaptive shell profiles; slice 2 mobile is owned here)  
**Area:** `apps/forja/android/` (flavors, manifests, updater), `apps/forja/lib/shared/platform/`, `packages/forja_foundation/lib/tokens/forja_shell_tokens.dart`, release scripts + CI, `apps/web` download page, `forja-packs` grids  
**Issues:** [518](../issues/518-[open]-phone-landscape-detected-as-tv.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** components (6 🔄) · **0 / 7** acceptance (slice 1 flavors) · **0 / 6** components (6 🔄) · **6 / 6** acceptance on phone emulator (slice 6 phone UX) · **0 / 1** components (1 🔄) · **1 / 1** acceptance (slice 3 auto PiP) · **0 / 6** components (6 🔄) · **11 / 13** acceptance (slice 7 phone UX pass, 11 on phone emulator) · **0 / 8** components ⏭️ · **0 / 10** acceptance ⏭️ (slices 2–5 rest) |
| **Current slice** | Slice 7 phone UX pass built and emulator-checked; double-tap feedback, long-press sheet, status-bar restore on a real phone, and device acceptance not run |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components (slice 1 — flavors)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-C01 | Two Android product flavors `tv` and `mobile`; same `applicationId` `com.forjahq.app` and same signing key (in-place upgrade, data kept) | 🔄 |
| 2 | R123-C02 | Per-flavor manifests — `tv`: leanback launcher + banner; `mobile`: touchscreen required, resizeable, no leanback launcher | 🔄 |
| 3 | R123-C03 | Build-time form factor passed to Dart at boot; `mobile` never takes the physical-size TV fallback; touch tablets resolve to the `mobile` profile ([518](../issues/518-[open]-phone-landscape-detected-as-tv.md)) | 🔄 |
| 4 | R123-C04 | Updater key `android_mobile`; `tv` flavor running on a non-TV device pulls `android_mobile` (one migration hop) | 🔄 |
| 5 | R123-C05 | Release assets `Forja-<v>-android-{tv,mobile}-<abi>.apk` from scripts + CI | 🔄 |
| 6 | R123-C06 | Web download page lists separate phone and TV entries | 🔄 |

---

## Acceptance (slice 1 — flavors)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R123-A01 | `mobile` APK installs over an installed `tv` APK on a phone; library, settings, and accounts kept | ⬜ |
| 2 | R123-A02 | `mobile` on a phone: cold start in landscape and rotation both stay on the `mobile` profile ([518](../issues/518-[open]-phone-landscape-detected-as-tv.md)) | ⬜ |
| 3 | R123-A03 | `mobile` on a touch tablet in landscape: `mobile` profile; text fields type on focus | ⬜ |
| 4 | R123-A04 | `tv` on `forja_tv`: leanback launcher entry with banner; TV profile and D-pad unchanged | ⬜ |
| 5 | R123-A05 | `mobile` shows in the phone launcher and not in the leanback launcher | ⬜ |
| 6 | R123-A06 | `tv` APK on a phone: updater offers the `android_mobile` build; after the update the phone runs `mobile` with data kept. The hop happens at the first release newer than the installed version that includes a mobile APK | ⬜ |
| 7 | R123-A07 | Release produces both APK sets per ABI; web download page offers phone and TV downloads | ⬜ |

---

## Components (slice 2 — mobile shell, RFC-028 slice 2)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R123-C07 | Build RFC-028 slice 2 (`R28-C06`, `R28-A11`–`R28-A14`): width literals → `ShellScope.metrics`; `MobileShell` bottom nav + safe-area tokens. Rows stay in RFC-028 | ⏭️ |

---

## Acceptance (slice 2 — mobile shell)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 8 | R123-A08 | RFC-028 `R28-A11`–`R28-A14` all ✅ (tracked in [RFC-028](028-[draft]-adaptive-shell-profiles.md) `R28-A32`) | ⏭️ |
| 9 | R123-A09 | Phone with gesture nav and a display cutout: bottom nav and content clear system insets in portrait and landscape | ⏭️ |

---

## Components (slice 3 — phone player)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 8 | R123-C08 | Android PiP auto-enter on Home while playing | 🔄 |
| 9 | R123-C09 | IPTV and Live Sports player touch gesture audit; Live Sports stays native play URL only | ⏭️ |
| 10 | R123-C10 | Restore the shell orientation when the player exits | ⏭️ |

---

## Acceptance (slice 3 — phone player)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R123-A10 | Home during playback enters PiP; reopening Forja returns to the full player | ✅ |
| 11 | R123-A11 | IPTV and Live Sports player controls work by touch on a phone; Live Sports plays native URLs only | ⏭️ |
| 12 | R123-A12 | Leaving the player returns to the orientation the shell had before playback | ⏭️ |

---

## Components (slice 4 — tabs and panels)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 11 | R123-C11 | Sources and details panels open as bottom sheets on the compact profile | ⏭️ |
| 12 | R123-C12 | Search field types on focus on the `mobile` profile | ⏭️ |
| 13 | R123-C13 | Pack grids follow the size class (`forja-packs` repo) | ⏭️ |

---

## Acceptance (slice 4 — tabs and panels)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 13 | R123-A13 | Phone portrait: sources and details open as bottom sheets | ⏭️ |
| 14 | R123-A14 | Phone: first tap on Search opens the keyboard | ⏭️ |
| 15 | R123-A15 | Pack grid column counts change between 412 and 915 logical widths | ⏭️ |

---

## Components (slice 5 — parity proof)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 14 | R123-C14 | `profile_parity_test` pumps each in-scope tab under `mobile` and `tv` | ⏭️ |
| 15 | R123-C15 | Goldens at 412×915 and 915×412 | ⏭️ |

---

## Acceptance (slice 5 — parity proof)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 16 | R123-A16 | `profile_parity_test` green for every in-scope tab under both profiles | ⏭️ |
| 17 | R123-A17 | Goldens at 412×915 and 915×412 committed and green | ⏭️ |
| 18 | R123-A18 | Emulator smoke on a phone AVD (`mobile`) and `forja_tv` (`tv`) | ⏭️ |

---

## Components (slice 6 — phone UX pass)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 16 | R123-C16 | Phone keeps the bottom tab bar in landscape (all tabs, with labels); tablet in landscape gets the side rail; no floating menu button over content | 🔄 |
| 17 | R123-C17 | Phone hubs show the hub top bar (Search, Films / Series menus, Categories) | 🔄 |
| 18 | R123-C18 | Portrait hero: image edge to edge, shorter so the first row peeks | 🔄 |
| 19 | R123-C19 | Phone details: full-height tint keeps title and summary readable on bright art | 🔄 |
| 20 | R123-C20 | Hub action strips (Live Sports, IPTV) scroll sideways on narrow screens instead of clipping actions | 🔄 |
| 21 | R123-C21 | Auto picture-in-picture setting on phones: on by default, toggle in Settings → Addons → Playback, value stays on the phone (not synced from desktop) | 🔄 |

---

## Acceptance (slice 6 — phone UX pass)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 19 | R123-A19 | Phone AVD (1080×2400), portrait and landscape: all 8 tabs reachable from the bottom tab bar | ✅ |
| 20 | R123-A20 | Phone AVD: hub top bar Search opens search; search field types on focus | ✅ |
| 21 | R123-A21 | Phone AVD: details and playback open and play | ✅ |
| 22 | R123-A22 | Phone AVD: leaving the app while a video plays enters picture-in-picture and playback continues | ✅ |
| 23 | R123-A23 | Phone AVD: leaving the player returns the shell to portrait | ✅ |
| 24 | R123-A24 | `forja_tv`: TV shell, hubs, and player unchanged by the phone UX pass | ✅ |

---

## Components (slice 7 — phone UX pass)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 22 | R123-C22 | Bottom tab bar: all tabs in a horizontal scroll row (selected stays in view); compact bar in landscape (icon beside label); clears the gesture bar | ✅ |
| 23 | R123-C23 | Edge-to-edge with the status bar visible; hub top bar readable over bright art and solid once scrolled; toasts and update banner sit above the tab bar | 🔄 |
| 24 | R123-C24 | Phone details: full-width labeled Play / Resume SxEy, labeled secondary actions (Sources, Trailer, My List, SUB/DUB), vertical episode list, larger back button, solid title bar on scroll, landscape keeps overview and genres; title and logo never overlap while loading (all platforms) | 🔄 |
| 25 | R123-C25 | Phone player: control bar with Episodes, Audio & subtitles, source, More (Quality, Settings, Volume, Previous episode, Lock); double-tap seek with +10 s feedback; menus open below the top bar; exit restores portrait and the status bar | 🔄 |
| 26 | R123-C26 | Catalog: about 3 posters across in portrait, 5–6 in landscape; home hero Play button, crossfade, horizontal dots, title and buttons above the tab bar in landscape; long-press poster sheet (Play, Details, My List); clearer selected mood; Continue Watching right after the hero (all platforms) | 🔄 |
| 27 | R123-C27 | Panels: Sources and Categories as bottom sheets; Live Sports loading bar under the action bar; Settings single column in landscape; My List status tabs scroll with full labels; landscape search with the keyboard open | 🔄 |

---

## Acceptance (slice 7 — phone UX pass)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 25 | R123-A25 | Phone AVD, portrait and landscape: bottom bar scrolls when tabs overflow; selected tab stays visible (no More sheet) | ⬜ |
| 26 | R123-A26 | Phone AVD: hub top bar turns solid on scroll | ✅ |
| 27 | R123-A27 | Phone AVD: details show stacked labeled actions and a vertical episode list | ✅ |
| 28 | R123-A28 | Phone AVD: player shows the phone control bar; More menu opens with its items | ✅ |
| 29 | R123-A29 | Phone AVD: Sources and Categories open as bottom sheets | ✅ |
| 30 | R123-A30 | Phone AVD: Settings is a single pane in landscape | ✅ |
| 31 | R123-A31 | Phone AVD: My List status tabs show full labels | ✅ |
| 32 | R123-A32 | Phone AVD: landscape search with the keyboard open does not overflow | ✅ |
| 33 | R123-A33 | `forja_tv`: TV home and details unchanged by the slice 7 pass | ✅ |
| 34 | R123-A34 | Double-tap seek shows the +10 s feedback bubble | ✅ |
| 35 | R123-A35 | Long-press on a poster opens the Play / Details / My List sheet | ✅ |
| 36 | R123-A36 | Real phone: status bar returns after leaving the player | ⬜ |
| 37 | R123-A37 | Device acceptance of slice 7 on a real phone | ⬜ |
| 38 | R123-A38 | Phone AVD, many hub tabs: bottom bar scrolls; selected tab visible and underlined (no More sheet) | ⬜ |

---

## Summary

Users install the Android TV APK on phones. That build guesses TV from screen size, so phones in landscape get the TV shell ([518](../issues/518-[open]-phone-landscape-detected-as-tv.md)). This RFC ships a dedicated phone build. Both builds share one app id and signing key, so a phone moves from the TV build to the phone build in place.

## Problem

- One APK serves phones, tablets, and TVs.
- Form factor is guessed at runtime from physical and logical size.
- A landscape phone or tablet passes the TV size test and gets D-pad UX.
- Phone layout work (RFC-028 slice 2) has no build to land in.

## Goals

- The build declares its form factor. Runtime guessing stays on the `tv` build only.
- Existing phone installs move to the `mobile` build through the updater with data kept.
- Phone shell, player, and panels reach parity with the TV and desktop profiles, proven by tests and goldens.

## Contracts

- `applicationId` and signing key are identical across flavors. Never fork them.
- `mobile` flavor: the shell profile is `mobile` on every screen size and orientation.
- `tv` flavor: leanback detection plus the physical-size fallback, as today.
- Updater: the `tv` build on a device without leanback pulls `android_mobile` once.
- Live Sports plays a native URL or nothing on both flavors.

## Related

- [RFC-028](028-[draft]-adaptive-shell-profiles.md) — shell profiles; slice 2 mobile built here (`R28-A32`)
- [RFC-122](122-[draft]-android-tv-remote-ux.md) — Android TV remote UX (`tv` flavor behavior)
- [Issue 518](../issues/518-[open]-phone-landscape-detected-as-tv.md) — phone landscape detected as TV
