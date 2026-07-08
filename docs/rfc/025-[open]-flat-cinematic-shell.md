# RFC-025: Flat cinematic shell & Home hero

**Status:** open  
**Version:** v1.0.0  
**Target version:** [1.0.0 Bab Souika](../backlog/1.0.0-[open].md)  
**Scope (slice 1):** **desktop only** — hover-expand rail, flat shell bg, Home hero layout  
**Depends on:** [RFC-023](fixed/023-[fixed]-app-shell-redesign.md) (shell structure shipped), [RFC-016](016-[partial]-lazy-tab-mounting.md) (lazy tabs)  
**Area:** `apps/forja/lib/shell/`, `apps/forja/lib/features/home/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **37 / 39** acceptance (desktop slices 1–1.3) · **2 / 3** deferred |
| **Current slice** | Desktop cinematic polish (1.3) + mobile flat nav |
| **Backlog** | [1.0.0](../backlog/1.0.0-[open].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R25-C01 | `ShellNavRail` → hover-expand overlay rail (icon-only collapsed; labels overlay body) | ✅ |
| 2 | R25-C02 | `ShellScaffold` layout: `Stack` full-bleed body; remove `_ambientGlows`; unified `bgDark` | ✅ |
| 3 | R25-C03 | `shell_tokens.dart`: rail collapsed/expanded widths, hero layout ratios, gradient stops | ✅ |
| 4 | R25-C04 | Home hero: 2/3-right backdrop + left text panel (extract `home_hero.dart` optional) | ✅ |

---

## Acceptance (1.0.0 — desktop slice 1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R25-A01 | Collapsed rail ~icon width; no permanent labels; same `bgDark` as body (no separate rail tint) | ✅ |
| 2 | R25-A02 | Hover rail expands with animated width; labels render **over** body content (z-index), not pushing layout | ✅ |
| 3 | R25-A03 | Shell ambient glows removed (`_ambientGlows` deleted; `shellGlow*` tokens unused) | ✅ |
| 4 | R25-A04 | `ShellBottomNav` unchanged in slice 1 (mobile deferred) | ✅ |
| 5 | R25-A05 | Contracts preserved: `ShellBus`, navbar settings, lazy tabs, `hideGlobalNav`, IPTV/Music hide rules | ✅ |
| 6 | R25-A06 | Backdrop image occupies **right ~2/3** of hero; left ~1/3 is text/metadata on solid dark | ✅ |
| 7 | R25-A07 | Black horizontal gradient overlay: opaque `bgDark` left → transparent into image (readable title/synopsis) | ✅ |
| 8 | R25-A08 | Hero carousel indicators on **right edge** (vertical dots on desktop) — replace bottom horizontal bars | ✅ |
| 9 | R25-A09 | All Home hero `BackdropFilter` / frosted-glass helpers removed; flat solid pills/circles/arrows | ✅ |
| 10 | R25-A10 | No primary-color radial “ambient tint” on hero; no glow box-shadows on Play / indicators | ✅ |
| 11 | R25-A11 | Widget tests: rail collapsed width, hover expand, glow absent; hero layout smoke (desktop width) | ✅ |
| 12 | R25-A12 | `flutter analyze` clean on touched files | ✅ |

---

## Acceptance (1.0.0 — desktop slice 1.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 16 | R25-A16 | Logo + Films/TV/Anime top bar on body; Films underlined (visual only) | ✅ |
| 17 | R25-A17 | Rail: profile top, settings bottom, nav centered; grey icons | ✅ |
| 18 | R25-A18 | Netflix underline active state (no circle fill) | ✅ |
| 19 | R25-A19 | Collapsed rail wider; body left-inset = collapsed width | ✅ |
| 20 | R25-A20 | Expanded rail transparent + body scrim gradient | ✅ |
| 21 | R25-A21 | Right viewport gradient; full-width desktop body (no 1600 cap on Home) | ✅ |
| 22 | R25-A22 | Hero: Watch Now ghost + square info/add buttons (40px) | ✅ |
| 23 | R25-A23 | App-wide button theme + Home continue-watching/stats migrated | 🔄 |
| 24 | R25-A24 | Shell/nav typography Inter | ✅ |
| 25 | R25-A25 | Widget tests updated | ✅ |

---

## Acceptance (1.0.0 — desktop slice 1.2)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 26 | R25-A26 | Fixed-width rail (`navRailWidth` 88px); no hover expand / scrim | ✅ |
| 27 | R25-A27 | Top bar (logo + Films/TV/Anime) **Home tab only** — other tabs use their own headers | ✅ |
| 28 | R25-A28 | Hero: full-bleed `Stack` (backdrop under gradient) — no Row seam at image edge | ✅ |
| 29 | R25-A29 | Remove Home `_AmbientBackdrop` body lights; no shell right-edge vignette | ✅ |
| 30 | R25-A30 | Watch Now = text-only ghost; info / + = bare `ForjaPlainIcon` (no bordered boxes) | ✅ |
| 31 | R25-A31 | Muted grey nav icons; larger rail items + top-bar category spacing | ✅ |
| 32 | R25-A32 | Widget tests: fixed rail width, home-only top bar opt-in, plain icon smoke | ✅ |

---

## Acceptance (1.0.0 — desktop slice 1.3)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 33 | R25-A33 | `HomeTopBar`: Films / TV / Categories on hero; scroll-hide; mood menu via `ShellBus` | ✅ |
| 34 | R25-A34 | Cinematic hero: ~72% viewport height; image under top bar + continue-watching / mood overlap | ✅ |
| 35 | R25-A35 | Fixed hero text slots (title, meta, overview) — stable layout across slides | ✅ |
| 36 | R25-A36 | Infinite hero carousel + clickable vertical step indicators | ✅ |
| 37 | R25-A37 | Logo on nav rail (`navRailWidth` 120); `ShellTopBar` provider strip stub (hidden on Home) | ✅ |
| 38 | R25-A38 | Desktop Search: full-page Netflix layout — no `ShellSearchBar` in shell header | ✅ |
| 39 | R25-A39 | Rail items use `ForjaInteractive` hover/press feedback | ✅ |
| 40 | R25-A40 | Widget tests: `HomeTopBar`, desktop search tab, flat bottom nav | ✅ |

---

## Acceptance (deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 13 | R25-A13 | Mobile bottom nav flat treatment (remove `BackdropFilter` in `shell_bottom_nav.dart`) | ✅ |
| 14 | R25-A14 | App-wide blur/glow purge (Music, cards, player chrome) | ⏭️ |
| 15 | R25-A15 | Light-mode parity audit after flat dark default ships | ⏭️ |

---

## Summary

Replace the current glassmorphism + ambient-glow shell with a **flat, unified dark canvas**. Desktop nav collapses to icons; hover expands labels **over** the body. Home hero moves from full-bleed bottom overlay to a **left text column + right 2/3 backdrop** with a black left→right gradient for readability.

Visual language is separate from [RFC-023](fixed/023-[fixed]-app-shell-redesign.md) (structural shell extraction — shipped). Tab cache behavior stays in [RFC-024](024-[partial]-tab-cache-eviction-stale.md).

## Reference mockups

| Asset | Description |
|-------|-------------|
| [home-flat-shell-mockup.png](assets/025/home-flat-shell-mockup.png) | Target: icon rail, unified bg, left hero text, right 2/3 image, vertical carousel dots |
| [hero-fullbleed-before.png](assets/025/hero-fullbleed-before.png) | Current-style full-bleed hero (before) |
| [hero-gradient-left-text.png](assets/025/hero-gradient-left-text.png) | Left black gradient + text over warm backdrop (gradient detail) |

## Problem

1. **Split visual language** — [`shell_scaffold.dart`](../../apps/forja/lib/shell/shell_scaffold.dart) paints radial ambient glows on top of `bgDark`; [`shell_nav_rail.dart`](../../apps/forja/lib/shell/shell_nav_rail.dart) uses `NavigationRail` with labels always visible beside a fixed-width column.

2. **Glass-heavy Home hero** — [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) `_buildHeroCarousel` (~L1140) is full-bleed with multi-layer gradients, primary radial tint, bottom text overlay, and `BackdropFilter` frosted controls (`_buildFrostedPill`, `_buildFrostedCircle`, `_buildFrostedArrow`).

3. **Menu and body feel separate** — `Row(rail, Expanded(body))` permanently reserves rail width; body never reads as one surface with the nav.

## Goals

- Flat `bgDark` shell — menu and body same color, no blur/glow on shell + Home (slice 1)
- Desktop hover-expand rail: icons only collapsed; labels overlay body on hover
- Home desktop hero: left ~1/3 text, right ~2/3 backdrop, black horizontal gradient
- Preserve shell contracts from RFC-023 (see below)

## Non-goals (slice 1)

- Mobile bottom nav redesign (R25-A13)
- App-wide blur removal outside shell + Home (R25-A14)
- Full Home god-file split ([RFC-019](019-[draft]-god-file-decomposition.md)) — optional small `home_hero.dart` extract only
- GoRouter / deep-link changes
- Player overlay ([RFC-003](003-[partial]-player-overlay.md))

## Design

### Shell layout

Replace `Row(rail, Expanded(body))` in [`shell_scaffold.dart`](../../apps/forja/lib/shell/shell_scaffold.dart) with a `Stack`:

```
Stack
├── Container(effectiveBackground)     // flat bgDark
├── ShellBody (full width)
└── ShellNavRail (Positioned left, overlay)
```

- **Collapsed:** `ShellTokens.navRailCollapsedWidth` (~56–64px) — logo + icons only
- **Expanded (hover):** `ShellTokens.navRailExpandedWidth` (~200–240px) — labels fade/slide in
- **Pointer:** body is always full width; expanded rail does not push layout
- **Delete:** `_ambientGlows` and references to `shellGlowTopRight`, `shellGlowBottomLeft`, `shellGlowCenterLeft`
- **`hideGlobalNav`:** unchanged — rail not built when IPTV deep view or Music desktop sidebar active

### Home hero (desktop only)

In `_buildHeroCarousel` (desktop branch):

| Region | Width | Content |
|--------|-------|---------|
| Left | ~1/3 | Title/logo, meta, synopsis, Play / More Info / My List — on solid `bgDark` |
| Right | ~2/3 | `PageView` backdrop, `BoxFit.cover`, `Alignment.centerRight` |

Gradient: single dominant `LinearGradient` left → right — `bgDark` opaque → transparent into image. Remove bottom-heavy multi-stop stack and primary radial tint overlay.

Controls: replace frosted glass with flat `Material` / `Container` (reuse light-mode styling as baseline).

Indicators: vertical dots on right edge (desktop); keep existing horizontal bars on mobile.

Mobile hero layout unchanged in slice 1.

### Tokens ([`shell_tokens.dart`](../../apps/forja/lib/shared/design/src/shell_tokens.dart))

Add (values tuned during implementation):

```dart
static const double navRailCollapsedWidth = 56;
static const double navRailExpandedWidth = 220;
static const Duration navRailExpandDuration = Duration(milliseconds: 200);
static const double heroImageWidthFraction = 2 / 3;
static const double heroTextWidthFraction = 1 / 3;
static const double heroMinHeightDesktop = 480;
```

Deprecate/remove `shellGlow*` once glows are deleted.

## Slices

### Slice 1 — v1.0.0 desktop *(this RFC)*

R25-C01–C04 · R25-A01–A12

### Slice 2 — mobile + app-wide flat *(deferred)*

R25-A13–A15

## Contracts (must not break)

| Contract | Location |
|----------|----------|
| `ShellBus.requestTab` | `shell_bus.dart` |
| `ShellBus.stremioSearchNotifier` | `shell_bus.dart` |
| `ShellBus.hideGlobalNav` | `shell_bus.dart` |
| `SettingsService.allNavIds` + `navbarChangeNotifier` | `packages/rust` |
| Lazy `_tabCache` + `_mountedTabIds` | `main_screen.dart` |
| `DesktopWindowChrome.wrapShell()` | bootstrap path |
| `AppRouter` push helpers | `app_router.dart` |

## Honesty / debt notes

- **Slice 1 scope:** Removing `BackdropFilter` on shell + Home reduces GPU layers on desktop; Music, player, and card blur remain — track in R25-A14.
- **Settings copy:** “Light Mode disables blur, glows…” in Settings → Appearance becomes partially stale once dark mode is flat by default; update on ship.
- **RFC-019:** Hero work may extract `home_hero.dart` without waiting for full `home_screen.dart` split.

## Related

[RFC-023](fixed/023-[fixed]-app-shell-redesign.md), [RFC-024](024-[partial]-tab-cache-eviction-stale.md), [RFC-016](016-[partial]-lazy-tab-mounting.md), [RFC-019](019-[draft]-god-file-decomposition.md), [1.0.0 backlog](../backlog/1.0.0-[open].md)
