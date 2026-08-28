import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/desktop_window_geometry.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/engine/live_goat_webview_unlock.dart';
import 'package:forja/features/live_matches/live_matches_sport_filter.dart';
import 'package:forja/features/live_matches/live_matches_team_parse.dart';
import 'package:forja/features/live_matches/live_matches_iptv_sports_settings.dart';
import 'package:forja/features/live_matches/live_matches_engine.dart';
import 'package:forja/features/live_matches/live_embed_nav.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/features/live_matches/live_embed_webview_proxy.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/providers/iptv_controller_provider.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_catalog_workspace.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_portals_top_bar_button.dart';
import 'package:rust/rust.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

part 'live_matches_models.dart';
part 'live_matches_widgets.dart';
part 'live_matches_data.dart';
part 'live_matches_build.dart';
part 'live_matches_timeline.dart';
part 'live_matches_playback.dart';
part 'live_matches_forja_live.dart';
part 'providers/live_matches_providers.dart';

class LiveMatchesScreen extends ConsumerStatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  ConsumerState<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends ConsumerState<LiveMatchesScreen>
    with
        TickerProviderStateMixin,
        ShellTabRefresh<LiveMatchesScreen>,
        _LiveMatchesData,
        _LiveMatchesForjaLive,
        _LiveMatchesBuild,
        _LiveMatchesTimeline,
        _LiveMatchesPlayback {
  static const _tabId = 'live_matches';
  static const _topBarRowId = 'live-top-bar';
  static const _chipRowId = 'sport-chips';
  static const _gridRowId = 'grid';
  static const _granularityRowId = 'timeline-granularity';
  // tabs: All + each sport
  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  // selected sport filter ('all' = no filter)
  String _sportFilter = 'all';

  // Body layout: card grid or vertical timeline.
  static const _viewPreferenceKey = 'live_matches_timeline_view';
  static const _serverPreferenceKey = 'live_matches_server_v1';
  static const _forjaLiveCatalogFilterPreferenceKey =
      'live_matches_forja_catalog_filter_v1';
  static const _schedulePreferenceKey = 'live_matches_schedule_v2';
  /// Legacy single-axis pref — migrated once into [_schedulePreferenceKey].
  static const _timeWindowPreferenceKeyLegacy = 'live_matches_time_window_v1';
  _LiveMatchesView _view = _LiveMatchesView.timeline;
  bool _viewWasToggled = false;
  _TimelineGranularity _timelineGranularity = _TimelineGranularity.h3;
  final ScrollController _timelineScrollController = ScrollController();
  bool _timelineAutoScrolled = false;

  /// Timeline bucket rows show at most [_timelineBucketCardCap] cards until expanded.
  static const int _timelineBucketCardCap = 20;
  final Map<int, bool> _timelineBucketExpanded = {};

  /// Rebuilds the timeline each minute so airing Misc/Other cards stay on NOW.
  Timer? _timelineLiveTick;

  /// The single hovered timeline card (bucket + index) lifted above neighbors.
  int? _timelineHoveredBucketMs;
  int? _timelineHoveredIndex;

  /// Stable transform links per timeline card so the elevated hover copy can
  /// track the real card's on-screen position (`bucketMs:index`).
  final Map<String, LayerLink> _timelineCardLinks = {};

  /// Registered TV row ids for timeline hour buckets (`tl-<bucketMs>`).
  final Set<String> _timelineTvRowIds = {};

  TabController? _tabController;
  _LiveMatchesServer _server = _LiveMatchesServer.forjaLive;

  /// False until [_restoreServerPreference] finishes — avoids fetching before saved server applies.
  bool _serverHydrated = false;
  List<_DamiTvStream> _damiTvStreams = [];
  List<_StreamedMatch> _streamedMatches = [];

  /// ESPN scoreboard payloads for My IPTV (enrich on play).
  List<Map<String, dynamic>> _espnGames = [];
  String? _lastSyncedIptvPortalKey;
  int _forjaLiveLoadGen = 0;
  int _iptvSportsPlayGen = 0;
  int _iptvSportsSearchGen = 0;
  String _forjaLivePluginFilter = 'all';
  Map<String, _ForjaLivePluginLoad> _forjaLivePluginLoads = {};
  _LiveMatchesScheduleStatus _scheduleStatus = _LiveMatchesScheduleStatus.both;
  _LiveMatchesScheduleHorizon _scheduleHorizon = _LiveMatchesScheduleHorizon.h1;

  /// Widest horizon already ingested this session (refetch when user widens).
  _LiveMatchesScheduleHorizon _catalogFetchedHorizon =
      _LiveMatchesScheduleHorizon.h1;

  /// Settings → Forja Sports **Catalog** toggles changed while this tab was hidden.
  bool _forjaLiveCatalogSettingsDirty = false;

  /// Prevent stacking Servers / Catalog / Time bottom sheets on double-tap.
  bool _topBarSheetOpen = false;

  static const _topBarServersIndex = 0;

  bool get _showIptvPortalTopBar => _server == _LiveMatchesServer.iptvSports;

  /// Catalog + schedule window on Forja Live / Sports / All.
  bool get _showCatalogTopBar =>
      (_server == _LiveMatchesServer.all ||
          _server == _LiveMatchesServer.forjaLive ||
          _server == _LiveMatchesServer.iptvSports) &&
      _forjaLivePluginLoads.isNotEmpty;

  bool get _showTimeTopBar =>
      _server == _LiveMatchesServer.all ||
      _server == _LiveMatchesServer.forjaLive ||
      _server == _LiveMatchesServer.iptvSports;

  int get _topBarCatalogIndex => 1;

  int get _topBarTimeIndex {
    var index = 1;
    if (_showCatalogTopBar) index++;
    return index;
  }

  /// Servers → [Catalog] → [Time] → Refresh → [Portals] → [View].
  int get _topBarRefreshIndex {
    var index = 1;
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

  /// TV: keep D-pad on top-bar Refresh across catalog reload remounts.
  bool _restoreRefreshFocus = false;

  /// Gate first catalog fetch — `ref` is unsafe in [initState].
  bool _didInitialLoad = false;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleDefault;

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (_error != null || _sports.isEmpty || force) {
      await _load();
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
    unawaited(_clampServerIfForjaSportsDisabled(reload: true));
    _syncTimelineLiveTick();
    if (_error != null || (_sports.isEmpty && !_loading)) {
      unawaited(_load());
    } else if (_forjaLiveCatalogSettingsDirty &&
        (_server == _LiveMatchesServer.all ||
            _server == _LiveMatchesServer.forjaLive ||
            _server == _LiveMatchesServer.iptvSports)) {
      _forjaLiveCatalogSettingsDirty = false;
      (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
        reloadNow: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    EngineService.changeNotifier.addListener(_onEnginePackChanged);
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
    if (_liveMatchesLeanbackOnly(context) && _view != _LiveMatchesView.grid) {
      _view = _LiveMatchesView.grid;
      _timelineAutoScrolled = false;
      _timelineHoveredBucketMs = null;
      _timelineHoveredIndex = null;
      _syncTimelineLiveTick();
    }
  }

  void _onEnginePackChanged() {
    if (!mounted) return;
    if (_server != _LiveMatchesServer.all &&
        _server != _LiveMatchesServer.forjaLive) {
      return;
    }
    (this as _LiveMatchesForjaLive)._applyEngineCatalogSettingsChange(
      reloadNow: (this as ShellTabRefresh<LiveMatchesScreen>).shellTabVisible,
    );
  }

  @override
  void dispose() {
    EngineService.changeNotifier.removeListener(_onEnginePackChanged);
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
    _timelineAutoScrolled = false;
    _timelineHoveredBucketMs = null;
    _timelineHoveredIndex = null;
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
    // Leanback TV never restores timeline - cards-only surface.
    if (_liveMatchesLeanbackOnly(context)) {
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
        // Landing on timeline from a restored preference must scroll to now.
        if (savedView == _LiveMatchesView.timeline) {
          _timelineAutoScrolled = false;
        }
      });
      _syncTimelineLiveTick();
    }
  }

  /// Loads Forja Sports / Stremio availability and clamps [_server] if needed.
  Future<({bool iptvSportsEnabled, bool stremioLiveEnabled})>
  _clampServerIfForjaSportsDisabled({required bool reload}) async {
    final iptvSportsEnabled =
        (await LiveMatchesIptvSportsConfig.load()).enabled;
    final stremioLiveEnabled = await _liveMatchesStremioLiveEnabled();
    if (!mounted) {
      return (
        iptvSportsEnabled: iptvSportsEnabled,
        stremioLiveEnabled: stremioLiveEnabled,
      );
    }
    final next = _liveMatchesClampServerForSurface(
      _server,
      iptvSportsEnabled: iptvSportsEnabled,
      stremioLiveEnabled: stremioLiveEnabled,
    );
    if (next != _server) {
      if (_server == _LiveMatchesServer.iptvSports) {
        ref.read(iptvControllerProvider).closePortalPanel();
      }
      setState(() => _server = next);
      unawaited(_persistServerPreference(next));
      if (reload) await _load();
    }
    return (
      iptvSportsEnabled: iptvSportsEnabled,
      stremioLiveEnabled: stremioLiveEnabled,
    );
  }

  Future<void> _restoreServerThenLoad() async {
    await _restoreServerPreference();
    await (this as _LiveMatchesForjaLive)
        ._restoreForjaLiveCatalogFilterPreference();
    await (this as _LiveMatchesForjaLive)._restoreTimeWindowPreference();
    if (!mounted) return;
    setState(() => _serverHydrated = true);
    if (_server == _LiveMatchesServer.iptvSports) {
      final ctrl = ref.read(iptvControllerProvider);
      await ctrl.preparePortalPanel();
      await _syncMyIptvFromActivePortal(ctrl, reload: false);
      if (!mounted) return;
    }
    await _load();
  }

  Future<void> _restoreServerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final iptvSportsEnabled =
        (await LiveMatchesIptvSportsConfig.load()).enabled;
    final stremioLiveEnabled = await _liveMatchesStremioLiveEnabled();
    if (!mounted) return;
    final raw = prefs.getString(_serverPreferenceKey);
    _LiveMatchesServer? saved;
    if (raw != null) {
      for (final server in _LiveMatchesServer.values) {
        if (server.name == raw) {
          saved = server;
          break;
        }
      }
    }
    final next = _liveMatchesClampServerForSurface(
      saved ?? _server,
      iptvSportsEnabled: iptvSportsEnabled,
      stremioLiveEnabled: stremioLiveEnabled,
    );
    // Clamp invalid saved server (hidden All/PPV/Streamed/Mut/Stremio, disabled Forja Sports, …).
    if (saved != null && saved != next) {
      unawaited(_persistServerPreference(next));
    }
    if (next == _server) return;
    setState(() => _server = next);
  }

  Future<void> _persistServerPreference(_LiveMatchesServer server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverPreferenceKey, server.name);
  }

  void _toggleView() {
    if (!mounted) return;
    if (_liveMatchesLeanbackOnly(context)) return;
    _viewWasToggled = true;
    setState(() {
      _view = _view == _LiveMatchesView.grid
          ? _LiveMatchesView.timeline
          : _LiveMatchesView.grid;
      _timelineAutoScrolled = false;
      _timelineHoveredBucketMs = null;
      _timelineHoveredIndex = null;
    });
    _syncTimelineLiveTick();
    unawaited(_persistViewPreference(_view == _LiveMatchesView.timeline));
  }

  Future<void> _persistViewPreference(bool showTimeline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewPreferenceKey, showTimeline);
  }
}
