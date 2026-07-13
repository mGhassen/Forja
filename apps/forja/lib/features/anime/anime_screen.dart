// Anime hub — cinematic hero + poster rows (same shell as Home).

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_cinematic_hero.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'anime_details_screen.dart';
import 'anime_player_screen.dart';
import 'anime_search_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/widgets/shell_card_play_overlay.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

part 'anime_screen_feed.dart';
part 'anime_screen_build.dart';
part 'anime_widgets.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, ShellTabRefresh<AnimeScreen>, _AnimeScreenFeed, _AnimeScreenBuild {
  final AnimeService _service = AnimeService();
  final ScrollController _cwScrollController = ScrollController();
  final ScrollController _scroll = ScrollController();

  // Section futures
  Future<List<AnimeCard>>? _spotlightFuture;
  Future<List<AnimeCard>>? _trendingFuture;
  Future<List<AnimeCard>>? _topAiringFuture;
  Future<List<AnimeCard>>? _mostPopularFuture;
  Future<List<AnimeCard>>? _mostFavoriteFuture;
  Future<List<AnimeCard>>? _topRatedFuture;
  Future<List<AnimeCard>>? _latestCompletedFuture;
  Future<List<AnimeCard>>? _top10Future;
  Future<List<AnimeCard>>? _recentEpisodesFuture;
  Future<List<Map<String, dynamic>>>? _historyFuture;

  bool _catalogResolved = false;
  String? _error;

  // Continue watching
  List<Map<String, dynamic>> _continueWatching = [];
  int? _resumingAnimeId;


  // Mood / genre filter
  String _selectedMood = 'shonen';
  Future<List<AnimeCard>>? _moodFuture;

  static const List<({String id, String label, IconData icon, String? genre})>
      _moods = [
    (id: 'shonen',    label: 'Shōnen',       icon: Icons.local_fire_department_rounded, genre: 'Action'),
    (id: 'romance',   label: 'Romance',      icon: Icons.favorite_rounded,              genre: 'Romance'),
    (id: 'comedy',    label: 'Comedy',       icon: Icons.sentiment_very_satisfied_rounded, genre: 'Comedy'),
    (id: 'mystery',   label: 'Mystery',      icon: Icons.psychology_rounded,            genre: 'Mystery'),
    (id: 'thriller',  label: 'Thriller',     icon: Icons.dark_mode_rounded,             genre: 'Thriller'),
    (id: 'fantasy',   label: 'Fantasy',      icon: Icons.auto_awesome_rounded,          genre: 'Fantasy'),
    (id: 'sliceLife', label: 'Slice of Life',icon: Icons.wb_sunny_rounded,              genre: 'Slice of Life'),
    (id: 'scifi',     label: 'Sci-Fi',       icon: Icons.rocket_launch_rounded,         genre: 'Sci-Fi'),
    (id: 'sports',    label: 'Sports',       icon: Icons.sports_baseball_rounded,       genre: 'Sports'),
    (id: 'horror',    label: 'Horror',       icon: Icons.bedtime_rounded,               genre: 'Horror'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ShellTvFocusCoordinator.registerTabDefaults(
      'anime',
      defaultFocus: () => ShellTvFocus.homeHeroPlay,
      heroReveal: () {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    AnimeService.watchHistoryRevision.addListener(_onHistoryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('anime');
    WidgetsBinding.instance.removeObserver(this);
    AppTheme.themeNotifier.removeListener(_onTheme);
    AnimeService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _cwScrollController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHistory();
    }
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) async {
    if (_error != null || !_catalogResolved || force) {
      await _load();
    }
  }

}
