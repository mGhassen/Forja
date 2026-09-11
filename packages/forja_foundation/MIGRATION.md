# Migrating to `forja_foundation` (RFC-106)

This file is the **only** checklist. If a row has no New path, that is a
package or host gap — close it in the same slice. Do not skip. Do not treat
`package:forja/shared/foundation/primitives/**` as a destination.

## Rules

1. Import the **file**, never `package:forja_foundation/forja_foundation.dart`.
2. Never `hide Switch, Chip, …` against Material.
3. Never add `import` lines to `part of` files — put them on the library parent.
4. Never import `package:forja/shared/foundation/**`. That tree is **deleted**. Do not recreate it.
5. If the package is missing an API: **extend the package** or **move** to `shared/shell/`, `shared/engine/`, or `shared/host/kit|packs|update|account|watch`. Do **not** put pack surfaces in `shared/host/lists|live_sports|sources`. Do not keep the old foundation import.

`forja_foundation.dart` is a gallery/test barrel.

Pack JSON wire: [PACK_AUTHORS.md](PACK_AUTHORS.md). Do not edit forja-packs unless an alias is dropped.

---

## Destination buckets

Every old symbol has **exactly one** New import.

| Bucket | Import prefix | What |
|--------|---------------|------|
| Package DS | `package:forja_foundation/<file>.dart` | tokens, Button, Switch, Chip, kit types, protocol, NetworkImage, props-only composers |
| Host shell | `package:forja/shared/shell/<file>.dart` | ShellScope, TV, desktop chrome, toast, ForjaInteractive |
| Engine | `package:forja/shared/engine/**` | rust-adjacent live models/schedule state, list-follow, torrent parse |
| Player | `package:forja/shared/player/**` | torrent source panels (player UI) |
| Host services | `package:forja/shared/host/kit/**` · `packs/**` · `update/**` · `account/**` · `watch/**` | generic catalog runtime + pack install + app update. **Never** `host/lists`, `host/live_sports`, `host/sources` |

---

## Tokens

| Old symbol | Old path | New import |
|------------|----------|------------|
| `ForjaShellColors` | `foundation/primitives/tokens/forja_shell_colors.dart` | `package:forja_foundation/tokens/forja_shell_colors.dart` |
| `ShellTokens` | `…/tokens/forja_shell_tokens.dart` | `package:forja_foundation/tokens/forja_shell_tokens.dart` |
| `DetailsTokens` | `…/tokens/forja_details_tokens.dart` | `package:forja_foundation/tokens/forja_details_tokens.dart` |
| `SettingsTokens` | `…/tokens/forja_settings_tokens.dart` | `package:forja_foundation/tokens/forja_settings_tokens.dart` |
| `DesignTokens` | `…/tokens/forja_theme.dart` | `package:forja_foundation/tokens/forja_theme.dart` |
| `ForjaThemeExtension` / `forjaThemeData()` | host theme glue | `package:forja_foundation/theme/forja_theme_extension.dart` — host `AppTheme` sets `extensions: [ForjaThemeExtension.dark()]` |
| `ShellTokens.usesCompactNavDrawer` | width + TV gate | package tokens + host `ShellScope` wraps `CompactNavDrawerPolicy` |

---

## Buttons — constructor recipes

Import: `package:forja_foundation/components/button.dart`.

Package `Button` extras required before rewrite: `color`, `iconSize`, `compact`, optional `height`.

| Old | New |
|-----|-----|
| `ForjaButton(variant: ForjaButtonVariant.primary, …)` / `ForjaButton.primary(…)` | `Button(variant: ButtonVariant.primary, label:, onPressed:, icon:, loading: busy, expand:, autofocus:, focusNode:)` |
| `ForjaButton(variant: ForjaButtonVariant.neutral, …)` / `ForjaButton(…)` | `Button(variant: ButtonVariant.secondary, …)` — `neutral` → `secondary` |
| `ForjaButton(variant: ForjaButtonVariant.destructive, …)` / `ForjaButton.destructive(…)` | `Button(variant: ButtonVariant.destructive, …)` |
| `busy: true` | `loading: true` |
| `ForjaGhostButton(label:, onTap:, icon:, autoFocus:, focusNode:)` | `Button(variant: ButtonVariant.ghost, label:, onPressed: onTap, icon:, autofocus: autoFocus, focusNode:)` |
| `ForjaPlainIcon(icon:, onTap:, tooltip:, color:, size:, focusNode:, onKeyEvent:)` | `Button(variant: ButtonVariant.plainIcon, size: ButtonSize.icon, icon:, onPressed: onTap, tooltip:, color:, iconSize: size, height: hitSize, focusNode:, onKeyEvent:)` |
| `ForjaIconButton(icon:, onTap:, tooltip:)` | `Button(variant: ButtonVariant.outline, size: ButtonSize.icon, icon:, onPressed: onTap, tooltip:)` |
| `ForjaCloseButton(…)` / `.compact` | `Button(variant: ButtonVariant.plainIcon, size: ButtonSize.icon, icon: Icons.close_rounded, onPressed: onTap, tooltip:, color:, iconSize: size, height: hitSize, compact: true, onKeyEvent:)` |
| `ForjaInteractive` | **not** Button — `package:forja/shared/shell/forja_interactive.dart` |

`ForjaGhostButton` / `ForjaPlainIcon` / `ForjaCloseButton` / `ForjaIconButton` / `ForjaTopBarIcon` are **deleted**. Do not reintroduce them. `ForjaInteractive` is `package:forja/shared/shell/forja_interactive.dart` — import that file, not a buttons barrel.

Do **not** import `compat/legacy_buttons.dart` from app code. Rewrite constructors.

`ForjaButton.activateOnKeyUp` — drop; TV activate is host `ShellInputPolicy` + `Button` focus. If a call site still needs key-up activate, keep that logic next to the call site, not a second button type.

---

## Controls

| Old | New import | Recipe |
|-----|------------|--------|
| `ForjaSwitch` / `forjaSwitchThemeData` | `package:forja_foundation/components/switch.dart` | `Switch(value:, onChanged:, scale:, emphasized:)` — hide Material `Switch` on that file only (`import 'package:flutter/material.dart' hide Switch;`) |
| `ForjaShellChip` | host shell until Chip covers TV | `package:forja/shared/shell/forja_shell_chip.dart` (moved) **or** `package:forja_foundation/components/chip.dart` when the row is a simple filter chip |
| `ForjaChipRow` | `package:forja/shared/shell/forja_chip_row.dart` (moved) | |
| `ForjaActionChip` | `package:forja/shared/shell/forja_action_chip.dart` (moved) | |
| `ForjaStatusTabs` / `ForjaUnderlineTab` | `package:forja/shared/shell/…` (moved) | package `Tabs` only if the row is the new family |

---

## Feedback

Winner: **move the real host implementations** to `shared/shell/`. Package `showForjaToast` is a SnackBar stub — do not point live call sites at it.

| Old | New import |
|-----|------------|
| `ForjaToast` / `ForjaToastHost` / `ForjaToastKind` | `package:forja/shared/shell/forja_toast.dart` |
| `ForjaLoadingDots` / `ForjaBusyCancelGlyph` | `package:forja/shared/shell/forja_loading_dots.dart` |
| `ForjaPlayerOverlayPanel` | `package:forja/shared/shell/forja_player_overlay.dart` |
| `ForjaFrostedPanel` | `package:forja/shared/shell/forja_frosted_panel.dart` |
| `FractalGlassGradient` / splash logo | `package:forja/shared/shell/brand/…` (moved from primitives/brand + feedback) |

---

## Chrome / images / tap

| Old | New |
|-----|-----|
| `ForjaNetworkImage` | `package:forja_foundation/components/network_image.dart` after package gains `alignment`, `useOldImageOnUrlChange`, `memCacheWidth`, `filterQuality` |
| `shellFocusableTap` / `shellGridColumnCount` / `shellTvRegisterRow` | `package:forja/shared/shell/shell_focusable_tap.dart` |
| Package `FocusableTap` | kit-only stand-in — **not** a replacement for `shellFocusableTap` |
| `HoverScale` | `package:forja/shared/shell/hover_scale.dart` |
| `HorizontalScroller` | `package:forja/shared/shell/horizontal_scroller.dart` |
| `LoadingOverlay` / `dismissActiveLoadingOverlayRoute` | `package:forja/shared/shell/loading_overlay.dart` |
| `ShellCardPlayOverlay` | `package:forja/shared/shell/shell_card_play_overlay.dart` |
| `ShellErrorRetryPanel` | `package:forja/shared/shell/shell_error_retry_panel.dart` |
| `ShellMoodCircleLayout` / `ShellMoodCircleItem` | `package:forja/shared/shell/shell_mood_circle.dart` |
| `ForjaPosterCard` / `ForjaServerGrid` | `package:forja/shared/shell/…` (moved) |

---

## Host shell (moved off foundation)

| Old path | New path |
|----------|----------|
| `foundation/primitives/shell/forja_shell_scope.dart` | `package:forja/shared/shell/forja_shell_scope.dart` |
| `…/forja_shell_layout.dart` (`shellScaled`, `shellUsesWideLayout`, …) | `package:forja/shared/shell/forja_shell_layout.dart` |
| `…/forja_shell_profile.dart` (`ShellProfile`, `resolveShellProfile`) | `package:forja/shared/shell/forja_shell_profile.dart` |
| `…/forja_shell_platform.dart` (`shellPlatformConfigFor`) | `package:forja/shared/shell/forja_shell_platform.dart` |
| `…/forja_shell_metrics.dart` | `package:forja/shared/shell/forja_shell_metrics.dart` |
| `…/forja_shell_input_policy.dart` | `package:forja/shared/shell/forja_shell_input_policy.dart` |
| `…/forja_shell_keyboard_focus.dart` | `package:forja/shared/shell/forja_shell_keyboard_focus.dart` |
| `…/forja_shell_keyboard_focus_scope.dart` | `package:forja/shared/shell/forja_shell_keyboard_focus_scope.dart` |
| `…/forja_shell_section_title.dart` | `package:forja/shared/shell/forja_shell_section_title.dart` |
| `…/forja_shell_tab_header.dart` | `package:forja/shared/shell/forja_shell_tab_header.dart` |
| `foundation/primitives/tv/tv_browse_text_field.dart` | `package:forja/shared/shell/tv_browse_text_field.dart` |
| `…/tv_search_browse_overlay.dart` | `package:forja/shared/shell/tv_search_browse_overlay.dart` |
| `foundation/primitives/desktop/desktop_window_chrome.dart` | `package:forja/shared/shell/desktop_window_chrome.dart` |
| `…/desktop_window_geometry.dart` | `package:forja/shared/shell/desktop_window_geometry.dart` |
| `…/desktop_window_focus.dart` | `package:forja/shared/shell/desktop_window_focus.dart` |
| `foundation/tv/shell_tv_coordinator.dart` | `package:forja/shared/shell/tv/shell_tv_coordinator.dart` |
| `foundation/tv/shell_tv_focus.dart` | `package:forja/shared/shell/tv/shell_tv_focus.dart` |
| `foundation/tv/tv_focus_graph.dart` | `package:forja/shared/shell/tv/tv_focus_graph.dart` |
| `foundation/tv/shell_tv_back_handler.dart` | `package:forja/shared/shell/tv/shell_tv_back_handler.dart` |
| `foundation/tv/shell_tv_app_exit.dart` | `package:forja/shared/shell/tv/shell_tv_app_exit.dart` |
| `foundation/tv/shell_tv_hold_accel.dart` | `package:forja/shared/shell/tv/shell_tv_hold_accel.dart` |
| `foundation/tv/tv_remote_debug.dart` | `package:forja/shared/shell/tv/tv_remote_debug.dart` |
| `foundation/tv/media_details_tv_scope.dart` | `package:forja/shared/shell/tv/media_details_tv_scope.dart` |

---

## Engine / player / host services (not pack folders)

| Surface | New path |
|---------|----------|
| Live feed merge / resolve / unlock | `package:forja/shared/engine/live/**` (no pack UX) |
| Horizon / view / open menus / kind icons / search hint / panel tabs | live_sports hub pack layout + settings |
| List-follow / merge | `package:forja/shared/engine/lists/**` |
| Torrent release parse | `package:forja/shared/engine/models/torrent_release_metadata.dart` |
| Torrent source panels | `package:forja/shared/player/sources/**` |
| Generic catalog kit (boot, event cards, resolve panel, my-list catalog) | `package:forja/shared/host/kit/**` (`KitEventPaint` from list rows — not `MatchEvent`) |
| Packs / PackAssets | `package:forja/shared/host/packs/**` |
| Watch history | `package:forja/shared/host/watch/watch_history.dart` |
| Update dialog / banner | `package:forja/shared/host/update/**` |
| Keychain consent | `package:forja/shared/host/account/**` |

**Forbidden destinations:** `shared/host/lists/**`, `shared/host/live_sports/**`, `shared/host/sources/**` — pack surfaces, not host.

---

## Kit types / protocol (package)

| Old | New |
|-----|-----|
| `KitTypes` | `package:forja_foundation/kit/kit_types.dart` |
| `kit_layout_map` | `package:forja_foundation/kit/kit_layout_map.dart` |
| `Deeplink` / filter / protocol / pack_capabilities | `package:forja_foundation/protocol/<file>.dart` |
| `normalizeCoverUrl` | `package:forja_foundation/utils/cover_urls.dart` |
| `resolveCoverUrl` | `package:forja/shared/host/kit/cover_urls.dart` — host TMDB relative-path, not the package util |

Package kit composers (`widgets/catalog/cinematic_hero.dart`, `details/details_hero.dart`, `details/play_row.dart`, `catalog/because_section.dart`, …) are props-only gallery copies. Running catalog UI is `package:forja/shared/host/kit/**`. New work that is props-only imports the package file. Do not recreate `shared/foundation/` copies.

---

## Kit runtime — moved off foundation

| Surface | New path |
|---------|----------|
| Catalog kit (shell, details, hero, search, layout, posters) | `package:forja/shared/host/kit/<file>.dart` |
| Play / probe / stream loading | `package:forja/shared/playback/<file>.dart` |
| Episode / media-details / sources TV | `package:forja/shared/player/details/<file>.dart` |
| Vertical filters / letter jump | `package:forja/shared/shell/<file>.dart` |

`apps/forja/lib/shared/foundation/` is **deleted**. Do not restore it. Q1–Q12 visual sign-off is still unsigned (`docs/rfc/106-qa-matrix.md`).

---

## Tests — same tables

Every inventory test that imported foundation chrome follows the **same** New path. No “tests later.”

`apps/forja/test/catalog_extract_context_test.dart`
`apps/forja/test/catalog_hub_search_capabilities_test.dart`
`apps/forja/test/catalog_kit_category_circle_meta_test.dart`
`apps/forja/test/catalog_kit_live_types_test.dart`
`apps/forja/test/catalog_movie_id_for_play_test.dart`
`apps/forja/test/catalog_open_test.dart`
`apps/forja/test/catalog_play_filters_test.dart`
`apps/forja/test/catalog_protocol_test.dart`
`apps/forja/test/desktop_browser_auth_test.dart`
`apps/forja/test/engine_test.dart`
`apps/forja/test/episode_torrent_search_queries_test.dart`
`apps/forja/test/forja_loading_dots_test.dart`
`apps/forja/test/forja_logo_halo_pixels_test.dart`
`apps/forja/test/hub_boot_prefetch_test.dart`
`apps/forja/test/hub_details_meta_test.dart`
`apps/forja/test/iptv_play_source_display_test.dart`
`apps/forja/test/kisskh_cover_url_test.dart`
`apps/forja/test/kit_schedule_event_query_test.dart`
`apps/forja/test/kit_sources_live_tv_browse_test.dart`
`apps/forja/test/list_follow_from_watched_test.dart`
`apps/forja/test/list_follow_test.dart`
`apps/forja/test/list_letter_jump_test.dart`
`apps/forja/test/live_embed_m3u8_rewrite_test.dart`
`apps/forja/test/live_feed_merge_test.dart`
`apps/forja/test/live_sports_host_feature_test.dart`
`apps/forja/test/live_sports_sport_filter_test.dart`
`apps/forja/test/live_sports_team_parse_test.dart`
`apps/forja/test/live_stremio_meta_test.dart`
`apps/forja/test/main_screen_shell_test.dart`
`apps/forja/test/my_list_catalog_test.dart`
`apps/forja/test/pack_addon_settings_test.dart`
`apps/forja/test/pack_connected_auth_test.dart`
`apps/forja/test/pack_secret_settings_test.dart`
`apps/forja/test/player_back_exit_gate_test.dart`
`apps/forja/test/player_popup_panel_back_test.dart`
`apps/forja/test/player_stream_menu_order_test.dart`
`apps/forja/test/player_tv_remote_test.dart`
`apps/forja/test/plugin_install_validator_test.dart`
`apps/forja/test/plugin_pack_update_focus_test.dart`
`apps/forja/test/profile_avatar_test.dart`
`apps/forja/test/provider_score_probe_sync_test.dart`
`apps/forja/test/shell_adapters_test.dart`
`apps/forja/test/shell_bus_test.dart`
`apps/forja/test/shell_card_play_overlay_test.dart`
`apps/forja/test/shell_metrics_test.dart`
`apps/forja/test/shell_navigation_levels_test.dart`
`apps/forja/test/shell_profile_behavior_test.dart`
`apps/forja/test/shell_profile_test.dart`
`apps/forja/test/shell_scaffold_test.dart`
`apps/forja/test/shell_tab_refresh_test.dart`
`apps/forja/test/shell_tv_app_exit_test.dart`
`apps/forja/test/shell_tv_coordinator_test.dart`
`apps/forja/test/shell_tv_hold_accel_test.dart`
`apps/forja/test/shell_tv_tabs_test.dart`
`apps/forja/test/sources_filter_panel_width_test.dart`
`apps/forja/test/sources_panel_back_test.dart`
`apps/forja/test/sources_panel_filters_nuvio_lazy_test.dart`
`apps/forja/test/sources_panel_tv_test.dart`
`apps/forja/test/sources_request_context_test.dart`
`apps/forja/test/splash_halo_test.dart`
`apps/forja/test/tab_watch_history_test.dart`
`apps/forja/test/torrent_release_metadata_test.dart`
`apps/forja/test/tv_focus_graph_test.dart`
`apps/forja/test/tv_season_episode_picker_test.dart`

Kit-runtime tests import `shared/host/kit/**`, `shared/engine/**`, `shared/player/**`, or `package:forja_foundation/<file>.dart` — never `shared/foundation/`.

---

## Done greps

```bash
rg "package:forja/shared/foundation/" apps/forja --glob '*.dart'
rg "forja_foundation.dart' hide" apps/forja
rg "ForjaGhostButton|ForjaButton\(|ForjaButtonVariant" \
  apps/forja/lib/features apps/forja/lib/shell apps/forja/lib/shared/player
```

All three empty. `apps/forja/lib/shared/foundation/` is **deleted**.
