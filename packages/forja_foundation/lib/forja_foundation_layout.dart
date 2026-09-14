/// Layout zone — kit.list registry, top-bar hooks, portals chip (RFC migrate).
///
/// May use flutter_riverpod. Must not import `package:forja/`.
library;

export 'package:forja_foundation/layout/list/kit_list_entry.dart';
export 'package:forja_foundation/layout/list/kit_list_paint.dart';
export 'package:forja_foundation/layout/list/list_source.dart';
export 'package:forja_foundation/layout/list/panel_host.dart';
export 'package:forja_foundation/layout/list/list_open_mode.dart';
export 'package:forja_foundation/layout/list/list_event_query.dart';
export 'package:forja_foundation/layout/list/host_list_registry.dart';
export 'package:forja_foundation/layout/top_bar_host_hooks.dart';
export 'package:forja_foundation/layout/panel_source_flags_hooks.dart';
export 'package:forja_foundation/layout/chrome/kit_portals_chip.dart';

export 'package:forja_foundation/layout/pack_layout_host.dart';
export 'package:forja_foundation/layout/pack_layout_host_wire.dart' show PluginKitTopBar;
export 'package:forja_foundation/layout/pack_layout_capabilities.dart'
    show PackLayoutCapabilities, PackLayoutMovie, PackListFollowTarget, PackPluginSnapshot;
export 'package:forja_foundation/layout/shell_tab_refresh.dart';
export 'package:forja_foundation/layout/feed_chrome.dart';
export 'package:forja_foundation/layout/focus_edge.dart';
export 'package:forja_foundation/layout/top_menu_registry.dart';
export 'package:forja_foundation/layout/chrome_menu_item.dart';
