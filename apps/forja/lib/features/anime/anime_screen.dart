// Anime hub — built to mirror the look & feel of HomeScreen.
// Hero carousel + horizontal poster rails + ambient backdrop + mood chips.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shimmer/shimmer.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'anime_details_screen.dart';
import 'anime_discover_screen.dart';
import 'anime_player_screen.dart';
import 'anime_search_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart' hide AppTheme;

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final AnimeService _service = AnimeService();
  final PageController _heroController = PageController();
  final ScrollController _cwScrollController = ScrollController();
  final ScrollController _scroll = ScrollController();

  Timer? _heroTimer;
  int _heroIndex = 0;

  // Section data
  List<AnimeCard> _spotlight = [];
  List<AnimeCard> _trending = [];
  List<AnimeCard> _topAiring = [];
  List<AnimeCard> _mostPopular = [];
  List<AnimeCard> _mostFavorite = [];
  List<AnimeCard> _topRated = [];
  List<AnimeCard> _latestCompleted = [];
  List<AnimeCard> _top10 = [];
  List<AnimeCard> _recentEpisodes = [];

  bool _loading = true;
  String? _error;

  // Continue watching
  List<Map<String, dynamic>> _continueWatching = [];

  // Tonight's Pick
  AnimeCard? _tonightsPick;

  // Mood / genre filter
  String _selectedMood = 'shonen';
  Future<List<AnimeCard>>? _moodFuture;

  // Ambient backdrop colors derived from the active hero poster.
  Color _ambientPrimary = AppTheme.primaryColor;
  Color _ambientSecondary = AppTheme.accentColor;
  final Map<int, ({Color primary, Color secondary})> _ambientCache = {};

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
    WidgetsBinding.instance.addObserver(this);
    AppTheme.themeNotifier.addListener(_onTheme);
    AnimeService.watchHistoryRevision.addListener(_onHistoryChanged);
    _moodFuture = _loadMood(_selectedMood);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppTheme.themeNotifier.removeListener(_onTheme);
    AnimeService.watchHistoryRevision.removeListener(_onHistoryChanged);
    _heroTimer?.cancel();
    _heroController.dispose();
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

  void _onHistoryChanged() => _refreshHistory();

  /// Reload only the Continue Watching list — cheap, no API hits other
  /// than SharedPreferences. Called on app resume, on history mutation,
  /// and after returning from any screen that may have updated history.
  Future<void> _refreshHistory() async {
    try {
      final list = await _service.getWatchHistory();
      if (!mounted) return;
      setState(() {
        _continueWatching = list.take(10).toList();
      });
    } catch (_) {}
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getSpotlight(),
        _service.getTrending(),
        _service.getTopAiring(),
        _service.getMostPopular(),
        _service.getMostFavorite(),
        _service.getTopRated(),
        _service.getLatestCompleted(),
        _service.getTop10Today(),
        _service.getRecentEpisodes(),
        _service.getWatchHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _spotlight = (results[0] as List<AnimeCard>).take(5).toList();
        _trending = results[1] as List<AnimeCard>;
        _topAiring = results[2] as List<AnimeCard>;
        _mostPopular = results[3] as List<AnimeCard>;
        _mostFavorite = results[4] as List<AnimeCard>;
        _topRated = results[5] as List<AnimeCard>;
        _latestCompleted = results[6] as List<AnimeCard>;
        _top10 = results[7] as List<AnimeCard>;
        _recentEpisodes = results[8] as List<AnimeCard>;
        _continueWatching =
            (results[9] as List<Map<String, dynamic>>).take(10).toList();

        if (_trending.length > 4) {
          final pool = _trending.skip(3).toList();
          _tonightsPick = pool[math.Random().nextInt(pool.length)];
        }
        _loading = false;
      });

      if (_spotlight.isNotEmpty) {
        _extractAmbient(_spotlight.first);
        _startHeroTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load anime: $e';
        });
      }
    }
  }

  Future<List<AnimeCard>> _loadMood(String id) async {
    try {
      final mood = _moods.firstWhere((m) => m.id == id, orElse: () => _moods[0]);
      return await _service.browse(
        genre: mood.genre,
        sort: 'TRENDING_DESC',
        perPage: 20,
      );
    } catch (e) {
      debugPrint('[AnimeScreen] mood load failed: $e');
      return const [];
    }
  }

  void _selectMood(String id) {
    if (id == _selectedMood) return;
    setState(() {
      _selectedMood = id;
      _moodFuture = _loadMood(id);
    });
  }

  void _shuffleTonight() {
    if (_trending.length < 4) return;
    final pool = _trending.skip(3).toList();
    setState(() => _tonightsPick = pool[math.Random().nextInt(pool.length)]);
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_spotlight.length < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_heroController.hasClients) return;
      final next = (_heroIndex + 1) % _spotlight.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  Future<void> _extractAmbient(AnimeCard a) async {
    if (_ambientCache.containsKey(a.id)) {
      final c = _ambientCache[a.id]!;
      if (!mounted) return;
      setState(() {
        _ambientPrimary = c.primary;
        _ambientSecondary = c.secondary;
      });
      return;
    }
    final url = a.bannerOrCover;
    if (url.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        size: const Size(180, 100),
        maximumColorCount: 12,
      );
      if (!mounted) return;
      final p = palette.dominantColor?.color ?? AppTheme.primaryColor;
      final s = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          AppTheme.accentColor;
      _ambientCache[a.id] = (primary: p, secondary: s);
      setState(() {
        _ambientPrimary = p;
        _ambientSecondary = s;
      });
    } catch (_) {}
  }

  void _openDetails(AnimeCard a) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: a)),
    ).then((_) => _refreshHistory());
  }

  void _openDiscover() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnimeDiscoverScreen()),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnimeSearchScreen()),
    );
  }

  Future<void> _resumeWatch(Map<String, dynamic> entry) async {
    try {
      final anime = AnimeCard.fromJson(
          (entry['anime'] as Map).cast<String, dynamic>());
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final cat = (entry['category'] as String?) ?? 'sub';
      // Don't await getEpisodes here — push the player immediately so it
      // can start resolving streams in parallel. The player can fetch
      // its own episode list when the user opens the episode picker.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnimePlayerScreen(
            anime: anime,
            episodeNumber: epNum,
            category: cat,
            allEpisodes: const [],
          ),
        ),
      ).then((_) => _refreshHistory());
    } catch (_) {}
  }

  Future<void> _removeFromHistory(Map<String, dynamic> entry) async {
    final animeId = entry['animeId'] as int?;
    if (animeId == null) return;
    await _service.removeFromHistory(animeId);
    if (!mounted) return;
    setState(() {
      _continueWatching.removeWhere((e) => e['animeId'] == animeId);
    });
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : Stack(
                      children: [
                        _buildAmbientBackdrop(),
                        RefreshIndicator(
                          color: AppTheme.primaryColor,
                          backgroundColor: AppTheme.bgCard,
                          onRefresh: _load,
                          child: CustomScrollView(
                            controller: _scroll,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverAppBar(
                                pinned: false,
                                floating: true,
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.search,
                                        color: Colors.white),
                                    onPressed: _openSearch,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.tune_rounded,
                                        color: Colors.white),
                                    tooltip: 'Discover',
                                    onPressed: _openDiscover,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                              SliverToBoxAdapter(child: _buildHero()),
                              if (_continueWatching.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _buildContinueWatching(),
                                ),
                              SliverToBoxAdapter(child: _buildSpotlightMosaic()),
                              SliverToBoxAdapter(child: _buildMoodChips()),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Trending Now',
                                  icon: Icons.trending_up_rounded,
                                  items: _trending,
                                  onTap: _openDetails,
                                ),
                              ),
                              if (_tonightsPick != null)
                                SliverToBoxAdapter(
                                  child: _buildTonightsPick(),
                                ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Top Airing',
                                  icon: Icons.live_tv_rounded,
                                  items: _topAiring,
                                  onTap: _openDetails,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Top 10 Today',
                                  icon: Icons.leaderboard_rounded,
                                  items: _top10,
                                  onTap: _openDetails,
                                  showRank: true,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Most Popular',
                                  icon: Icons.whatshot_rounded,
                                  items: _mostPopular,
                                  onTap: _openDetails,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Latest Episodes',
                                  icon: Icons.new_releases_rounded,
                                  items: _recentEpisodes,
                                  onTap: _openDetails,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Top Rated',
                                  icon: Icons.star_rounded,
                                  items: _topRated,
                                  onTap: _openDetails,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Most Favorited',
                                  icon: Icons.favorite_rounded,
                                  items: _mostFavorite,
                                  onTap: _openDetails,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _AnimeRail(
                                  title: 'Recently Completed',
                                  icon: Icons.check_circle_rounded,
                                  items: _latestCompleted,
                                  onTap: _openDetails,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 80),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
      },
    );
  }

  // ─── Ambient backdrop ──────────────────────────────────────────
  Widget _buildAmbientBackdrop() {
    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        child: Stack(
          children: [
            Container(color: AppTheme.bgDark),
            Positioned(
              top: -120,
              right: -160,
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ambientPrimary.withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -160,
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ambientSecondary.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 280,
              right: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ambientPrimary.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Container(color: AppTheme.bgDark.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }

  // ─── Spotlight (mosaic, mirrors home page) ─────────────────────
  Widget _buildSpotlightMosaic() {
    if (_spotlight.length < 5) return const SizedBox.shrink();
    return _AnimeMosaicSpotlight(
      items: _spotlight.take(5).toList(),
      onTap: _openDetails,
    );
  }

  // ─── Hero carousel ─────────────────────────────────────────────
  Widget _buildHero() {
    if (_spotlight.isEmpty) return const SizedBox.shrink();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final h = isLandscape
        ? MediaQuery.of(context).size.height * 0.65
        : MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroController,
            itemCount: _spotlight.length,
            onPageChanged: (i) {
              setState(() => _heroIndex = i);
              _extractAmbient(_spotlight[i]);
            },
            itemBuilder: (_, i) =>
                _buildHeroSlide(_spotlight[i], isLandscape),
          ),
          // Dot indicator
          Positioned(
            bottom: 22,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _spotlight.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 3,
                  width: i == _heroIndex ? 28 : 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i == _heroIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    boxShadow: i == _heroIndex
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlide(AnimeCard a, bool isLandscape) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (a.bannerOrCover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: a.bannerOrCover,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (_, _) => Container(color: AppTheme.bgCard),
            errorWidget: (_, _, _) => Container(color: AppTheme.bgCard),
          ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                AppTheme.bgDark.withValues(alpha: 0.3),
                AppTheme.bgDark.withValues(alpha: 0.85),
                AppTheme.bgDark,
              ],
              stops: const [0.0, 0.25, 0.55, 0.8, 1.0],
            ),
          ),
        ),
        // Content
        Positioned(
          left: 24,
          right: 24,
          bottom: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                a.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLandscape ? 36 : 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      blurRadius: 20,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildHeroMeta(a),
              if (a.cleanDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  a.cleanDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  ForjaGhostButton(
                    label: 'Watch Now',
                    icon: Icons.play_arrow_rounded,
                    onTap: () => _openDetails(a),
                  ),
                  const SizedBox(width: 16),
                  ForjaPlainIcon(
                    icon: Icons.info_outline_rounded,
                    tooltip: 'Details',
                    onTap: () => _openDetails(a),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroMeta(AnimeCard a) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if ((a.averageScore ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 3),
                Text(
                  ((a.averageScore ?? 0) / 10).toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (a.seasonYear != null)
          Text(
            '${a.seasonYear}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (a.format != null && a.format!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              a.format!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (a.episodes != null)
          Text(
            '${a.episodes} eps',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        if (a.genres.isNotEmpty)
          Text(
            a.genres.take(3).join(' · '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _frostedPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Continue watching ─────────────────────────────────────────
  void _cwScrollLeft() {
    if (_cwScrollController.hasClients) {
      _cwScrollController.animateTo(
        (_cwScrollController.offset - 400).clamp(0.0, _cwScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _cwScrollRight() {
    if (_cwScrollController.hasClients) {
      _cwScrollController.animateTo(
        (_cwScrollController.offset + 400).clamp(0.0, _cwScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _cwArrowButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
    );
  }

  Widget _buildContinueWatching() {
    final w = MediaQuery.of(context).size.width;
    // Card width scales: phone 200, tablet 240, desktop 280.
    final cardW = w < 600 ? 200.0 : (w < 1100 ? 240.0 : 280.0);
    final cardH = cardW * (130.0 / 220.0); // keep ~1.69 aspect
    final hPad = w < 380 ? 14.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue Watching',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2.5,
                      width: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _cwScrollLeft,
                child: _cwArrowButton(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _cwScrollRight,
                child: _cwArrowButton(Icons.arrow_forward_ios_rounded),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardH,
          child: ListView.separated(
            controller: _cwScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: _continueWatching.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final entry = _continueWatching[i];
              final animeJson =
                  (entry['anime'] as Map).cast<String, dynamic>();
              final anime = AnimeCard.fromJson(animeJson);
              final ep = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
              final cat = (entry['category'] as String?) ?? 'sub';
              return HoverScale(
                onTap: () => _resumeWatch(entry),
                radius: 14,
                child: Container(
                  width: cardW,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (anime.bannerOrCover.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: anime.bannerOrCover,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ep $ep · ${cat.toUpperCase()}',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _removeFromHistory(entry),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Mood chips ────────────────────────────────────────────────
  Widget _buildMoodChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Pick your vibe', Icons.tune_rounded),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _moods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = _moods[i];
                final selected = m.id == _selectedMood;
                return Material(
                  color: selected
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _selectMood(m.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                                  .withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            m.icon,
                            size: 14,
                            color: selected
                                ? AppTheme.primaryColor
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            m.label,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.75),
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildMoodSection(),
        ],
      ),
    );
  }

  Widget _buildMoodSection() {
    return FutureBuilder<List<AnimeCard>>(
      future: _moodFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(
            height: 290,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          );
        }
        return _AnimeRail(
          title: 'In the mood',
          icon: Icons.auto_awesome_rounded,
          items: snap.data!,
          onTap: _openDetails,
          topPadding: 0,
          hideHeader: true,
        );
      },
    );
  }

  // ─── Tonight's Pick ────────────────────────────────────────────
  Widget _buildTonightsPick() {
    final a = _tonightsPick!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.nights_stay_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Tonight's Pick",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _shuffleTonight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shuffle_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Shuffle',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final isWide = w > 700;
              final h = (w / (isWide ? 2.6 : 1.9)).clamp(260.0, 420.0);
              final img = a.bannerOrCover;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openDetails(a),
                child: Container(
                  height: h,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        blurRadius: 32,
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.15),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.92),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.10),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                if ((a.averageScore ?? 0) > 0) ...[
                                  const Icon(Icons.star_rounded,
                                      size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    ((a.averageScore ?? 0) / 10)
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (a.seasonYear != null)
                                  Text(
                                    '${a.seasonYear}',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                if (a.genres.isNotEmpty) ...[
                                  Text(
                                    '  ·  ',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    a.genres.take(2).join(' · '),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isWide ? 28 : 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (a.cleanDescription.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                a.cleanDescription,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.72),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _openDetails(a),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow_rounded,
                                          color: Colors.black, size: 22),
                                      SizedBox(width: 4),
                                      Text(
                                        'Play',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Section header (re-usable) ───────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2.5,
                  width: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading & error states ───────────────────────────────────
  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: const Color(0xFF1E1E2F),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80),
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.55,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 18,
              width: 160,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => Container(
                width: 160,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppTheme.primaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Reusable horizontal poster rail
// ──────────────────────────────────────────────────────────────────
class _AnimeRail extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<AnimeCard> items;
  final void Function(AnimeCard) onTap;
  final bool showRank;
  final double topPadding;
  final bool hideHeader;

  const _AnimeRail({
    required this.title,
    required this.icon,
    required this.items,
    required this.onTap,
    this.showRank = false,
    this.topPadding = 32,
    this.hideHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final w = MediaQuery.of(context).size.width;
    // Three breakpoints: phone (<600), tablet (<1100), desktop (≥1100).
    final cardW = w < 600 ? 150.0 : (w < 1100 ? 175.0 : 200.0);
    final cardH = cardW * 1.5;
    final railH = cardH + 64; // poster + title block
    final hPad = w < 380 ? 14.0 : 24.0;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideHeader)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        color: AppTheme.primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2.5,
                          width: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: railH,
            child: HorizontalScroller(
              height: railH,
              padding: EdgeInsets.symmetric(
                  horizontal: showRank ? (hPad - 6).clamp(8.0, 24.0) : hPad),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  SizedBox(width: showRank ? 6 : 14),
              itemBuilder: (_, i) => _AnimeCardTile(
                anime: items[i],
                width: cardW,
                height: cardH,
                rank: showRank ? i + 1 : null,
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeCardTile extends StatelessWidget {
  final AnimeCard anime;
  final double width;
  final double height;
  final int? rank;
  final VoidCallback onTap;

  const _AnimeCardTile({
    required this.anime,
    required this.width,
    required this.height,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final card = HoverScale(
      onTap: onTap,
      radius: 14,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (anime.coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: anime.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppTheme.bgCard),
                      errorWidget: (_, _, _) => Container(
                        color: AppTheme.bgCard,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white24),
                      ),
                    ),
                  // Bottom gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                  if ((anime.averageScore ?? 0) > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              ((anime.averageScore ?? 0) / 10)
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (anime.format != null && anime.format!.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          anime.format!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (anime.seasonYear != null || anime.episodes != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (anime.seasonYear != null) '${anime.seasonYear}',
                    if (anime.episodes != null) '${anime.episodes} eps',
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (rank == null) return card;

    return SizedBox(
      width: width + 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: card,
          ),
          Positioned(
            left: -4,
            bottom: 60,
            child: Text(
              '$rank',
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 88,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -4,
                shadows: [
                  Shadow(
                    blurRadius: 12,
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Mosaic Spotlight — port of home page's _MosaicSpotlight, adapted
//  for AnimeCard. 1 large featured tile + 4 smaller tiles.
// ════════════════════════════════════════════════════════════════════
class _AnimeMosaicSpotlight extends StatelessWidget {
  final List<AnimeCard> items;
  final void Function(AnimeCard) onTap;
  const _AnimeMosaicSpotlight({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.length < 5) return const SizedBox.shrink();
    final featured = items.first;
    final small = items.skip(1).take(4).toList();

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final isWide = w > 720;
      final hPad = w < 380 ? 14.0 : (w < 520 ? 18.0 : 24.0);
      final headerTopPad = w < 380 ? 24.0 : 36.0;
      final headerBotPad = w < 380 ? 12.0 : 16.0;

      final header = Padding(
        padding: EdgeInsets.fromLTRB(hPad, headerTopPad, hPad, headerBotPad),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Spotlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (w >= 380)
              Text(
                '${items.length} trending now',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );

      if (isWide) {
        final featuredW = (w - hPad * 2 - 14) * 0.58;
        final smallW = (w - hPad * 2 - 14) * 0.42;
        final tileH = featuredW * 0.58;
        final smallTileH = (tileH - 12) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: featuredW,
                    height: tileH,
                    child: _AnimeMosaicTile(
                      anime: featured,
                      onTap: () => onTap(featured),
                      big: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: smallW,
                    height: tileH,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: (smallW / 2 - 6) / smallTileH,
                      children: small
                          .map((m) => _AnimeMosaicTile(
                                anime: m,
                                onTap: () => onTap(m),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      final featuredAvail = w - hPad * 2;
      final featuredH = (featuredAvail * 0.56).clamp(170.0, 320.0);
      final smallTileW = w < 380
          ? (w * 0.62).clamp(180.0, 240.0)
          : (w < 520 ? 200.0 : 220.0);
      final smallTileH = w < 380 ? 110.0 : 130.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: SizedBox(
              height: featuredH,
              child: _AnimeMosaicTile(
                anime: featured,
                onTap: () => onTap(featured),
                big: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: smallTileH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: hPad),
              itemCount: small.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                width: smallTileW,
                child: _AnimeMosaicTile(
                  anime: small[i],
                  onTap: () => onTap(small[i]),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _AnimeMosaicTile extends StatelessWidget {
  final AnimeCard anime;
  final VoidCallback onTap;
  final bool big;
  const _AnimeMosaicTile({
    required this.anime,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = anime.bannerOrCover;
    return HoverScale(
      onTap: onTap,
      radius: 16,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) =>
                    Container(color: AppTheme.bgCard),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            if (big)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    '#1 TRENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            if ((anime.averageScore ?? 0) > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        ((anime.averageScore ?? 0) / 10).toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    anime.displayTitle,
                    maxLines: big ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: big ? 20 : 14,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.3,
                      shadows: const [
                        Shadow(blurRadius: 10, color: Colors.black87),
                      ],
                    ),
                  ),
                  if (big) const SizedBox(height: 6),
                  if (big)
                    Text(
                      [
                        if (anime.format != null) anime.format!,
                        if (anime.seasonYear != null) '${anime.seasonYear}',
                        if (anime.episodes != null)
                          '${anime.episodes} eps',
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
