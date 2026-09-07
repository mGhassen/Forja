/// Foundation — app-wide base: primitives, kit, protocol, services.
///
/// Layout: [primitives] · [components] · [blocks] · [protocol] · [services] · [lib].
/// Services domains: `meta/` · `registry/` · `nav/` · `pack/` · `follow/` · `watch/`.
/// Product hub tabs are pack-owned. Live Sports host glue lives under
/// `shared/host/live_sports/` (not here).
library;

export 'primitives/primitives.dart';
export 'lib/pack_assets.dart';
export 'lib/forja_host_assets.dart';
export 'lib/cover_urls.dart';
export 'protocol/deeplink.dart';
export 'protocol/filter.dart';
export 'protocol/protocol.dart';
export 'services/meta/cache.dart';
export 'services/meta/runtime.dart';
export 'services/registry/host_list_registry.dart';
export 'services/registry/kit_top_bar_host_hooks.dart';
export 'services/registry/meta_surface_open.dart';
export 'services/nav/plugin_nav.dart';
export 'blocks/shell/kit_open.dart';
export 'blocks/shell/kit_search_screen.dart';
export 'blocks/shell/kit_shell.dart';
export 'components/cards/kit_poster_card.dart';
export 'components/cards/kit_event_card.dart';
export 'components/cards/kit_event_dense_tile.dart';
export 'components/chrome/chrome_filters.dart';
export 'components/chrome/kit_category_bar.dart';
export 'components/chrome/kit_filter_sheet_option.dart';
export 'components/chrome/kit_top_bar_actions.dart';
export 'components/chrome/vertical_filters.dart';
export 'components/chrome/vertical_filters_rail.dart';
export 'components/chrome/kit_search_filters.dart';
export 'components/chrome/kit_search_page.dart';
export 'components/layout/kit_focus.dart';
export 'components/layout/kit_top_bar.dart';
export 'components/layout/kit_top_menu_registry.dart';
export 'components/layout/kit_list_source.dart';
export 'components/layout/kit_list_widget.dart';
export 'components/layout/kit_menu_widget.dart';
export 'components/layout/kit_stack_widget.dart';
export 'components/layout/kit_tabs_widget.dart';
export 'components/layout/kit_types.dart';
export 'components/layout/kit_layout_scope.dart';
export 'components/sections/because_section.dart';
export 'components/sections/continue_watching_card.dart';
export 'components/sections/continue_watching_section.dart';
export 'components/sections/continue_widget.dart';
export 'blocks/details/play_filters.dart';
export 'blocks/details/kit_details_play.dart';
export 'blocks/details/kit_details_sections.dart';
export 'blocks/play/kit_episodes.dart';
export 'blocks/play/play_context.dart';
export 'blocks/play/play_hooks.dart';
export 'blocks/play/play_resolve.dart';
export 'blocks/play/play_session.dart';
export 'blocks/play/iptv_play.dart';
export 'blocks/play/live_play.dart';
export 'blocks/play/sources_request_context.dart';
export 'components/layout/kit_panel_host.dart';
export 'components/panel/kit_sources_panel.dart';
export 'blocks/play/stremio_stream_id.dart';
export 'components/meta/meta_movie.dart';
export 'services/follow/list_follow.dart';
export 'services/follow/list_follow_from_watched.dart';
export 'services/follow/list_providers.dart';
export 'services/follow/external_list_providers.dart';
export 'tv/shell_tv_coordinator.dart';
export 'tv/shell_tv_focus.dart';
export 'tv/tv_focus_graph.dart';
export 'tv/media_details_tv_scope.dart';
export 'lib/match_event.dart';
