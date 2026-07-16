// AnimeSlayer details screen — mirrors `AnimeDetailsScreen` visual style.
// Backdrop blur + poster + chips + expandable synopsis + episode grid +
// related rail. Bound to `AnimeArabicService` / `ArabicAnimeDetails`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime_arabic/catalog/anime_arabic_service.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/hub/hub_catalog_section.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'package:forja/shared/widgets/hub_details/hub_details_play_row.dart';
import 'package:forja/shared/widgets/media_details_body.dart';
import 'package:forja/shared/widgets/tv_season_episode_picker.dart';
import 'anime_arabic_player_screen.dart';

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
  final FocusNode _heroPlayFocus = FocusNode(debugLabel: 'anime-arabic-details-play');

  ArabicAnimeDetails? _details;
  Map<String, dynamic>? _progress;
  bool _loading = true;
  bool _synopsisExpanded = false;
  String? _error;
  int _selectedEpisode = 1;

  @override
  void initState() {
    super.initState();
    _load();
    AnimeArabicService.watchHistoryRevision.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _heroPlayFocus.dispose();
    AnimeArabicService.watchHistoryRevision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  bool get _tvNav => ShellScope.inputPolicyOf(context).useFocusableMoodChips;

  void _revealedDetailsHeroPlayFocus() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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

  void _playSelected(ArabicAnimeDetails a) {
    ArabicEpisode? ep;
    for (final e in a.episodes) {
      if (e.number == _selectedEpisode) {
        ep = e;
        break;
      }
    }
    if (ep == null) return;
    _play(ep);
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        final scaffold = _buildScaffold();
        return _tvNav
            ? MediaDetailsTvScope(
                heroPlayFocus: _heroPlayFocus,
                scrollController: _scroll,
                child: scaffold,
              )
            : scaffold;
      },
    );
  }

  Widget _buildScaffold() {
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
                      color: ForjaShellColors.sectionAccent,
                    ),
                  )
                else
                  _buildContent(),
              ],
            ),
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
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (_, _) => Container(color: AppTheme.bgCard),
            errorWidget: (_, _, _) => Container(color: AppTheme.bgCard),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgDark.withValues(alpha: 0.5),
                  AppTheme.bgDark.withValues(alpha: 0.78),
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
                color: ForjaShellColors.sectionAccent, size: 48),
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
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
    final heroFocusUp = _revealedDetailsHeroPlayFocus;
    final showEpisodes = d.episodes.isNotEmpty;
    final relatedOrder = showEpisodes ? 1 : 0;

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
        if (d.genres.isNotEmpty) SliverToBoxAdapter(child: _buildGenres(d)),
        SliverToBoxAdapter(child: _buildMetaGrid(d)),
        SliverToBoxAdapter(
          child: MediaDetailsBody(
            backgroundColor: AppTheme.bgDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showEpisodes)
                  MediaDetailsBody.padContent(
                    context,
                    TvSeasonEpisodePicker(
                      tmdbId: widget.anime.slug.hashCode,
                      seasonCount: 1,
                      selectedSeason: 1,
                      selectedEpisode: _selectedEpisode,
                      isLoadingSeason: false,
                      seasonData: null,
                      watchedEpisodes: const {},
                      fallbackPosterPath: d.displayCover,
                      customEpisodesBySeason: _episodeMaps(d),
                      onSeasonSelected: (_) {},
                      onEpisodeSelected: (ep) {
                        setState(() => _selectedEpisode = ep);
                      },
                      onToggleWatched: (_, _) {},
                      tvTabId: _tvNav ? MediaDetailsTv.tabId : null,
                      tvSeasonRowId: 'seasons',
                      tvEpisodeRowId: 'episodes',
                      tvRowOrderBase: 0,
                      tvFocusUp: heroFocusUp,
                    ),
                  )
                else
                  MediaDetailsBody.padContent(
                    context,
                    Text(
                      'لم يتم العثور على حلقات',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (d.related.isNotEmpty) ...[
                  const SizedBox(height: DetailsTokens.sectionSpacing),
                  _buildRelated(
                    d,
                    tvRowOrder: relatedOrder,
                    tvFocusUp: showEpisodes ? null : heroFocusUp,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Map<int, List<Map<String, dynamic>>> _episodeMaps(ArabicAnimeDetails d) {
    return {
      1: d.episodes
          .map(
            (e) => {
              'episode_number': e.number,
              'name': e.title,
              if (e.thumb != null && e.thumb!.isNotEmpty) 'still_path': e.thumb,
            },
          )
          .toList(),
    };
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
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // ─── Action row (Play / Resume) ──────────────────────────────
  Widget _buildActionRow(ArabicAnimeDetails a) {
    final resumeEpNum = (_progress?['episodeNumber'] as int?);
    final canResumeSelected =
        _progress != null && resumeEpNum == _selectedEpisode;
    ArabicEpisode? selectedEp;
    for (final e in a.episodes) {
      if (e.number == _selectedEpisode) {
        selectedEp = e;
        break;
      }
    }

    final canPlay = selectedEp != null;
    final heroFocusUp = _revealedDetailsHeroPlayFocus;

    final row = Row(
      children: [
        HubDetailsPlayRow(
          label: canResumeSelected
              ? 'استئناف الحلقة $_selectedEpisode'
              : 'تشغيل الحلقة $_selectedEpisode',
          enabled: canPlay,
          onPlay: canPlay ? () => _playSelected(a) : null,
          focusNode: _heroPlayFocus,
          tvTabId: _tvNav ? MediaDetailsTv.tabId : null,
          tvItemIndex: 0,
        ),
        if (_progress != null) ...[
          const SizedBox(width: 12),
          HeroPillIconGroup(
            tvTabId: _tvNav ? MediaDetailsTv.tabId : null,
            tvRowId: _tvNav ? MediaDetailsTv.heroRowId : null,
            tvItemIndexStart: 1,
            slots: [
              HeroPillIconSlot(
                icon: Icons.history_toggle_off_rounded,
                tooltip: 'Clear progress',
                onTap: () async {
                  await _service.removeFromHistory(a.slug);
                  if (!mounted) return;
                  setState(() => _progress = null);
                  ForjaToast.success(
                    'Cleared progress',
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: _tvNav
          ? DetailsHeroTvActionScope(
              tabId: MediaDetailsTv.tabId,
              itemCount: _progress != null ? 2 : 1,
              onFocusUp: heroFocusUp,
              child: row,
            )
          : row,
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
                    color: ForjaShellColors.cinematic.textPrimary,
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
                decoration: shellChipDecoration(selected: false, radius: 20),
                child: Text(
                  g,
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textSecondary,
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

  Widget _buildRelated(
    ArabicAnimeDetails a, {
    required int tvRowOrder,
    VoidCallback? tvFocusUp,
  }) {
    return HubCatalogSection<ArabicAnimeCard>(
      title: 'أنميات مشابهة',
      items: a.related,
      tvTabId: _tvNav ? MediaDetailsTv.tabId : null,
      tvRowId: 'related',
      tvRowOrder: tvRowOrder,
      tvFocusUp: tvFocusUp,
      cardBuilder: (context, card, index) => HubPosterCard(
        imageUrl: card.cover ?? '',
        title: card.title,
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AnimeArabicDetailsScreen(anime: card),
            ),
          );
        },
        listIndex: index,
        tvTabId: _tvNav ? MediaDetailsTv.tabId : null,
        tvRowId: 'related',
      ),
    );
  }
}
