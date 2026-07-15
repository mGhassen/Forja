import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
import 'package:rust/rust.dart';


// ═════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════

part 'live_matches_models.dart';
part 'live_matches_widgets.dart';
part 'live_matches_data.dart';
part 'live_matches_build.dart';
part 'live_matches_playback.dart';

class LiveMatchesScreen extends StatefulWidget {
  const LiveMatchesScreen({super.key});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen>
    with TickerProviderStateMixin, _LiveMatchesData, _LiveMatchesBuild, _LiveMatchesPlayback {
  static const _tabId = 'live_matches';
  static const _topBarRowId = 'live-top-bar';
  static const _chipRowId = 'sport-chips';
  static const _gridRowId = 'grid';

  // tabs: All + each sport
  List<_Sport> _sports = [];
  bool _loading = true;
  String? _error;

  // selected sport filter ('all' = no filter)
  String _sportFilter = 'all';

  TabController? _tabController;
  _LiveMatchesServer _server = _LiveMatchesServer.all;
  List<_DamiTvStream> _damiTvStreams = [];
  List<_StreamedMatch> _streamedMatches = [];
  List<_CdnChannel> _cdnChannels = [];
  List<_CdnSportEvent> _cdnSports = [];
  bool _cdnShowChannels = true; // true = channels, false = sports

  static const _topBarServersIndex = 0;
  static const _topBarRefreshIndex = 1;

  final FocusNode _refreshFocusNode = FocusNode(
    debugLabel: 'live-matches-refresh',
  );


  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      _tabId,
      restoreFocus: _restoreLiveMatchesTvFocus,
    );
    _load();
  }

  @override
  void dispose() {
    _refreshFocusNode.dispose();
    ShellTvFocusCoordinator.clearTab(_tabId);
    _tabController?.dispose();
    super.dispose();
  }

}


