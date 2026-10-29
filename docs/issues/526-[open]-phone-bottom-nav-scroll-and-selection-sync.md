# 526 — Phone bottom nav scroll + selection sync

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** shell / phone navigation  
**Reported:** 2026-10-29 (phone emulator after pack install)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. After opening the app and installing plugins, Settings Account can stay on screen while the bottom bar highlights Anime (or another hub).
2. Phone bottom bar caps at five slots + **More**; user wants it to scroll like desktop/TV rail when there are many tabs.
3. The bar must highlight the tab that matches the visible screen.

## Root cause (hypothesis until verified in code)

1. **Selection desync** — `MainScreen._loadNavbarConfig` remaps `_selectedIndex` via `selectDefaultTabOnNextNavLoad` / promote-from-Settings without `popShellOverlayUntilRoot`. Phone Settings category pages (Account = `profile`) stay as shell overlays while the index jumps to the starred hub.
2. **More vs scroll** — `ShellBottomNav` uses `ShellTokens.bottomNavMaxSlots` + More sheet (RFC-123 C22). Desktop/TV rail already scrolls when hubs overflow.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I526-T01 | Phone bottom bar: horizontal scroll of all tabs (drop More sheet); scroll selected into view | ✅ |
| 2 | I526-T02 | Navbar reload: do not yank selection while intentional Settings / overlay open; pop overlays when default-tab remaps | ✅ |
| 3 | I526-T03 | Tests + feature/RFC-123 copy for scrollable phone bar | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I526-A01 | Phone: many hub tabs → bar scrolls; selected tab visible and underlined | ⬜ |
| 2 | I526-A02 | Pack install / Account settings → bottom bar keeps Settings selected while that screen is up | ⬜ |

## Links

- [253](253-[open]-starred-home-opens-on-settings.md) — related default-tab arm races
- [RFC-123](../rfc/123-[open]-android-mobile-flavor.md) — R123-C22 / A25 (was 5 + More)
- [navigation](../features/getting-started/navigation.md)
