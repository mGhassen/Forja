// AnimeSlayer details screen — mirrors `AnimeDetailsScreen` visual style.
// Backdrop blur + poster + chips + expandable synopsis + episode grid +
// related rail. Bound to `AnimeArabicService` / `ArabicAnimeDetails`.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:api/api/anime_arabic_service.dart';
import 'package:storage/storage.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'anime_arabic_player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';

class AnimeArabicDetailsScreen extends StatefulWidget {
  final ArabicAnimeCard anime;

  const AnimeArabicDetailsScreen({super.key, required this.anime});

  @override
  State<AnimeArabicDetailsScreen> createState() =>
      _AnimeArabicDetailsScreenState();
}

class _AnimeArabicDetailsScreenState extends State<AnimeArabicDetailsScreen> {
  final AnimeArabicService _service = AnimeArabicService();
  final ScrollController _scroll = ScrollController();

  ArabicAnimeDetails? _details;
  Map<String, dynamic>? _progress;
  bool _loading = true;
  bool _synopsisExpanded = false;
  String? _error;

  // Episode pager
  int _episodeChunk = 0;
  static const int _chunkSize = 50;

  @override
  void initState() {
    super.initState();
    _load();
    AnimeArabicService.watchHistoryRevision.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _scroll.dispose();
    AnimeArabicService.watchHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    _service.getProgress(widget.anime.slug).then((p) {
      if (!mounted) return;
      setState(() => _progress = p);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getDetails(widget.anime.slug),
        _service.getProgress(widget.anime.slug),
      ]);
      if (!mounted) return;
      setState(() {
        _details = results[0] as ArabicAnimeDetails;
        _progress = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _play(ArabicEpisode ep) {
    if (ep.watchPath.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeArabicPlayerScreen(
          anime: widget.anime,
          episode: ep,
          allEpisodes: _details?.episodes ?? const [],
        ),
      ),
    ).then((_) => _onHistoryChanged());
  }

  // ─────────────────────────────────────────────────────────────
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
                    _buildBackdrop(),
                    if (_loading)
                      Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    else
                      _buildContent(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBackdrop() {
    final url = _details?.displayBanner.isNotEmpty == true
        ? _details!.displayBanner
        : (widget.anime.cover ?? '');
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
              'Failed to load: $_error',
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
    final d = _details!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final heroH = isLandscape ? 200.0 : 280.0;

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: heroH,
          pinned: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _frostedIcon(
            Icons.arrow_back_ios_new_rounded,
            () => Navigator.of(context).pop(),
          ),
        ),
        SliverToBoxAdapter(child: _buildTitleBlock(d)),
        SliverToBoxAdapter(child: _buildActionRow(d)),
        SliverToBoxAdapter(child: _buildSynopsis(d)),
        if (d.genres.isNotEmpty)
          SliverToBoxAdapter(child: _buildGenres(d)),
        SliverToBoxAdapter(child: _buildMetaGrid(d)),
        if (d.episodes.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildEpisodesHeader(d)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isLandscape ? 6 : 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final start = _episodeChunk * _chunkSize;
                  final ep = d.episodes[start + i];
                  final isCurrent =
                      _progress?['episodeNumber'] == ep.number;
                  return _episodeTile(ep, isCurrent);
                },
                childCount: () {
                  final start = _episodeChunk * _chunkSize;
                  final remaining = d.episodes.length - start;
                  return remaining < _chunkSize ? remaining : _chunkSize;
                }(),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(child: _buildEmptyEpisodes()),
        if (d.related.isNotEmpty)
          SliverToBoxAdapter(child: _buildRelated(d)),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ─── Title block ─────────────────────────────────────────────
  Widget _buildTitleBlock(ArabicAnimeDetails a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (a.displayCover.isNotEmpty)
            Container(
              width: 110,
              height: 160,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
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
                imageUrl: a.displayCover,
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
                    a.title,
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
                  const SizedBox(height: 10),
                  _buildHeroChips(a),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChips(ArabicAnimeDetails a) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (a.rating != null && a.rating!.isNotEmpty)
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
                  a.rating!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (a.year != null && a.year!.isNotEmpty) _miniChip(a.year!),
        if (a.status != null && a.status!.isNotEmpty) _miniChip(a.status!),
        if (a.episodes.isNotEmpty)
          _miniChip('${a.episodes.length} حلقة'),
        if (a.studio != null && a.studio!.isNotEmpty)
          _miniChip(a.studio!),
      ],
    );
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

  Widget _frostedIcon(IconData icon, VoidCallback onTap) {
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
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Action row (Play / Resume) ──────────────────────────────
  Widget _buildActionRow(ArabicAnimeDetails a) {
    final hasProgress = _progress != null;
    final resumeEpNum =
        hasProgress ? _progress!['episodeNumber'] as int? : null;
    final firstEp = a.episodes.isNotEmpty ? a.episodes.first : null;
    ArabicEpisode? resumeEp;
    if (resumeEpNum != null) {
      try {
        resumeEp = a.episodes.firstWhere((e) => e.number == resumeEpNum);
      } catch (_) {}
    }

    final canPlay = firstEp != null;

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
                    ? () => _play(resumeEp ?? firstEp)
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
                        resumeEp != null
                            ? 'استئناف الحلقة ${resumeEp.number}'
                            : 'تشغيل الحلقة 1',
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
          const SizedBox(width: 12),
          Material(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                await _service.removeFromHistory(a.slug);
                if (!mounted) return;
                setState(() => _progress = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Cleared progress'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                child: Icon(Icons.history_toggle_off_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Synopsis ────────────────────────────────────────────────
  Widget _buildSynopsis(ArabicAnimeDetails a) {
    if (a.description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: () =>
            setState(() => _synopsisExpanded = !_synopsisExpanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: Text(
                a.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              secondChild: Text(
                a.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              crossFadeState: _synopsisExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
            if (a.description.length > 200)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _synopsisExpanded ? 'عرض أقل' : 'عرض المزيد',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Genres ─────────────────────────────────────────────────
  Widget _buildGenres(ArabicAnimeDetails a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: a.genres
            .map(
              (g) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  g,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Metadata ─────────────────────────────────────────────────
  Widget _buildMetaGrid(ArabicAnimeDetails a) {
    final entries = <(IconData, String, String)>[];
    if (a.year != null && a.year!.isNotEmpty) {
      entries.add((Icons.calendar_today_rounded, 'سنة العرض', a.year!));
    }
    if (a.status != null && a.status!.isNotEmpty) {
      entries.add((Icons.info_outline_rounded, 'الحالة', a.status!));
    }
    if (a.rating != null && a.rating!.isNotEmpty) {
      entries.add((Icons.star_rounded, 'التقييم', a.rating!));
    }
    if (a.studio != null && a.studio!.isNotEmpty) {
      entries.add((Icons.movie_creation_rounded, 'الاستوديو', a.studio!));
    }
    if (a.episodes.isNotEmpty) {
      entries.add(
          (Icons.playlist_play_rounded, 'عدد الحلقات', '${a.episodes.length}'));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries
            .map(
              (e) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.$1,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${e.$2}: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      e.$3,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Episodes ─────────────────────────────────────────────────
  Widget _buildEpisodesHeader(ArabicAnimeDetails a) {
    final totalChunks = (a.episodes.length / _chunkSize).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Row(
        children: [
          const Icon(Icons.playlist_play_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            'الحلقات (${a.episodes.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (totalChunks > 1)
            Material(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              child: PopupMenuButton<int>(
                offset: const Offset(0, 32),
                color: AppTheme.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                onSelected: (i) =>
                    setState(() => _episodeChunk = i),
                itemBuilder: (_) => List.generate(totalChunks, (i) {
                  final start = i * _chunkSize + 1;
                  final end = ((i + 1) * _chunkSize)
                      .clamp(0, a.episodes.length);
                  return PopupMenuItem<int>(
                    value: i,
                    child: Text(
                      '$start - $end',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_episodeChunk * _chunkSize + 1}'
                        ' - ${((_episodeChunk + 1) * _chunkSize).clamp(0, a.episodes.length)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _episodeTile(ArabicEpisode ep, bool isCurrent) {
    return HoverScale(
      radius: 12,
      scale: 1.03,
      onTap: () => _play(ep),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ep.thumb != null && ep.thumb!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: ep.thumb!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppTheme.bgCard),
                  errorWidget: (_, _, _) =>
                      Container(color: AppTheme.bgCard),
                ),
              ),
            // Gradient
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
            // Play icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? AppTheme.primaryColor
                      : Colors.black.withValues(alpha: 0.5),
                ),
                child: Icon(
                  isCurrent
                      ? Icons.play_arrow_rounded
                      : Icons.play_arrow_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            // Episode number
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EP ${ep.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (isCurrent)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'الحالية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEpisodes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              size: 36),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على حلقات',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Related ──────────────────────────────────────────────────
  Widget _buildRelated(ArabicAnimeDetails a) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.connect_without_contact_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'أنميات مشابهة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HorizontalScroller(
            height: 220,
            itemCount: a.related.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _relatedCard(a.related[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relatedCard(ArabicAnimeCard c) {
    return SizedBox(
      width: 130,
      child: HoverScale(
        radius: 10,
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AnimeArabicDetailsScreen(anime: c),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  child: c.cover != null && c.cover!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: c.cover!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppTheme.bgCard),
                          errorWidget: (_, _, _) =>
                              Container(color: AppTheme.bgCard),
                        )
                      : Container(color: AppTheme.bgCard),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              c.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (c.tag != null && c.tag!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  c.tag!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
