import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/features/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/player/player/utils.dart' show probeStreamSourceUrl;
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/live_matches/catalog/live_schedule_filters.dart';
import 'package:forja/features/live_matches/streams/data/live_prefs.dart';
import 'package:forja/features/live_matches/streams/data/live_sport_filter.dart';
import 'package:forja/features/live_matches/streams/data/live_stremio_meta.dart';
import 'package:forja/features/live_matches/streams/data/live_team_parse.dart';
import 'package:forja/features/live_matches/streams/data/live_iptv_sports_config.dart';
import 'package:forja/features/live_matches/streams/play/live_engine.dart';
import 'package:forja/features/live_matches/streams/play/live_play_kit.dart';
import 'package:forja/shared/catalog/kit/play/catalog_live_play.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/shared/navigation/media_details_back_button.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_hero.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:rust/rust.dart';

// Live Sports streams panel host (RFC-073). Full browse UI deleted — kit owns
// the tab list; this page is panelOnly streams chrome + play.

part 'data/live_meta.dart';
part 'services/iptv_sports_match.dart';
part 'data/live_catalog_loader.dart';
part 'chrome/live_chrome_widgets.dart';
part 'chrome/live_top_bar_controller.dart';
part 'body/live_match_grid.dart';
part 'play/live_play_dispatch.dart';
part 'play/live_streams_panel.dart';
part 'providers/live_schedule_provider.dart';

/// Streams panel host for Live Sports (`nav.tabId: live_matches`).
///
/// Full god browse was deleted. Kit browse ([LiveSportsBrowseShell]) owns the
/// match list; this widget mounts only the Providers / Live TV panel.
class LiveSportsHubPage extends ConsumerStatefulWidget {
  const LiveSportsHubPage({
    super.key,
    this.layoutWidgets = const [],
    this.parentShellVisible = true,
    this.refreshEpoch = 0,
    this.panelOnly = true,
    this.kitPanelRow,
    this.onPanelClosed,
  });

  static const tabId = 'live_matches';

  /// Pack `layout` tree (`kit.list` + `source: live_schedule`).
  final List<Map<String, dynamic>> layoutWidgets;

  /// CatalogShell tab visibility — hub [ShellTabRefresh] is nested, not keyed.
  final bool parentShellVisible;

  /// Bumped by CatalogShell [onShellTabRefresh].
  final int refreshEpoch;

  /// Always true for current call sites — kit list owns browse.
  final bool panelOnly;

  /// Opaque schedule row from [CatalogKitListEntry.legacyRow] for [panelOnly].
  final Map<String, dynamic>? kitPanelRow;

  /// Kit browse clears selection when the panel Close is pressed.
  final VoidCallback? onPanelClosed;

  @override
  ConsumerState<LiveSportsHubPage> createState() => _LiveSportsHubPageState();
}

class _LiveSportsHubPageState extends ConsumerState<LiveSportsHubPage>
    with
        TickerProviderStateMixin,
        ShellTabRefresh<LiveSportsHubPage>,
        _LiveMatchesData,
        _LiveMatchesForjaLive,
        _LiveMatchesBuild,
        _LiveMatchesPlayback
    implements _LiveSportsPlayHost {
  static const _tabId = LiveSportsTvRows.tabId;
  static const _gridRowId = LiveSportsTvRows.grid;
  static const _streamsTabsRowId = LiveSportsTvRows.streamsTabs;
  static const _streamsChromeRowId = LiveSportsTvRows.streamsChrome;
  static const _streamsListRowId = LiveSportsTvRows.streamsList;
  static const _streamsCatsRowId = LiveSportsTvRows.streamsCats;
  static const _streamsTabsSort = 10;
  static const _streamsChromeSort = 11;
  static const _streamsCatsSort = 12;
  static const _streamsListSort = 13;

  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  String _sportFilter = 'all';

  static const _forjaLiveCatalogFilterPreferenceKey =
      LivePrefs.catalogFilterKey;
  static const _schedulePreferenceKey = LivePrefs.scheduleKey;
  static const _timeWindowPreferenceKeyLegacy = LivePrefs.timeWindowLegacyKey;

  TabController? _tabController;
  bool _iptvSportsEnabled = false;
  bool _mergeMatchingEvents = false;

  /// Browse catalog hydrate gate — panel-only host never loads browse schedule.
  final bool _browseHydrated = false;
  List<_IframeCatalogStream> _iframeCatalogStreams = [];
  List<_StreamedMatch> _streamedMatches = [];

  final Map<String, int> _eventStreamViewerTotals = {};

  List<Map<String, dynamic>> _espnGames = [];
  String? _lastSyncedIptvPortalKey;
  int _forjaLiveLoadGen = 0;
  int _iptvSportsPlayGen = 0;
  String _forjaLivePluginFilter = 'all';
  Map<String, _ForjaLivePluginLoad> _forjaLivePluginLoads = {};
  bool _forjaLiveCatalogHydrating = false;
  bool _forjaLiveCatalogMerging = false;
  Future<void>? _forjaLiveGridCatalogInflight;
  int _forjaLiveGridCatalogInflightSerial = 0;

  _LiveMatchesScheduleStatus _scheduleStatus = _LiveMatchesScheduleStatus.both;
  _LiveMatchesScheduleHorizon _scheduleHorizon = _LiveMatchesScheduleHorizon.h1;
  _LiveMatchesScheduleHorizon _catalogFetchedHorizon =
      _LiveMatchesScheduleHorizon.h1;
  bool _forjaLiveCatalogSettingsDirty = false;

  _StreamedMatch? _streamsPanelMatch;
  _IframeCatalogStream? _streamsPanelIframeAnchor;

  @override
  void openMatchStreamsPanel({
    required _StreamedMatch match,
    _IframeCatalogStream? iframeCatalogAnchor,
  }) {
    if (!mounted) return;
    setState(() {
      _streamsPanelMatch = match;
      _streamsPanelIframeAnchor = iframeCatalogAnchor;
    });
  }

  @override
  void closeMatchStreamsPanel() {
    if (!mounted || _streamsPanelMatch == null) return;
    setState(() {
      _streamsPanelMatch = null;
      _streamsPanelIframeAnchor = null;
    });
    widget.onPanelClosed?.call();
  }

  bool get _showCatalogTopBar =>
      !kLiveMatchesCatalogFiltersHidden && _forjaLivePluginLoads.isNotEmpty;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (_error != null || _sports.isEmpty || force) {
      await _load();
      return;
    }
    if ((this as _LiveMatchesForjaLive)._usesForjaLiveLazyCatalog &&
        _forjaLiveCatalogSettingsDirty) {
      _forjaLiveCatalogSettingsDirty = false;
      (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
        reloadNow: true,
      );
    }
  }

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _releaseLiveMatchesItemFocusIfHeld();
    EngineService.instance.cancelLiveCatalog();
    _IptvSportsChannelsPanel.dismiss();
    _loadGen++;
    _forjaLiveLoadGen++;
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    unawaited(_refreshCapabilityFlags(reload: true));
    if (_error != null || (_sports.isEmpty && !_loading)) {
      unawaited(_load());
    } else if (_forjaLiveCatalogSettingsDirty) {
      _forjaLiveCatalogSettingsDirty = false;
      (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
        reloadNow: true,
      );
    } else if ((this as _LiveMatchesForjaLive)._gridCatalogNeedsHydration()) {
      final forja = this as _LiveMatchesForjaLive;
      final stuckEmpty = _forjaLiveCatalogHydrating &&
          _forjaLivePluginLoads.isEmpty &&
          _forjaLiveGridCatalogInflight == null;
      if (stuckEmpty ||
          (!_forjaLiveCatalogHydrating && !forja._forjaLiveAnyLoading)) {
        forja._kickForjaLiveLazyCatalog(replace: stuckEmpty);
      }
    }
    unawaited(_consumePendingLivePlayOpen());
  }

  Future<void> _consumePendingLivePlayOpen() async {
    final id = LivePlayKit.takePendingOpenMatchId();
    if (id == null || id.isEmpty || !mounted) return;
    _StreamedMatch? match;
    for (final m in _streamedMatches) {
      if (m.id == id || m.id.endsWith(':$id')) {
        match = m;
        break;
      }
    }
    if (match == null || !match.isLive) return;
    await (this as _LiveMatchesPlayback)._openStreamedMatch(match);
  }

  @override
  void initState() {
    super.initState();
    EngineService.changeNotifier.addListener(_onEnginePackChanged);
    SettingsService.addonChangeNotifier.addListener(_onStremioAddonsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.panelOnly) {
      _openKitPanelFromRow();
      unawaited(_refreshCapabilityFlags(reload: false));
      return;
    }
  }

  @override
  bool get shellTabVisible =>
      widget.parentShellVisible && super.shellTabVisible;

  @override
  void didUpdateWidget(LiveSportsHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panelOnly) {
      if (oldWidget.kitPanelRow != widget.kitPanelRow) {
        _openKitPanelFromRow();
      }
      return;
    }
    if (oldWidget.parentShellVisible && !widget.parentShellVisible) {
      onShellTabHidden();
    } else if (!oldWidget.parentShellVisible && widget.parentShellVisible) {
      onShellTabShown();
    }
    if (oldWidget.refreshEpoch != widget.refreshEpoch &&
        widget.parentShellVisible) {
      unawaited(onShellTabRefresh(force: true));
    }
  }

  void _openKitPanelFromRow() {
    final row = widget.kitPanelRow;
    if (row == null || row.isEmpty) return;
    final normalized = _normalizeKitPanelRow(row);
    final id = (normalized['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (_streamsPanelMatch?.id == id) return;
    final match = _forjaLiveRowToMatch(normalized);
    openMatchStreamsPanel(match: match);
  }

  Map<String, dynamic> _normalizeKitPanelRow(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    final title = (out['title'] ?? out['name'] ?? out['event'] ?? '')
        .toString()
        .trim();
    if (title.isNotEmpty) out['title'] = title;
    if ((out['category'] ?? '').toString().trim().isEmpty) {
      final genres = out['genres'];
      if (genres is List && genres.isNotEmpty) {
        out['category'] = genres.first.toString();
      } else if ((out['badge'] ?? '').toString().trim().isNotEmpty) {
        out['category'] = out['badge'].toString();
      }
    }
    out['airing'] = out['airing'] == true ||
        out['live'] == true ||
        (out['status'] ?? '').toString().toLowerCase() == 'live';
    if ((out['catalog'] ?? '').toString().isEmpty) {
      out['catalog'] = 'forja_live';
    }
    final plugin = (out['livePluginId'] ?? out['pluginId'] ?? '').toString();
    if (plugin.isNotEmpty) out['livePluginId'] = plugin;
    if (out['date'] == null) {
      final starts = (out['starts_at'] ?? out['startsAt'] ?? '').toString();
      final asInt = int.tryParse(starts);
      if (asInt != null) {
        out['date'] = asInt > 20000000000 ? asInt : asInt * 1000;
      } else {
        final dt = DateTime.tryParse(starts);
        if (dt != null) out['date'] = dt.millisecondsSinceEpoch;
      }
    }
    return out;
  }

  void _onEnginePackChanged() {
    if (!mounted) return;
    if (!_usesForjaLiveLazyCatalog) {
      return;
    }
    (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
      reloadNow: (this as ShellTabRefresh<LiveSportsHubPage>).shellTabVisible,
    );
  }

  void _onStremioAddonsChanged() {
    if (!mounted) return;
    _clearProvidersResultsCache();
    unawaited(_refreshCapabilityFlags(reload: false));
    final forja = this as _LiveMatchesForjaLive;
    if (!forja._usesForjaLiveLazyCatalog) return;
    unawaited(() async {
      await forja._ensureStremioCatalogLoadsRegistered();
      if (!mounted) return;
      final filter = forja._activeForjaLiveCatalogFilter;
      if (filter == 'all' || _isStremioCatalogFilter(filter)) {
        forja._kickForjaLiveLazyCatalog(replace: true);
      }
    }());
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEnginePackChanged);
    SettingsService.addonChangeNotifier.removeListener(_onStremioAddonsChanged);
    _IptvSportsChannelsPanel.dismiss();
    ShellTvFocusCoordinator.clearTab(_tabId);
    _tabController?.dispose();
    super.dispose();
  }

  Future<
      ({
        bool forjaLiveEnabled,
        bool iptvSportsEnabled,
        bool stremioLiveEnabled,
      })> _refreshCapabilityFlags({required bool reload}) async {
    final config = await LiveMatchesIptvSportsConfig.load();
    final forjaLiveEnabled = config.forjaLiveEnabled;
    final iptvSportsEnabled = config.enabled;
    final mergeMatching = config.mergeMatchingEvents;
    final stremioLiveEnabled = await _liveMatchesStremioLiveEnabled();
    if (!mounted) {
      return (
        forjaLiveEnabled: forjaLiveEnabled,
        iptvSportsEnabled: iptvSportsEnabled,
        stremioLiveEnabled: stremioLiveEnabled,
      );
    }
    final mergeChanged = _mergeMatchingEvents != mergeMatching;
    final iptvChanged = _iptvSportsEnabled != iptvSportsEnabled;
    if (mergeChanged || iptvChanged) {
      setState(() {
        _iptvSportsEnabled = iptvSportsEnabled;
        _mergeMatchingEvents = mergeMatching;
        if (mergeChanged) {
          (this as _LiveMatchesForjaLive)._invalidateLiveMatchesGridCache();
        }
      });
      if (reload && iptvChanged) await _load();
    }
    return (
      forjaLiveEnabled: forjaLiveEnabled,
      iptvSportsEnabled: iptvSportsEnabled,
      stremioLiveEnabled: stremioLiveEnabled,
    );
  }
}
