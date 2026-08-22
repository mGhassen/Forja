// Anime hub - cinematic hero + poster rows (same shell as Home).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/providers/anime_catalog_provider.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/widgets/hero/cinematic_hero.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/services/hub_list_follow.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/widgets/anime_continue_watching_section.dart';
import 'anime_details_screen.dart';
import 'anime_player_screen.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_error_retry_panel.dart';
import 'package:forja/shared/widgets/shell_mood_circle.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

part 'anime_screen_feed.dart';
part 'anime_screen_build.dart';

class AnimeScreen extends ConsumerStatefulWidget {
  const AnimeScreen({super.key});

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, ShellTabRefresh<AnimeScreen>, _AnimeScreenFeed, _AnimeScreenBuild {
  final AnimeService _service = AnimeService();
  final ScrollController _cwScrollController = ScrollController();
  final ScrollController _scroll = ScrollController();

  /// Cached so tab show/refresh can invalidate without inherited lookup
  /// on a deactivated [Visibility] child.
  ProviderContainer? _container;

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
  bool _catalogResolved = false;
  String? _error;
  int _loadGen = 0;

  // Continue watching
  List<Map<String, dynamic>> _continueWatching = [];
  bool _historyResolved = false;
  int? _resumingAnimeId;


  // Mood / genre filter
  String _selectedMood = 'shonen';
  Future<List<AnimeCard>>? _moodFuture;

  static const List<({
    String id,
    String label,
    IconData icon,
    Color accent,
    String? genre,
  })> _moods = [
    (
      id: 'shonen',
      label: 'Shōnen',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFF97316),
      genre: 'Action',
    ),
    (
      id: 'romance',
      label: 'Romance',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFEC4899),
      genre: 'Romance',
    ),
    (
      id: 'comedy',
      label: 'Comedy',
      icon: Icons.sentiment_very_satisfied_rounded,
      accent: Color(0xFFFBBF24),
      genre: 'Comedy',
    ),
    (
      id: 'mystery',
      label: 'Mystery',
      icon: Icons.psychology_rounded,
      accent: Color(0xFF8B5CF6),
      genre: 'Mystery',
    ),
    (
      id: 'thriller',
      label: 'Thriller',
      icon: Icons.dark_mode_rounded,
      accent: Color(0xFF64748B),
      genre: 'Thriller',
    ),
    (
      id: 'fantasy',
      label: 'Fantasy',
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFFA855F7),
      genre: 'Fantasy',
    ),
    (
      id: 'sliceLife',
      label: 'Slice of Life',
      icon: Icons.wb_sunny_rounded,
      accent: Color(0xFF34D399),
      genre: 'Slice of Life',
    ),
    (
      id: 'scifi',
      label: 'Sci-Fi',
      icon: Icons.rocket_launch_rounded,
      accent: Color(0xFF06B6D4),
      genre: 'Sci-Fi',
    ),
    (
      id: 'sports',
      label: 'Sports',
      icon: Icons.sports_baseball_rounded,
      accent: Color(0xFF22C55E),
      genre: 'Sports',
    ),
    (
      id: 'horror',
      label: 'Horror',
      icon: Icons.bedtime_rounded,
      accent: Color(0xFF7C3AED),
      genre: 'Horror',
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    TvHeroActions.bind(
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
      enterFromNavFocus: () {
        ShellTvFocusCoordinator.revealHeroForTab('anime');
        ShellTvFocus.focusHomeHeroPlay();
      },
    );
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    SettingsService.animeTitleLanguageNotifier.addListener(_onTheme);
    AnimeService.watchHistoryRevision.addListener(_onHistoryChanged);
    // Initial catalog load comes from ref.watch in build — do not invalidate
    // here (didChangeDependencies has not cached ProviderContainer yet).
    unawaited(_refreshHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  /// Last applied load bag — skip identical re-apply from build bridge.
  AnimeCatalogFutures? _appliedCatalog;

  void _applyCatalogFutures(AnimeCatalogFutures load) {
    if (identical(_appliedCatalog, load)) return;
    _appliedCatalog = load;
    final gen = _loadGen;
    final spotlight = load.spotlight;
    setState(() {
      _error = null;
      _catalogResolved = false;
      _spotlightFuture = spotlight;
      _trendingFuture = load.trending;
      _topAiringFuture = load.topAiring;
      _mostPopularFuture = load.mostPopular;
      _mostFavoriteFuture = load.mostFavorite;
      _topRatedFuture = load.topRated;
      _latestCompletedFuture = load.latestCompleted;
      _top10Future = load.top10;
      _recentEpisodesFuture = load.recentEpisodes;
    });
    unawaited(_enrichSpotlightTmdb(gen, spotlight));
    unawaited(_settleCatalog(gen, load));
  }

  Future<void> _settleCatalog(int gen, AnimeCatalogFutures load) async {
    try {
      final sections = await load.allSections;
      if (!mounted || gen != _loadGen || !identical(_appliedCatalog, load)) {
        return;
      }
      final hasCatalog = sections.any((s) => s.isNotEmpty);
      setState(() {
        _catalogResolved = true;
        _error = hasCatalog
            ? null
            : 'Failed to load anime - check your connection';
      });
      if (hasCatalog) markShellTabFresh();
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _catalogResolved = true;
        _error = 'Failed to load anime - check your connection';
      });
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('anime');
    WidgetsBinding.instance.removeObserver(this);
    AppTheme.themeNotifier.removeListener(_onTheme);
    SettingsService.animeTitleLanguageNotifier.removeListener(_onTheme);
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

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _loadGen++;
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    if (!_catalogResolved || _error != null) {
      unawaited(_load());
    }
  }

}
