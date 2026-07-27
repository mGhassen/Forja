import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/extractors/core/stream_extractor.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/webview/forja_webview.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/live_matches/live_embed_nav.dart';
import 'package:forja/features/live_matches/live_matches_sport_filter.dart';
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
        _LiveMatchesBuild,
        _LiveMatchesTimeline,
        _LiveMatchesPlayback {
  static const _tabId = 'live_matches';
  static const _topBarRowId = 'live-top-bar';
  static const _chipRowId = 'sport-chips';
  static const _gridRowId = 'grid';
  static const _granularityRowId = 'timeline-granularity';
  static const _cdnModeRowId = 'cdn-mode';

  // tabs: All + each sport
  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;
  int _loadGen = 0;

  // selected sport filter ('all' = no filter)
  String _sportFilter = 'all';

  // Body layout: card grid or vertical timeline.
  static const _viewPreferenceKey = 'live_matches_timeline_view';
  _LiveMatchesView _view = _LiveMatchesView.timeline;
  bool _viewWasToggled = false;
  _TimelineGranularity _timelineGranularity = _TimelineGranularity.h3;
  final ScrollController _timelineScrollController = ScrollController();
  bool _timelineAutoScrolled = false;

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
  _LiveMatchesServer _server = _LiveMatchesServer.all;
  List<_DamiTvStream> _damiTvStreams = [];
  List<_StreamedMatch> _streamedMatches = [];
  List<_CdnChannel> _cdnChannels = [];
  List<_CdnSportEvent> _cdnSports = [];
  bool _cdnShowChannels = true; // true = channels, false = sports

  static const _topBarServersIndex = 0;
  static const _topBarRefreshIndex = 1;
  static const _topBarViewIndex = 2;

  final FocusNode _refreshFocusNode = FocusNode(
    debugLabel: 'live-matches-refresh',
  );
  final FocusNode _viewFocusNode = FocusNode(
    debugLabel: 'live-matches-view-toggle',
  );

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
    _loadGen++;
    _timelineLiveTick?.cancel();
    _timelineLiveTick = null;
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    _syncTimelineLiveTick();
    if (_error != null || (_sports.isEmpty && !_loading)) {
      unawaited(_load());
    }
  }

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      _tabId,
      enterFromNavFocus: () {
        _restoreLiveMatchesTvFocus();
      },
      restoreFocus: _restoreLiveMatchesTvFocus,
    );
    _syncTimelineLiveTick();
    unawaited(_restoreViewPreference());
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Android TV / leanback: cards only - no timeline canvas (mirrors IPTV).
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips &&
        _view != _LiveMatchesView.grid) {
      _view = _LiveMatchesView.grid;
      _timelineAutoScrolled = false;
      _timelineHoveredBucketMs = null;
      _timelineHoveredIndex = null;
      _syncTimelineLiveTick();
    }
  }

  @override
  void dispose() {
    _timelineLiveTick?.cancel();
    _refreshFocusNode.dispose();
    _viewFocusNode.dispose();
    _timelineScrollController.dispose();
    ShellTvFocusCoordinator.unregisterTabDefaults(_tabId);
    ShellTvFocusCoordinator.clearTab(_tabId);
    _tabController?.dispose();
    super.dispose();
  }

  void _syncTimelineLiveTick() {
    final need = shellTabVisible && _view == _LiveMatchesView.timeline;
    if (need) {
      _timelineLiveTick ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted || !shellTabVisible || _view != _LiveMatchesView.timeline) {
          return;
        }
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
    // TV never restores timeline - cards-only surface.
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
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

  void _toggleView() {
    if (!mounted) return;
    if (ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
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
