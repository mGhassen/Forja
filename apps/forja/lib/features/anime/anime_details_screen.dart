// Anime details — built to mirror DetailsScreen's visual style.
// Backdrop + poster + chips + expandable synopsis + episode grid + related rail.

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:api/api/anime_service.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'anime_player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final AnimeCard anime;
  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> {
  final AnimeService _service = AnimeService();
  final ScrollController _scroll = ScrollController();

  AnimeCard? _full;
  List<AnimeEpisode> _episodes = [];
  List<AnimeCard> _related = [];
  List<AnimeCard> _seasons = [];
  Map<String, dynamic>? _progress;
  bool _liked = false;
  String? _error;

  String _category = 'sub';
  bool _synopsisExpanded = false;

  // Episode grouping (50 per chunk to keep UI snappy)
  int _episodeChunk = 0;
  static const int _chunkSize = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  AnimeCard get _data => _full ?? widget.anime;

  /// Synthesize a placeholder episode list from AniList's count so the
  /// page renders an episode grid immediately, while Anikoto resolves
  /// the real titles/IDs in the background.
  List<AnimeEpisode> _synthEpisodes(AnimeCard a) {
    final count = a.episodes ?? a.nextAiringEpisode?['episode'];
    // If AniList doesn't know the episode count (movies, ONAs, unannounced
    // series), assume a single episode so the user still gets a play button
    // instead of an empty grid.
    final n = (count is int && count > 0) ? count : 1;
    final airedNow = a.nextAiringEpisode?['episode'];
    final maxAired =
        (airedNow is int && airedNow > 1) ? (airedNow - 1) : n;
    return List.generate(
      n,
      (i) => AnimeEpisode(
        number: i + 1,
        title: 'Episode ${i + 1}',
        aired: (i + 1) <= maxAired,
      ),
    );
  }

  Future<void> _load() async {
    // Paint immediately using the card we already have. Each fetch below
    // fans out independently and upgrades the UI as it lands — the page
    // never blocks on the slowest call (which is usually Anikoto).
    setState(() {
      _error = null;
      _episodes = _synthEpisodes(widget.anime);
    });

    // 1. Fresh AniList details (banner, full synopsis, streamingEpisodes
    //    thumbnails). Usually fast, ~150-300ms.
    _service.getDetails(widget.anime.id).then((d) {
      if (!mounted) return;
      setState(() {
        _full = d;
        // Re-synth with the fresher data if Anikoto hasn't landed yet.
        if (_episodes.isEmpty || _episodes.length < (d.episodes ?? 0)) {
          _episodes = _synthEpisodes(d);
        }
      });
    }).catchError((e) {
      if (mounted && _full == null) {
        setState(() => _error = 'Failed to load: $e');
      }
    });

    // 2. Real episode list (Anikoto). Slow — walks /recent-anime feed +
    //    search + ID probes. The synth list keeps the UI populated until
    //    this lands.
    _service.getEpisodes(widget.anime).then((eps) {
      if (!mounted || eps.isEmpty) return;
      setState(() => _episodes = eps);
    }).catchError((_) {});

    // 3. Related (single AniList query). Independent.
    _service.getRelations(widget.anime.id).then((r) {
      if (!mounted) return;
      setState(() => _related = r);
    }).catchError((_) {});

    // 4. Local prefs — instant.
    _service.getProgress(widget.anime.id).then((p) {
      if (!mounted) return;
      setState(() => _progress = p);
    }).catchError((_) {});
    _service.isLiked(widget.anime.id).then((l) {
      if (!mounted) return;
      setState(() => _liked = l);
    }).catchError((_) {});

    // 5. Seasons (graph walk — multiple AniList queries). Background.
    _service.getSeasons(widget.anime.id).then((s) {
      if (!mounted) return;
      if (s.length > 1) setState(() => _seasons = s);
    }).catchError((e) {
      debugPrint('[Details] seasons load: $e');
    });
  }

  void _play(int epNumber) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimePlayerScreen(
          anime: _data,
          episodeNumber: epNumber,
          category: _category,
          allEpisodes: _episodes,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _toggleLike() async {
    await _service.toggleLike(_data);
    if (!mounted) return;
    setState(() => _liked = !_liked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.bgCard,
        behavior: SnackBarBehavior.floating,
        content: Text(
          _liked ? 'Added to your list' : 'Removed from your list',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: _error != null
              ? _buildError()
              : Stack(
                  children: [
                    _buildPageBackdrop(),
                    _buildContent(),
                  ],
                ),
        );
      },
    );
  }

  // Full-screen blurred backdrop that sits behind the entire scroll view.
  Widget _buildPageBackdrop() {
    final url = _data.bannerOrCover;
    if (url.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (_, _) => Container(color: AppTheme.bgCard),
              errorWidget: (_, _, _) => Container(color: AppTheme.bgCard),
            ),
          ),
          // Tint so text/cards remain readable
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgDark.withValues(alpha: 0.35),
                  AppTheme.bgDark.withValues(alpha: 0.65),
                  AppTheme.bgDark.withValues(alpha: 0.92),
                  AppTheme.bgDark,
                ],
                stops: const [0.0, 0.4, 0.75, 1.0],
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
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeroSliver(),
        SliverToBoxAdapter(child: _buildTitleBlock()),
        SliverToBoxAdapter(child: _buildActionRow()),
        SliverToBoxAdapter(child: _buildSynopsis()),
        SliverToBoxAdapter(child: _buildMetaGrid()),
        SliverToBoxAdapter(child: _buildCategoryToggle()),
        SliverToBoxAdapter(child: _buildEpisodesHeader()),
        if (_seasons.length > 1)
          SliverToBoxAdapter(child: _buildSeasonsRail()),
        if (_episodes.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final start = _episodeChunk * _chunkSize;
                  final ep = _episodes[start + i];
                  final isCurrent = _progress != null &&
                      _progress!['episode'] == ep.number;
                  return _episodeTile(ep, isCurrent);
                },
                childCount: () {
                  final start = _episodeChunk * _chunkSize;
                  final remaining = _episodes.length - start;
                  return remaining < _chunkSize ? remaining : _chunkSize;
                }(),
              ),
            ),
          )
        else
          SliverToBoxAdapter(child: _buildEmptyEpisodes()),
        if (_related.isNotEmpty)
          SliverToBoxAdapter(child: _buildRelated()),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ─── Hero sliver: just a top spacer so the page backdrop shows ─
  Widget _buildHeroSliver() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final h = isLandscape ? 200.0 : 280.0;

    return SliverAppBar(
      expandedHeight: h,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _frostedIcon(
        Icons.arrow_back_ios_new_rounded,
        () => Navigator.of(context).pop(),
      ),
    );
  }

  // ─── Title block (poster + title sit on top of the backdrop) ───
  Widget _buildTitleBlock() {
    final a = _data;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (a.coverUrl.isNotEmpty)
            Container(
              width: 110,
              height: 160,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: CachedNetworkImage(
                imageUrl: a.coverUrl,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  if (a.titleNative.isNotEmpty &&
                      a.titleNative != a.displayTitle)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        a.titleNative,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _buildHeroChips(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChips() {
    final a = _data;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if ((a.averageScore ?? 0) > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 3),
                Text(
                  ((a.averageScore ?? 0) / 10).toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (a.format != null && a.format!.isNotEmpty)
          _miniChip(a.format!),
        if (a.seasonYear != null) _miniChip('${a.seasonYear}'),
        if (a.episodes != null) _miniChip('${a.episodes} eps'),
        if (a.status != null && a.status!.isNotEmpty)
          _miniChip(_statusLabel(a.status!)),
      ],
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'RELEASING':
        return 'Airing';
      case 'FINISHED':
        return 'Completed';
      case 'NOT_YET_RELEASED':
        return 'Upcoming';
      case 'CANCELLED':
        return 'Cancelled';
      case 'HIATUS':
        return 'Hiatus';
      default:
        return s;
    }
  }

  Widget _miniChip(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          s,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _frostedIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.black.withValues(alpha: 0.4),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: color ?? Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Action row (Play / Resume / List) ────────────────────────
  Widget _buildActionRow() {
    final hasProgress = _progress != null;
    final resumeEp = hasProgress ? _progress!['episode'] as int? : null;
    final canPlay = _episodes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: canPlay
                    ? () => _play(resumeEp ?? 1)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        hasProgress
                            ? 'Resume Ep $resumeEp'
                            : 'Play Ep 1',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Synopsis ─────────────────────────────────────────────────
  Widget _buildSynopsis() {
    final desc = _data.cleanDescription;
    if (desc.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: () =>
            setState(() => _synopsisExpanded = !_synopsisExpanded),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstChild: Text(
            desc,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          secondChild: Text(
            desc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          crossFadeState: _synopsisExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),
      ),
    );
  }

  // ─── Metadata grid ────────────────────────────────────────────
  Widget _buildMetaGrid() {
    final a = _data;
    final entries = <(String, String)>[
      if (a.mainStudio != null && a.mainStudio!.isNotEmpty)
        ('Studio', a.mainStudio!),
      if (a.duration != null) ('Duration', '${a.duration} min/ep'),
      if (a.season != null && a.seasonYear != null)
        ('Season',
            '${a.season![0]}${a.season!.substring(1).toLowerCase()} ${a.seasonYear}'),
      if (a.popularity != null)
        ('Popularity', _compactNum(a.popularity!)),
      if (a.genres.isNotEmpty) ('Genres', a.genres.join(', ')),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _metaRow(entries[i].$1, entries[i].$2),
              if (i < entries.length - 1)
                Divider(
                  height: 16,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _compactNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ─── Sub/Dub toggle ───────────────────────────────────────────
  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            _categoryButton('sub', 'SUB', Icons.subtitles_rounded),
            _categoryButton('dub', 'DUB', Icons.mic_rounded),
          ],
        ),
      ),
    );
  }

  Widget _categoryButton(String id, String label, IconData icon) {
    final selected = _category == id;
    return Expanded(
      child: Material(
        color: selected
            ? AppTheme.primaryColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _category = id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Episodes header (with chunk selector) ────────────────────
  Widget _buildEpisodesHeader() {
    final chunks = (_episodes.length / _chunkSize).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.playlist_play_rounded,
                color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Episodes',
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
          if (_episodes.isNotEmpty)
            Text(
              '${_episodes.length} total',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (chunks > 1) ...[
            const SizedBox(width: 10),
            _chunkPicker(chunks),
          ],
        ],
      ),
    );
  }

  Widget _chunkPicker(int chunks) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showModalBottomSheet<int>(
            context: context,
            backgroundColor: AppTheme.bgCard,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => SafeArea(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chunks,
                itemBuilder: (_, i) {
                  final start = i * _chunkSize + 1;
                  final end = ((i + 1) * _chunkSize)
                      .clamp(0, _episodes.length);
                  return ListTile(
                    title: Text(
                      'Episodes $start–$end',
                      style: TextStyle(
                        color: i == _episodeChunk
                            ? AppTheme.primaryColor
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(i),
                  );
                },
              ),
            ),
          );
          if (picked != null && mounted) {
            setState(() => _episodeChunk = picked);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_episodeChunk * _chunkSize + 1}–${((_episodeChunk + 1) * _chunkSize).clamp(0, _episodes.length)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodeTile(AnimeEpisode ep, bool isCurrent) {
    return Material(
      color: isCurrent
          ? AppTheme.primaryColor.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: ep.aired ? () => _play(ep.number) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Center(
            child: Text(
              '${ep.number}',
              style: TextStyle(
                color: ep.aired
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonsRail() {
    final currentId = widget.anime.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: SizedBox(
        height: 36,
        child: HorizontalScroller(
          height: 36,
          itemCount: _seasons.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _seasons[i];
            final selected = s.id == currentId;
            return HoverScale(
              radius: 18,
              onTap: () {
                if (selected) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => AnimeDetailsScreen(anime: s),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryColor.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'S${i + 1}\u00a0\u00b7\u00a0${s.displayTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyEpisodes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.movie_filter_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'No episodes available yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Related rail ─────────────────────────────────────────────
  Widget _buildRelated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.collections_bookmark_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Related',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: HorizontalScroller(
            height: 280,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = _related[i];
              return HoverScale(
                radius: 12,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AnimeDetailsScreen(anime: r),
                    ),
                  );
                },
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 195,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: r.coverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: r.coverUrl,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (r.format != null && r.format!.isNotEmpty)
                        Text(
                          r.format!,
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
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
}
