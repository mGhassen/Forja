import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/anime/anime_details_screen.dart';
import 'package:forja/features/anime/anime_player_screen.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/widgets/anime_continue_watching_section.dart';
import 'package:forja/features/asian_drama/asian_drama_details_screen.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/widgets/asian_drama_continue_watching_section.dart';
import 'package:forja/shared/catalog/kit/home/continue_watching_section.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hub_details/hub_engine_auto_play.dart';
import 'package:rust/rust.dart';

/// Host-owned Continue Watching row for catalog shells (`host.continue`).
class CatalogHostContinue extends StatelessWidget {
  const CatalogHostContinue({
    super.key,
    required this.tabId,
    this.tvRowOrder = 1,
  });

  final String tabId;
  final int tvRowOrder;

  @override
  Widget build(BuildContext context) {
    switch (tabId) {
      case 'anime':
        return _AnimeHostContinue(tvRowOrder: tvRowOrder);
      case 'asian_drama':
        return _DramaHostContinue(tvRowOrder: tvRowOrder);
      case 'home':
        return HomeContinueWatchingSection(
          compactTop: false,
          tvRowOrder: tvRowOrder,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _AnimeHostContinue extends StatefulWidget {
  const _AnimeHostContinue({required this.tvRowOrder});
  final int tvRowOrder;

  @override
  State<_AnimeHostContinue> createState() => _AnimeHostContinueState();
}

class _AnimeHostContinueState extends State<_AnimeHostContinue> {
  final _service = AnimeService();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  int? _resumingId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await _service.getWatchHistory();
      if (!mounted) return;
      setState(() {
        _entries = list
            .where((e) {
              final pos = (e['positionMs'] as num?)?.toInt() ?? 0;
              final dur = (e['durationMs'] as num?)?.toInt() ?? 0;
              return isInProgressResume(pos, dur);
            })
            .take(10)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    final animeId = entry['animeId'] as int?;
    if (animeId == null || _resumingId != null) return;
    setState(() => _resumingId = animeId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final cat = (entry['category'] as String?) ?? 'sub';
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000 && isInProgressResume(posMs, durMs)) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }
      final anime = await _service.getDetails(animeId);
      if (!mounted) return;
      final episodes = await _service.getEpisodes(anime);
      if (!mounted) return;
      if (await hubEngineAutoPlayEnabled()) {
        if (!mounted) return;
        final isMovie = (anime.format ?? '').toUpperCase() == 'MOVIE';
        final malId = await _service.resolveMalId(animeId);
        if (!mounted) return;
        await runHubEngineAutoPlay(
          context: context,
          movie: Movie(
            id: -anime.id,
            title: anime.displayTitle,
            posterPath: anime.coverUrl,
            backdropPath: anime.heroBackdrop,
            voteAverage: (anime.averageScore ?? 0) / 10.0,
            releaseDate: anime.seasonYear?.toString() ?? '',
            overview: anime.cleanDescription,
            genres: anime.genres,
            runtime: anime.duration ?? 0,
            mediaType: 'anime',
            numberOfEpisodes: anime.episodes ?? 0,
          ),
          engineCategory: 'anime',
          season: isMovie ? null : 1,
          episode: isMovie ? null : epNum,
          anilistId: animeId,
          malId: malId,
          startPosition: startPosition,
          loadingSubtitle: 'EP $epNum',
          hubEpisodes: isMovie
              ? null
              : [
                  for (final e in episodes)
                    PlayerHubEpisode(
                      number: e.number,
                      title: e.title,
                      notShippedYet: !e.aired,
                    ),
                ],
        );
      } else {
        if (!mounted) return;
        await openAnimePlayer(
          context,
          anime: anime,
          episodeNumber: epNum,
          category: cat,
          allEpisodes: episodes,
          startPosition: startPosition,
          freshResolve: true,
        );
      }
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimeContinueWatchingSection(
      entries: _entries,
      scrollController: _scroll,
      resumingAnimeId: _resumingId,
      onResume: _resume,
      onRemove: (e) async {
        final id = e['animeId'] as int?;
        if (id == null) return;
        await _service.removeFromHistory(id);
        if (mounted) await _reload();
      },
      onOpenDetails: (a) => openAnimeDetails(context, a).then((_) => _reload()),
      tvRowOrder: widget.tvRowOrder,
    );
  }
}

class _DramaHostContinue extends StatefulWidget {
  const _DramaHostContinue({required this.tvRowOrder});
  final int tvRowOrder;

  @override
  State<_DramaHostContinue> createState() => _DramaHostContinueState();
}

class _DramaHostContinueState extends State<_DramaHostContinue> {
  final _service = KissKhService();
  List<Map<String, dynamic>> _entries = const [];
  int? _resumingId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final list = await _service.getWatchHistory();
      if (!mounted) return;
      setState(() {
        _entries = list
            .where((e) {
              final pos = (e['positionMs'] as num?)?.toInt() ?? 0;
              final dur = (e['durationMs'] as num?)?.toInt() ?? 0;
              return isInProgressResume(pos, dur);
            })
            .take(10)
            .toList();
      });
    } catch (_) {}
  }

  KdramaCard _cardFromEntry(Map<String, dynamic> e) {
    return KdramaCard(
      id: (e['id'] as num?)?.toInt() ?? 0,
      title: (e['title'] ?? '').toString(),
      cover: (e['cover'] ?? e['poster'] ?? '').toString(),
      year: e['year']?.toString(),
      tmdbId: (e['tmdbId'] as num?)?.toInt(),
    );
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    final id = (entry['id'] as num?)?.toInt();
    if (id == null || _resumingId != null) return;
    setState(() => _resumingId = id);
    try {
      final card = _cardFromEntry(entry);
      if (!mounted) return;
      await openAsianDramaDetails(context, card);
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsianDramaContinueWatchingSection(
      entries: _entries,
      resumingDramaId: _resumingId,
      onResume: _resume,
      onRemove: (e) async {
        final id = (e['id'] as num?)?.toInt();
        if (id == null) return;
        await _service.removeFromHistory(id);
        if (mounted) await _reload();
      },
      onOpenDetails: (d) =>
          openAsianDramaDetails(context, d).then((_) => _reload()),
      cardFromEntry: _cardFromEntry,
      tvRowOrder: widget.tvRowOrder,
    );
  }
}
