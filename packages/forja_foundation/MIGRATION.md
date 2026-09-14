# Migrating to `forja_foundation` (RFC-106)

This file is the **only** checklist. If a row has no New path, that is a
package or host gap — close it in the same slice. Do not skip. Do not treat
`package:forja/shared/foundation/primitives/**` as a destination.

## Rules

1. Import the **file**, never `package:forja_foundation/forja_foundation.dart`.
2. Never `hide Switch, Chip, …` against Material.
3. Never add `import` lines to `part of` files — put them on the library parent.
4. Never import `package:forja/shared/foundation/**`. That tree is **deleted**. Do not recreate it.
5. If the package is missing an API: **extend the package** (`widgets/` / `components/` / `blocks/` / `protocol/`) or **move glue** to `shell/`, `shared/engine/`, or `shared/player/`. Do **not** put catalog UI in `shared/kit`, `shared/host/kit`, or `shared/foundation`. Those dumps are forbidden.

`forja_foundation.dart` is a gallery/test barrel.

Pack JSON wire: [PACK_AUTHORS.md](PACK_AUTHORS.md). Do not edit forja-packs unless an alias is dropped.

---

## Destination buckets

Every old symbol has **exactly one** New import.

| Bucket | Import prefix | What |
|--------|---------------|------|
| Package DS | `package:forja_foundation/<file>.dart` | tokens, Button, Switch, Chip, layout types (`LayoutTypes` / `LayoutMap`), protocol, NetworkImage, props-only composers |
| Host shell | `package:forja/shell/{core,filters,focus,feedback,desktop,brand,tv,update}/…` | ShellScope, TV, desktop chrome, toast, ForjaInteractive |
| Engine | `package:forja/shared/engine/**` | rust-adjacent live models/schedule state, list-follow, torrent parse |
| Player | `package:forja/shared/player/**` | torrent source panels + media-details chrome (orchestration) |
| Host services | `package:forja/shared/host/{packs,update,account,watch}/**` | pack install + app update + account + watch history |

**Forbidden dumps:** `shared/kit/**`, `shared/host/kit/**`, `shared/foundation/**`, `shared/host/lists|live_sports|sources`. Catalog UI is this package.

---

## Tokens

| Old symbol | Old path | New import |
|------------|----------|------------|
| `ForjaShellColors` | `foundation/primitives/tokens/forja_shell_colors.dart` | `package:forja_foundation/tokens/forja_shell_colors.dart` |
| `ShellTokens` | `…/tokens/forja_shell_tokens.dart` | `package:forja_foundation/tokens/forja_shell_tokens.dart` |
| `DetailsTokens` | `…/tokens/forja_details_tokens.dart` | `package:forja_foundation/tokens/forja_details_tokens.dart` |
| `SettingsTokens` | `…/tokens/forja_settings_tokens.dart` | `package:forja_foundation/tokens/forja_settings_tokens.dart` |
| `DesignTokens` | `…/tokens/forja_theme.dart` | `package:forja_foundation/tokens/forja_theme.dart` |
| `ForjaThemeExtension` / `forjaThemeData()` | host theme glue | `package:forja_foundation/tokens/forja_theme_extension.dart` — host `AppTheme` sets `extensions: [ForjaThemeExtension.dark()]` |
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
| `ForjaInteractive` | **not** Button — `package:forja/shell/focus/forja_interactive.dart` |

`ForjaGhostButton` / `ForjaPlainIcon` / `ForjaCloseButton` / `ForjaIconButton` / `ForjaTopBarIcon` / `compat/legacy_buttons.dart` are **deleted**. Do not reintroduce them. `ForjaInteractive` is `package:forja/shell/focus/forja_interactive.dart` — import that file, not a buttons barrel.

`ForjaButton.activateOnKeyUp` — drop; TV activate is host `ShellInputPolicy` + `Button` focus. If a call site still needs key-up activate, keep that logic next to the call site, not a second button type.

---

## Controls

| Old | New import | Recipe |
|-----|------------|--------|
| `ForjaSwitch` / `forjaSwitchThemeData` | `package:forja_foundation/components/switch.dart` | `Switch(value:, onChanged:, scale:, emphasized:)` — hide Material `Switch` on that file only (`import 'package:flutter/material.dart' hide Switch;`) |
| `ForjaShellChip` | `package:forja_foundation/widgets/chrome/shell_chip.dart` | |
| `ForjaChipRow` / `ForjaActionChip` / `components/Chip` / `Tabs` / `UnderlineTabBar` / `ForjaStatusTabs` / `ForjaUnderlineTab` | **deleted** (RFC-111) | |

---

## Feedback

Winner: **move the real host implementations** to `shell/`. Package `showForjaToast` is a SnackBar stub — do not point live call sites at it.

| Old | New import |
|-----|------------|
| `ForjaToast` / `ForjaToastHost` / `ForjaToastKind` | `package:forja/shell/feedback/forja_toast.dart` |
| `ForjaLoadingDots` / `ForjaBusyCancelGlyph` | `package:forja/shell/feedback/forja_loading_dots.dart` |
| `ForjaPlayerOverlayPanel` | `package:forja/shell/feedback/forja_player_overlay.dart` |
| `ForjaFrostedPanel` | `package:forja/shell/feedback/forja_frosted_panel.dart` |
| `FractalGlassGradient` / splash logo | `package:forja/shell/brand/…` (moved from primitives/brand + feedback) |

---

## Chrome / images / tap

| Old | New |
|-----|-----|
| `ForjaNetworkImage` | `package:forja_foundation/components/network_image.dart` after package gains `alignment`, `useOldImageOnUrlChange`, `memCacheWidth`, `filterQuality` |
| `shellFocusableTap` / `shellGridColumnCount` / `shellTvRegisterRow` | `package:forja/shell/focus/shell_focusable_tap.dart` |
| Package `FocusableTap` | kit-only stand-in — **not** a replacement for `shellFocusableTap` |
| `HoverScale` | `package:forja/shell/focus/hover_scale.dart` |
| `HorizontalScroller` | `package:forja/shell/chrome/horizontal_scroller.dart` |
| `LoadingOverlay` / `dismissActiveLoadingOverlayRoute` | `package:forja/shell/feedback/loading_overlay.dart` |
| `ShellCardPlayOverlay` | `package:forja/shell/feedback/shell_card_play_overlay.dart` |
| `ShellErrorRetryPanel` | `package:forja/shell/feedback/shell_error_retry_panel.dart` |
| `ShellMoodCircleLayout` / `ShellMoodCircleItem` | `MoodCircle` / `MoodCircleLayout` + `MoodSection` |
| `ForjaPosterCard` / `ForjaServerGrid` | `package:forja/shell/…` (moved) |

---

## Host shell (moved off foundation)

| Old path | New path |
|----------|----------|
| `foundation/primitives/shell/forja_shell_scope.dart` | `package:forja/shell/core/forja_shell_scope.dart` |
| `…/forja_shell_layout.dart` (`shellScaled`, `shellUsesWideLayout`, …) | `package:forja/shell/core/forja_shell_layout.dart` |
| `…/forja_shell_profile.dart` (`ShellProfile`, `resolveShellProfile`) | `package:forja/shell/core/forja_shell_profile.dart` |
| `…/forja_shell_platform.dart` (`shellPlatformConfigFor`) | `package:forja/shell/core/forja_shell_platform.dart` |
| `…/forja_shell_metrics.dart` | `package:forja/shell/core/forja_shell_metrics.dart` |
| `…/forja_shell_input_policy.dart` | `package:forja/shell/core/forja_shell_input_policy.dart` |
| `…/forja_shell_keyboard_focus.dart` | `package:forja/shell/core/forja_shell_keyboard_focus.dart` |
| `…/forja_shell_keyboard_focus_scope.dart` | `package:forja/shell/core/forja_shell_keyboard_focus_scope.dart` |
| `…/forja_shell_section_title.dart` | `package:forja/shell/chrome/forja_shell_section_title.dart` |
| `…/forja_shell_tab_header.dart` | `package:forja/shell/chrome/forja_shell_tab_header.dart` |
| `foundation/primitives/tv/tv_browse_text_field.dart` | `package:forja/shell/tv/tv_browse_text_field.dart` |
| `…/tv_search_browse_overlay.dart` | `package:forja/shell/tv/tv_search_browse_overlay.dart` |
| `foundation/primitives/desktop/desktop_window_chrome.dart` | `package:forja/shell/desktop/desktop_window_chrome.dart` |
| `…/desktop_window_geometry.dart` | `package:forja/shell/desktop/desktop_window_geometry.dart` |
| `…/desktop_window_focus.dart` | `package:forja/shell/desktop/desktop_window_focus.dart` |
| `foundation/tv/shell_tv_coordinator.dart` | `package:forja/shell/tv/shell_tv_coordinator.dart` |
| `foundation/tv/shell_tv_focus.dart` | `package:forja/shell/tv/shell_tv_focus.dart` |
| `foundation/tv/tv_focus_graph.dart` | `package:forja/shell/tv/tv_focus_graph.dart` |
| `foundation/tv/shell_tv_back_handler.dart` | `package:forja/shell/tv/shell_tv_back_handler.dart` |
| `foundation/tv/shell_tv_app_exit.dart` | `package:forja/shell/tv/shell_tv_app_exit.dart` |
| `foundation/tv/shell_tv_hold_accel.dart` | `package:forja/shell/tv/shell_tv_hold_accel.dart` |
| `foundation/tv/tv_remote_debug.dart` | `package:forja/shell/tv/tv_remote_debug.dart` |
| `foundation/tv/media_details_tv_scope.dart` | `package:forja/shell/tv/media_details_tv_scope.dart` |

---

## Engine / player / host services (not pack folders)

| Surface | New path |
|---------|----------|
| Live feed merge / resolve / unlock | `package:forja/shared/engine/live/**` (no pack UX) |
| Horizon / view / open menus / kind icons / search hint / panel tabs | live_sports hub pack layout + settings |
| List-follow / merge | `package:forja/shared/engine/lists/**` |
| Torrent release parse | `package:forja/shared/engine/models/torrent_release_metadata.dart` |
| Torrent source panels | `package:forja/shared/player/sources/**` |
| Generic catalog kit UI | `package:forja_foundation/widgets/**` · `blocks/**` — see evacuate table. Glue: `shared/engine/hub/` |
| Packs / PackAssets | `package:forja/shared/engine/packs/**` · UI: `package:forja/features/settings/packs/**` |
| Watch history | `package:forja/shared/engine/store/watch_history.dart` |
| Update dialog / banner | `package:forja/shell/update/**` |
| Keychain consent | `package:forja/features/settings/about/macos_keychain_consent_screen.dart` |

**Forbidden destinations:** `shared/kit/**`, `shared/host/kit/**`, `shared/host/lists/**`, `shared/host/live_sports/**`, `shared/host/sources/**`.

---

## Kit types / protocol (package)

| Old | New |
|-----|-----|
| `LayoutTypes` | `package:forja_foundation/protocol/layout_types.dart` |
| `kit_layout_map` | `package:forja_foundation/protocol/layout_map.dart` |
| `Deeplink` / filter / protocol / pack_capabilities | `package:forja_foundation/protocol/<file>.dart` |
| `normalizeCoverUrl` / `resolveAbsoluteCoverUrl` | `package:forja_foundation/utils/cover_urls.dart` — packs emit absolute https; **host `engine/hub/cover_urls.dart` is deleted** |

Package composers are the **running** UI. Host maps MetaRuntime / Riverpod / TV into props. Do not keep a parallel tree in `shared/kit`. Do not rewrite `/abc.jpg` via `TmdbApi` in host catalog paint.

---

## `shared/kit` evacuate (checklist)

`apps/forja/lib/shared/kit/` is **gone**. Import the **file**. Glue that cannot enter zone A lives in engine / player / shell / host services — not another kit folder.

**Legend:** ✅ moved · 🔄 this slice · ⬜ leftover

| Old (`shared/kit/`) | New | Status |
|---------------------|-----|--------|
| `hero_overview_text.dart` | `package:forja_foundation/widgets/details/hero_overview_text.dart` | ✅ |
| `hero_facts_panel.dart` | `package:forja_foundation/widgets/details/facts_panel.dart` (`FactsPanel` / `fromFields`) | ✅ |
| `kit_details_facts_panel.dart` | same `FactsPanel(rows:)` | ✅ |
| `hero_meta_line.dart` | `package:forja_foundation/widgets/details/meta_line.dart` (`MetaLine`) | ✅ |
| `hero_title.dart` | `package:forja_foundation/widgets/details/hero_title.dart` — `String title` + logo; host passes `movie.title` + TV/selectable flags | ✅ |
| `hero_utils.dart` | `package:forja_foundation/utils/hero_utils.dart` | ✅ |
| `kit_hero_content_scrim.dart` | `package:forja_foundation/widgets/details/hero_content_scrim.dart` | ✅ |
| `hero_banner.dart` | **deleted** — unused (`AppRouter` + `Movie` carousel, no call sites) | ✅ |
| `hero_watch_providers_row.dart` | `package:forja_foundation/widgets/details/watch_providers_row.dart` | ✅ |
| `rotating_hero_backdrop.dart` | `package:forja_foundation/widgets/catalog/rotating_hero_backdrop.dart` | ✅ |
| `settled_network_image.dart` | `package:forja_foundation/components/settled_network_image.dart` | ✅ |
| `hero_pill_buttons.dart` | paint: `package:forja_foundation/widgets/details/hero_pill_surfaces.dart`; Interactive/TV: `package:forja/shell/focus/hero_pill_buttons.dart` | ✅ |
| `cinematic_hero.dart` | **kept** (RFC-109 A69) — hub catalog carousel; details stay on `widgets/details/details_hero.dart` | ✅ |
| `because_section.dart` · `continue_section.dart` · `continue_watching_card.dart` · `mood_section.dart` | **kept** (RFC-109 A69) — hub catalog sections; host mounts via `kit/slots/*` | ✅ |
| `catalog_hero_section.dart` · `movie_poster*.dart` · `movie_atmosphere.dart` · `kit_event_dense_tile` | **deleted** composers (RFC-111). Keep: `poster_card` / `event_card` / `home_loading_skeleton` under `widgets/catalog/`. | ✅ |
| `kit_layout_scope.dart` · `kit_stack_widget.dart` · `kit_side_panel_overlay.dart` · `kit_portal_list_panel.dart` | `package:forja_foundation/widgets/chrome/{layout_scope,layout_stack,side_panel_overlay,portal_list_panel}.dart` | ✅ |
| `kit_panel_tabs.dart` | `package:forja_foundation/widgets/sources/panel_tabs.dart` | ✅ |
| `kit_category_circle_meta.dart` | `package:forja_foundation/widgets/catalog/category_circle_meta.dart` | ✅ |
| `tmdb_paint_gate.dart` | `package:forja_foundation/widgets/details/tmdb_paint_gate.dart` | ✅ |
| `kit_shell.dart` · `kit_list_widget.dart` · `kit_tabs_widget.dart` · `kit_section.dart` · `kit_menu_widget.dart` · `kit_search_*.dart` · `kit_list_event_search.dart` · `kit_top_bar*.dart` · `kit_category_bar.dart` · `kit_catalog_filter_sheet.dart` · `kit_filter_sheet_option.dart` · `kit_portals_chip.dart` · `recent_search_helper_tile.dart` · `kit_chrome_top_bar.dart` | **RFC-111:** dead catalog layout composers deleted. Live: search stack + `CatalogBody` + `PortalsChip`; hub chrome = host `KitChromeTopBar`. | ✅ |
| `kit_panel_host.dart` · `kit_feed_chrome.dart` · `kit_top_bar_host_hooks.dart` · `kit_top_menu_registry.dart` | `package:forja/shared/engine/hub/<file>.dart` | ✅ |
| `kit_details_screen.dart` · `kit_details_hero.dart` · `kit_details_play_row.dart` · `kit_entry_details.dart` · `kit_match_details_page.dart` · `kit_list_status_*` | paint: `blocks/details/{details_block,match_details_block}.dart` (`DetailsScreen` / `EntryDetails` / `MatchDetailsPage`) + `widgets/details/{details_hero,play_row,list_status_*}.dart`. Host MetaRuntime/TV/ListFollow: `package:forja/shared/player/details/<file>.dart` | ✅ |
| Catalog / search page shells | `blocks/catalog/catalog_body_block.dart` · `blocks/search/catalog_search_page.dart` — PackPaintTree types `catalogBody` / `search` (RFC-112). Hubs share `catalogBody`; no `iptv*` / `liveSports*` / `myList*` block ids. | ✅ |
| `kit_details_sections.dart` UI | `package:forja_foundation/widgets/details/details_rails.dart`; parse/fetch leftover: `package:forja/shared/engine/hub/kit_details_sections.dart` | ✅ |
| `kit_details_stremio.dart` · `kit_details_meta.dart` · `kit_details_play.dart` | `package:forja/shared/engine/hub/<file>.dart` | ✅ |
| `kit_details_host_hooks.dart` · host `tmdb_details_enrich.dart` | **deleted** — packs own enrich | ✅ |
| `kit_sources*.dart` · `kit_resolve_panel_host.dart` | paint: `package:forja_foundation/widgets/sources/{sources_panel_chrome,live_tv_browse}.dart`. `ResolvePanel` **deleted** (RFC-111). Host TV/hooks: `package:forja/shared/player/sources/<file>.dart` | ✅ |
| `meta_runtime.dart` · `meta_cache.dart` · `meta_movie.dart` · `meta_feed_list_source.dart` · `meta_surface_open.dart` · `plugin_nav.dart` · `catalog_open.dart` (was `kit_open`) · `kit_live_boot.dart` · `live_surface_open.dart` · `kit_list_source.dart` · `kit_list_event_query.dart` · `kit_list_open_mode.dart` · `kit_event_paint.dart` · `kit_row_prefetch.dart` · `details_fetch.dart` · `host_list_registry.dart` · `kit_*_hooks.dart` · `play_filters.dart` · `chrome_filters.dart` · `pack_filters.dart` · `legacy_*.dart` | `package:forja/shared/engine/hub/<file>.dart` | ✅ |
| `cover_urls.dart` (host) | **deleted** — use `package:forja_foundation/utils/cover_urls.dart` | ✅ |
| `search_recent_queries.dart` | `package:forja/shared/engine/runtime/search/search_recent_queries.dart` | ✅ |
| `my_list_catalog_open.dart` · `my_list_catalog_source.dart` · `my_list_host.dart` | `package:forja/shared/engine/lists/<file>.dart` | ✅ |
| `desktop_selectable_title.dart` | `package:forja/shell/desktop/desktop_selectable_title.dart` | ✅ |
| `kit_focus.dart` | `package:forja/shell/focus/focus_edge.dart` | ✅ |
| `lib/kit/kit_types.dart` · `kit_layout_map.dart` | `package:forja_foundation/protocol/{layout_types,layout_map}.dart` (`LayoutTypes` / `LayoutMap`) — `lib/kit/` deleted | ✅ |
| `forja_host_assets.dart` | `package:forja/shared/engine/packs/forja_host_assets.dart` | ✅ |

Play / probe / stream loading stays `shared/playback/`. Episode picker / sources TV stays `shared/player/details/`. Vertical filters registry stays `shell/filters/` (paint via `LogoMenuRail`).

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

Kit-runtime tests import `package:forja_foundation/<file>.dart`, `shared/engine/**`, or `shared/player/**` — never `shared/foundation/` or new `shared/kit/` files.

---

## Done greps

```bash
rg "package:forja/shared/foundation/" apps/forja --glob '*.dart'
rg "forja_foundation.dart' hide" apps/forja
rg "ForjaGhostButton|ForjaButton\(|ForjaButtonVariant" \
  apps/forja/lib/features apps/forja/lib/shell apps/forja/lib/shared/player
```

All three empty. `apps/forja/lib/shared/foundation/` is **deleted**.
