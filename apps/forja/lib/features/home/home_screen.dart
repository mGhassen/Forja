import 'dart:async';
import 'package:rust/rust.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/home/providers/home_feed_providers.dart';
import 'package:forja/features/home/providers/home_tracker_providers.dart';
import 'package:forja/features/home/home_catalog_rotate.dart';
import 'package:forja/features/home/home_rail_dedupe.dart';
import 'package:forja/shared/catalog/bestsimilar_scraper.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/features/home/home_genre_categories.dart';
import 'package:forja/features/home/home_hero.dart';
import 'package:forja/features/home/widgets/because_you_watched_section.dart';
import 'package:forja/features/home/widgets/continue_watching_section.dart';
import 'package:forja/features/home/widgets/home_mood_section.dart';
import 'package:forja/features/home/widgets/home_movie_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:visibility_detector/visibility_detector.dart';




part 'home_screen_feed.dart';
part 'home_screen_build.dart';
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin, ShellTabRefresh<HomeScreen>, _HomeScreenFeed, _HomeScreenBuild {

  final TmdbApi _api = TmdbApi();
  final ScrollController _homeScrollController = ScrollController();
  final HomeHeroController _homeHeroController = HomeHeroController();
  Future<List<Movie>> _popularFuture = Future.value(const <Movie>[]);
  Future<List<Movie>> _featuredThisMonthFuture = Future.value(const <Movie>[]);
  Future<List<Movie>> _nowPlayingFuture = Future.value(const <Movie>[]);

  List<({String id, String label, Future<List<Movie>> future, List<Movie>? pool})>
      _randomCategoryRows = [];
  /// Last painted TMDB rails — survive filter flips so the page stays painted
  /// until the matching fetch lands (do not re-strip by the new Films/TV filter).
  List<Movie> _railCacheTrending = const [];
  List<Movie> _railCacheFeatured = const [];
  List<Movie> _railCachePopular = const [];
  List<Movie> _railCacheNowPlaying = const [];
  /// Rails allowed to hit TMDB / start row fetches. Hero + Featured (+ Popular
  /// preload on shell) start armed; the rest arm on viewport (+1 lookahead).
  final Set<String> _armedRails = {'trending', 'featured'};
  final Set<String> _genreFetchStarted = {};
  bool _bootstrapArmsDone = false;
  int _genreRowsGen = 0;
  /// Stable hero Future identity — a new Future.value every build remounts
  /// FutureBuilder into shimmer.
  String _heroSlideSig = '';
  Future<List<Movie>> _heroMoviesFuture = Future.value(const <Movie>[]);

  // Trakt personalized sections
  List<Movie> _traktRecommendations = [];
  List<Movie> _traktUpcomingShows = [];
  List<Movie> _traktUpcomingMovies = [];
  bool _traktRecsLoading = false;
  bool _traktShowsLoading = false;
  bool _traktMoviesLoading = false;

  // "Because you watched ___" - seed from continue-watching; re-rolls on
  // Home refresh / shuffle, then BestSimilar.com recommendations (mapped to TMDB).
  Map<String, dynamic>? _becauseSeed; // raw history item
  Future<List<Movie>>? _becauseFuture;
  List<Movie>? _becausePool;
  int _becausePoolSize = 0; // unique in-progress shows; controls shuffle button
  StreamSubscription<List<Map<String, dynamic>>>? _historySeedSub;
  /// Invalidates Because-you-watched + Trakt home rails when the tab hides.
  int _homeBgWorkGen = 0;
  /// Cancels in-flight BestSimilar resolves without aborting Trakt home loads.
  int _becauseWorkGen = 0;
  bool _postSplashWorkStarted = false;
  VoidCallback? _splashDismissedListener;

  bool _shellOffsetSyncScheduled = false;

  // Mood/genre filter state
  String _selectedMood = 'mind';
  Future<List<Movie>>? _moodFuture;
  List<Movie>? _moodPool;
  /// Bumps on every mood tap so each click fetches a fresh rotate mix.
  int _moodReloadToken = 0;

  // Mood definitions - movie and TV use different TMDB genre IDs.
  static const List<({
    String id,
    String label,
    IconData icon,
    Color accent,
    List<int> movieGenres,
    List<int> tvGenres,
  })> _moods = [
    (
      id: 'mind',
      label: 'Mind-Bending',
      icon: Icons.psychology_rounded,
      accent: Color(0xFF8B5CF6),
      movieGenres: [878, 9648],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'feel',
      label: 'Feel-Good',
      icon: Icons.wb_sunny_rounded,
      accent: Color(0xFFFBBF24),
      movieGenres: [35, 10751],
      tvGenres: [35, 10751],
    ),
    (
      id: 'dark',
      label: 'Dark Thrillers',
      icon: Icons.dark_mode_rounded,
      accent: Color(0xFF64748B),
      movieGenres: [53, 80],
      tvGenres: [80, 9648],
    ),
    (
      id: 'romance',
      label: 'Romance',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFEC4899),
      movieGenres: [10749],
      tvGenres: [18],
    ),
    (
      id: 'horror',
      label: 'Horror',
      icon: Icons.bedtime_rounded,
      accent: Color(0xFF7C3AED),
      movieGenres: [27],
      tvGenres: [10765, 9648],
    ),
    (
      id: 'action',
      label: 'Action',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFF97316),
      movieGenres: [28, 12],
      tvGenres: [10759],
    ),
    (
      id: 'animated',
      label: 'Animated',
      icon: Icons.brush_rounded,
      accent: Color(0xFF06B6D4),
      movieGenres: [16],
      tvGenres: [16],
    ),
    (
      id: 'drama',
      label: 'Drama',
      icon: Icons.theaters_rounded,
      accent: Color(0xFF3B82F6),
      movieGenres: [18],
      tvGenres: [18],
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  Duration get shellStaleAfter => ShellTokens.tabStaleHome;

  @override
  Future<void> onShellTabRefresh({required bool force}) => _reloadHomeFeed();

  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _pauseHomeBackgroundWork();
  }

  @override
  void onShellTabShown() {
    super.onShellTabShown();
    _resumeHomeBackgroundWorkIfNeeded();
  }

  int? get _watchProviderId => ShellBus.selectedWatchProviderId.value;

  ShellHomeCategory? get _mediaFilter => ShellBus.homeCategory.value;

  ({List<int>? movie, List<int>? tv}) get _genreIds {
    final genre = lookupHomeGenre(ShellBus.homeSelectedGenreId.value);
    if (genre == null) return (movie: null, tv: null);
    return (movie: genre.movieGenres, tv: genre.tvGenres);
  }




  bool _isRailArmed(String id) => _armedRails.contains(id);

  void _ensureBootstrapArms({required bool usesShellHome}) {
    if (_bootstrapArmsDone) return;
    _bootstrapArmsDone = true;
    // +1 lookahead after Featured (first painted catalog row).
    if (usesShellHome) {
      _armedRails.add('popular');
    } else {
      _armedRails.add('mood');
    }
  }

  /// Visual order of lazy TMDB catalog rails — overlays (CW / Because / Trakt)
  /// stay out so an empty Continue Watching row cannot stall mood / New Releases.
  List<String> _homeLazyRailChain({required bool usesShellHome}) {
    if (usesShellHome) {
      return [
        'featured',
        'popular',
        'mood',
        'new-releases',
        for (final row in _randomCategoryRows) 'genre-${row.id}',
      ];
    }
    return [
      'featured',
      'mood',
      'popular',
      'new-releases',
      for (final row in _randomCategoryRows) 'genre-${row.id}',
    ];
  }

  void _armRailAndNext(String id, {required bool usesShellHome}) {
    final chain = _homeLazyRailChain(usesShellHome: usesShellHome);
    final i = chain.indexOf(id);
    final next = (i >= 0 && i + 1 < chain.length) ? chain[i + 1] : null;
    if (_armedRails.contains(id) &&
        (next == null || _armedRails.contains(next))) {
      return;
    }
    final kicks = <String>[];
    setState(() {
      if (_armedRails.add(id)) kicks.add(id);
      if (next != null && _armedRails.add(next)) kicks.add(next);
    });
    for (final k in kicks) {
      _onRailArmed(k);
    }
  }

  void _syncMainRailFutures() {
    ref.watch(homeTrendingProvider);
    ref.watch(homeFeaturedProvider);
    _featuredThisMonthFuture = ref.read(homeFeaturedProvider.future);
    if (_isRailArmed('popular')) {
      ref.watch(homePopularProvider);
      _popularFuture = ref.read(homePopularProvider.future);
    }
    if (_isRailArmed('new-releases')) {
      ref.watch(homeNowPlayingProvider);
      _nowPlayingFuture = ref.read(homeNowPlayingProvider.future);
    }
  }

  void _syncHomeScrollOffset() {
    if (_shellOffsetSyncScheduled) return;
    _shellOffsetSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shellOffsetSyncScheduled = false;
      if (!mounted || !_homeScrollController.hasClients) return;
      final offset = _homeScrollController.offset;
      if (ShellBus.homeScrollOffset.value != offset) {
        ShellBus.homeScrollOffset.value = offset;
      }
    });
  }


  @override
  void initState() {
    super.initState();
    _homeScrollController.addListener(_syncHomeScrollOffset);
    _resetHomeCategoryFeeds();

    _schedulePostSplashWork();
    markShellTabFresh();
  }



}
