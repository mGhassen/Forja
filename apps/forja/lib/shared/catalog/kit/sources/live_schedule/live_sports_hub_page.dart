import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/features/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_types.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_prefs.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_sport_filter.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_stremio_meta.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_team_parse.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/data/live_iptv_sports_config.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/play/live_engine.dart';
import 'package:forja/shared/catalog/kit/sources/live_schedule/play/live_play_kit.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/screens/iptv_portals_top_bar_button.dart';
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

// Live Sports hub page (RFC-071) — host-owned kit body for the live_sports pack.

part 'data/live_meta.dart';
part 'services/iptv_sports_match.dart';
part 'data/live_catalog_loader.dart';
part 'chrome/live_chrome_widgets.dart';
part 'chrome/live_top_bar_controller.dart';
part 'body/live_match_grid.dart';
part 'play/live_play_dispatch.dart';
part 'play/live_details_screen.dart';
part 'providers/live_schedule_provider.dart';

/// Catalog hub page for Live Sports (`nav.tabId: live_matches`).
class LiveSportsHubPage extends ConsumerStatefulWidget {
  const LiveSportsHubPage({
    super.key,
    this.layoutWidgets = const [],
    this.parentShellVisible = true,
    this.refreshEpoch = 0,
  });

  /// Pack `layout` tree (`kit.list` + `source: live_schedule`). Unused for
  /// chrome — host owns browse UI; kept for shell/mount identity.
  final List<Map<String, dynamic>> layoutWidgets;

  /// CatalogShell tab visibility — hub [ShellTabRefresh] is nested, not keyed.
  final bool parentShellVisible;

  /// Bumped by CatalogShell [onShellTabRefresh].
  final int refreshEpoch;

  @override
  ConsumerState<LiveSportsHubPage> createState() => LiveSportsHubPageState();
}

class LiveSportsHubPageState extends ConsumerState<LiveSportsHubPage>
    with
        TickerProviderStateMixin,
        ShellTabRefresh<LiveSportsHubPage>,
        _LiveMatchesData,
        _LiveMatchesForjaLive,
        _LiveMatchesBuild,
        _LiveMatchesPlayback
    implements _LiveSportsPlayHost {
  static const tabId = 'live_matches';
  static const _tabId = tabId;
  static const _topBarRowId = 'live-top-bar';
  static const _chipRowId = 'sport-chips';
  static const _gridRowId = 'grid';
  /// Side streams panel (Providers / Live TV) — same TvFocusGraph as browse.
  static const _streamsTabsRowId = 'live-streams-tabs';
  static const _streamsChromeRowId = 'live-streams-chrome';
  static const _streamsListRowId = 'live-streams-list';
  static const _streamsCatsRowId = 'live-streams-cats';
  static const _streamsTabsSort = 10;
  static const _streamsChromeSort = 11;
  static const _streamsCatsSort = 12;
  static const _streamsListSort = 13;
  // tabs: All + each sport
  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  // selected sport filter ('all' = no filter)
  String _sportFilter = 'all';

  // Body layout: card grid or vertical timeline.
  static const _timelineViewEnabled = false; // timeline deleted (RFC-073)
  static const _viewPreferenceKey = LivePrefs.viewKey;
  static const _forjaLiveCatalogFilterPreferenceKey =
      LivePrefs.catalogFilterKey;
  static const _schedulePreferenceKey = LivePrefs.scheduleKey;
  /// Legacy single-axis pref — migrated once into [_schedulePreferenceKey].
  static const _timeWindowPreferenceKeyLegacy = LivePrefs.timeWindowLegacyKey;
  _LiveMatchesView _view = _timelineViewEnabled
      ? _LiveMatchesView.timeline
      : _LiveMatchesView.grid;
  bool _viewWasToggled = false;
  final ScrollController _timelineScrollController = ScrollController();

  final Map<int, bool> _timelineBucketExpanded = {};

  /// Rebuilds the timeline each minute so airing Misc/Other cards stay on NOW.
  Timer? _timelineLiveTick;

  /// Registered TV row ids for timeline hour buckets (`tl-<bucketMs>`).
  final Set<String> _timelineTvRowIds = {};

  TabController? _tabController;
  bool _iptvSportsEnabled = false;

  /// False until browse prefs hydrate — avoids fetching before catalog filter/horizon apply.
  bool _browseHydrated = false;
  List<_IframeCatalogStream> _iframeCatalogStreams = [];
  List<_StreamedMatch> _streamedMatches = [];

  /// After a stream picker resolves, card badge shows this total (all streams).
  final Map<String, int> _eventStreamViewerTotals = {};

  /// ESPN scoreboard payloads for My IPTV (enrich on play).
  List<Map<String, dynamic>> _espnGames = [];
  String? _lastSyncedIptvPortalKey;
  int _forjaLiveLoadGen = 0;
  int _iptvSportsPlayGen = 0;
  String _forjaLivePluginFilter = 'all';
  Map<String, _ForjaLivePluginLoad> _forjaLivePluginLoads = {};
  /// Lazy catalog scrape in flight (before plugin rows mark `loading`).
  bool _forjaLiveCatalogHydrating = false;

  /// Single-flight guard — duplicate kicks stacked engine catalog jobs.
  Future<void>? _forjaLiveGridCatalogInflight;
  int _forjaLiveGridCatalogInflightSerial = 0;

  int _liveMatchesGridCacheRevision = 0;
  int _liveMatchesGridEntriesCachedAtRevision = -1;
  List<_LiveMatchGridEntry>? _cachedLiveMatchesGridEntries;
  _LiveMatchesScheduleStatus _scheduleStatus = _LiveMatchesScheduleStatus.both;
  _LiveMatchesScheduleHorizon _scheduleHorizon = _LiveMatchesScheduleHorizon.h1;

  /// Widest horizon already ingested this session (refetch when user widens).
  _LiveMatchesScheduleHorizon _catalogFetchedHorizon =
      _LiveMatchesScheduleHorizon.h1;

  /// Settings → Forja Sports **Catalog** toggles changed while this tab was hidden.
  bool _forjaLiveCatalogSettingsDirty = false;


  /// Prevent stacking Catalog / Time bottom sheets on double-tap.
  bool _topBarSheetOpen = false;

  /// Selected match for the in-page streams panel (RFC-084 — no details route).
  _StreamedMatch? _streamsPanelMatch;
  _IframeCatalogStream? _streamsPanelIframeAnchor;

  /// Bumps when Providers cache must remount the open panel (addon install, etc.).
  int _streamsPanelReloadEpoch = 0;

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
  }

  /// Dense list when layout says so (host default); `style: grid` keeps cards.
  bool get useDenseMatchList {
    for (final w in widget.layoutWidgets) {
      final type = (w['type'] ?? '').toString();
      if (type != CatalogKitTypes.list && type != 'list') continue;
      final src = (w['source'] ?? CatalogKitListSources.liveSchedule).toString();
      if (src != CatalogKitListSources.liveSchedule) continue;
      final style = (w['style'] ?? 'list').toString().trim().toLowerCase();
      return style != 'grid' && style != 'cards';
    }
    return true;
  }

  int get _topBarCatalogIndex => 0;

  bool get _showIptvPortalTopBar => _iptvSportsEnabled;

  /// Catalog + schedule window on the live sports hub.
  bool get _showCatalogTopBar =>
      !kLiveMatchesCatalogFiltersHidden && _forjaLivePluginLoads.isNotEmpty;

  bool get _showTimeTopBar => _showCatalogTopBar;

  int get _topBarTimeIndex {
    var index = 0;
    if (_showCatalogTopBar) index++;
    return index;
  }

  /// [Catalog] → [Time] → Refresh → [Portals] → [View].
  int get _topBarRefreshIndex {
    var index = 0;
    if (_showCatalogTopBar) index++;
    if (_showTimeTopBar) index++;
    return index;
  }

  int get _topBarPortalIndex => _topBarRefreshIndex + 1;

  int get _topBarViewIndex =>
      _showIptvPortalTopBar ? _topBarPortalIndex + 1 : _topBarRefreshIndex + 1;

  final FocusNode _refreshFocusNode = FocusNode(
    debugLabel: 'live-matches-refresh',
  );
  final FocusNode _viewFocusNode = FocusNode(
    debugLabel: 'live-matches-view-toggle',
  );

  /// Legacy flag from top-bar Refresh restore — cleared on schedule restore.
  bool _restoreRefreshFocus = false;

  /// Gate first catalog fetch — `ref` is unsafe in [initState].
  bool _didInitialLoad = false;

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
    _restoreRefreshFocus = false;
    _releaseLiveMatchesItemFocusIfHeld();
    EngineService.instance.cancelLiveCatalog();
    _IptvSportsChannelsPanel.dismiss();
    _loadGen++;
    _forjaLiveLoadGen++;
    _timelineLiveTick?.cancel();
    _timelineLiveTick = null;
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    unawaited(_refreshCapabilityFlags(reload: true));
    _syncTimelineLiveTick();
    if (_error != null || (_sports.isEmpty && !_loading)) {
      unawaited(_load());
    } else if ((this as _LiveMatchesForjaLive)._gridCatalogNeedsHydration() &&
        !_forjaLiveCatalogHydrating &&
        !(this as _LiveMatchesForjaLive)._forjaLiveAnyLoading) {
      (this as _LiveMatchesForjaLive)._kickForjaLiveLazyCatalog();
    } else if (_forjaLiveCatalogSettingsDirty) {
      _forjaLiveCatalogSettingsDirty = false;
      (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
        reloadNow: true,
      );
    }
    unawaited(_consumePendingLivePlayOpen());
  }

  /// Cross-hub [LivePlayKit.openFromCatalogMeta] → open matching live fixture.
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
    TvHeroActions.bind(
      _tabId,
      enterFromNavFocus: () {
        _restoreLiveMatchesTvFocus();
      },
      restoreFocus: _restoreLiveMatchesTvFocus,
    );
    _syncTimelineLiveTick();
    unawaited(_restoreViewPreference());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ref.invalidate needs ProviderScope — never call from initState.
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      unawaited(_restoreServerThenLoad());
    }
    // Android TV / leanback: cards only - no timeline canvas (mirrors IPTV).
    if ((_liveMatchesLeanbackOnly(context) || !_timelineViewEnabled) &&
        _view != _LiveMatchesView.grid) {
      _view = _LiveMatchesView.grid;
      _syncTimelineLiveTick();
    }
  }

  @override
  bool get shellTabVisible =>
      widget.parentShellVisible && super.shellTabVisible;

  @override
  void didUpdateWidget(LiveSportsHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    // Schedule catalogs refresh below — but Providers TTL cache would still
    // serve the pre-addon channel list until Refresh/retry. Drop it now.
    _clearProvidersResultsCache();
    if (_streamsPanelMatch != null) {
      setState(() => _streamsPanelReloadEpoch++);
    }
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
    _timelineLiveTick?.cancel();
    _refreshFocusNode.dispose();
    _viewFocusNode.dispose();
    _timelineScrollController.dispose();
    TvHeroActions.unbind(_tabId);
    ShellTvFocusCoordinator.clearTab(_tabId);
    _tabController?.dispose();
    super.dispose();
  }

  void _resetTimelineLazyState() {
    _timelineBucketExpanded.clear();
  }

  void _syncTimelineLiveTick() {
    // Grid (including Android TV cards-only) also needs a minute tick so ● LIVE
    // badges flip when kickoff passes without a manual refresh.
    final need =
        shellTabVisible &&
        (_view == _LiveMatchesView.timeline || _view == _LiveMatchesView.grid);
    if (need) {
      _timelineLiveTick ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted || !shellTabVisible) return;
        setState(() {});
      });
    } else {
      _timelineLiveTick?.cancel();
      _timelineLiveTick = null;
    }
  }

  Future<void> _restoreViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _viewWasToggled) return;
    // Leanback TV / hidden timeline toggle: cards-only surface.
    if (_liveMatchesLeanbackOnly(context) || !_timelineViewEnabled) {
      if (_view != _LiveMatchesView.grid) {
        setState(() => _view = _LiveMatchesView.grid);
        _syncTimelineLiveTick();
      }
      return;
    }
    final showTimeline = prefs.getBool(_viewPreferenceKey);
    if (!mounted || showTimeline == null) return;

    final savedView = showTimeline
        ? _LiveMatchesView.timeline
        : _LiveMatchesView.grid;
    if (_view != savedView) {
      setState(() {
        _view = savedView;
      });
      _syncTimelineLiveTick();
    }
  }

  /// Refreshes Forja Sports / Stremio capability flags (not browse modes).
  Future<
      ({
        bool forjaLiveEnabled,
        bool iptvSportsEnabled,
        bool stremioLiveEnabled,
      })> _refreshCapabilityFlags({required bool reload}) async {
    final config = await LiveMatchesIptvSportsConfig.load();
    final forjaLiveEnabled = config.forjaLiveEnabled;
    final iptvSportsEnabled = config.enabled;
    final stremioLiveEnabled = await _liveMatchesStremioLiveEnabled();
    if (!mounted) {
      return (
        forjaLiveEnabled: forjaLiveEnabled,
        iptvSportsEnabled: iptvSportsEnabled,
        stremioLiveEnabled: stremioLiveEnabled,
      );
    }
    if (_iptvSportsEnabled != iptvSportsEnabled) {
      setState(() => _iptvSportsEnabled = iptvSportsEnabled);
      if (reload) await _load();
    }
    return (
      forjaLiveEnabled: forjaLiveEnabled,
      iptvSportsEnabled: iptvSportsEnabled,
      stremioLiveEnabled: stremioLiveEnabled,
    );
  }

  Future<void> _restoreServerThenLoad() async {
    await _restoreBrowsePrefs();
    await (this as _LiveMatchesForjaLive)
        ._restoreForjaLiveCatalogFilterPreference();
    await (this as _LiveMatchesForjaLive)._restoreTimeWindowPreference();
    if (!mounted) return;
    final iptvEnabled = (await LiveMatchesIptvSportsConfig.load()).enabled;
    if (!mounted) return;
    setState(() {
      _browseHydrated = true;
      _iptvSportsEnabled = iptvEnabled;
    });
    if (_iptvSportsEnabled) {
      final ctrl = ref.read(iptvControllerProvider);
      await ctrl.preparePortalPanel();
      await _syncMyIptvFromActivePortal(ctrl, reload: false);
      if (!mounted) return;
    }
    await _load();
  }

  Future<void> _restoreBrowsePrefs() async {
    final config = await LiveMatchesIptvSportsConfig.load();
    if (!mounted) return;
    setState(() => _iptvSportsEnabled = config.enabled);
    unawaited(LivePrefs.clearRetiredModePrefs());
  }

  void _toggleView() {
    if (!mounted) return;
    if (_liveMatchesLeanbackOnly(context)) return;
    _viewWasToggled = true;
    setState(() {
      _view = _view == _LiveMatchesView.grid
          ? _LiveMatchesView.timeline
          : _LiveMatchesView.grid;
    });
    _syncTimelineLiveTick();
    unawaited(_persistViewPreference(_view == _LiveMatchesView.timeline));
  }

  Future<void> _persistViewPreference(bool showTimeline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewPreferenceKey, showTimeline);
  }
}
