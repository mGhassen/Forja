import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:rust/rust.dart';

const _maxMagnetAttempts = 5;

class EpisodeTorrentPlayback {
  final String url;
  final String magnet;
  final int? fileIndex;

  const EpisodeTorrentPlayback({
    required this.url,
    required this.magnet,
    this.fileIndex,
  });
}

/// One text/indexer pass for TV torrent search.
class TorrentSearchPass {
  final String query;
  final int? season;
  final int? episode;

  const TorrentSearchPass({
    required this.query,
    this.season,
    this.episode,
  });
}

/// Pack sets `open.torrentEp: true` → search `Title 05` (not `SxxExx`).
bool catalogOpenTorrentEp(CatalogOpen? open) =>
    open?.extraBool('torrentEp') ?? false;

/// TV torrent query passes.
///
/// [torrentEp] true → `Title 05` / `Title - 05`; false → `Title Sxx` / `SxxExx`.
List<TorrentSearchPass> tvTorrentSearchPasses({
  required String title,
  required int season,
  required int episode,
  bool torrentEp = false,
}) {
  final t = title.trim();
  if (t.isEmpty) return const [];

  if (torrentEp) {
    final ep = episode.toString().padLeft(2, '0');
    return [
      TorrentSearchPass(query: '$t $ep', season: season, episode: episode),
      TorrentSearchPass(query: '$t - $ep', season: season, episode: episode),
    ];
  }

  final s = season.toString().padLeft(2, '0');
  final e = episode.toString().padLeft(2, '0');
  return [
    TorrentSearchPass(query: '$t S$s', season: season),
    TorrentSearchPass(query: '$t S${s}E$e', season: season, episode: episode),
  ];
}

Future<List<TorrentResult>> searchTvTorrents({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
  bool torrentEp = false,
}) async {
  final passes = tvTorrentSearchPasses(
    title: title,
    season: season,
    episode: episode,
    torrentEp: torrentEp,
  );
  if (passes.isEmpty) return const [];

  final settings = SettingsService();
  final jackettConfigured = await settings.isJackettConfigured();
  final jackettBase = jackettConfigured
      ? await settings.getJackettBaseUrl()
      : null;
  final jackettKey =
      jackettConfigured ? await settings.getJackettApiKey() : null;
  final jackettReady =
      jackettBase != null && jackettKey != null && jackettBase.isNotEmpty;

  final prowlarrConfigured = await settings.isProwlarrConfigured();
  final prowlarrBase = prowlarrConfigured
      ? await settings.getProwlarrBaseUrl()
      : null;
  final prowlarrKey =
      prowlarrConfigured ? await settings.getProwlarrApiKey() : null;
  final prowlarrReady =
      prowlarrBase != null && prowlarrKey != null && prowlarrBase.isNotEmpty;

  List<int>? prowlarrIndexerIds;
  if (prowlarrReady) {
    final tagIds = await settings.getProwlarrTagIds();
    if (tagIds.isNotEmpty) {
      final resolved = await ProwlarrService().resolveTagIndexerIds(
        prowlarrBase,
        prowlarrKey,
        tagIds,
      );
      if (resolved.isNotEmpty) prowlarrIndexerIds = resolved;
    }
  }

  final combined = <String, TorrentResult>{};

  for (final pass in passes) {
    final searches = <Future<List<TorrentResult>>>[
      Engine.searchTorrents(
        pass.query,
        imdbId: imdbId,
        season: pass.season,
        episode: pass.episode,
      ).then((list) => list.map(TorrentResult.fromJson).toList()),
    ];
    if (jackettReady) {
      searches.add(
        JackettService().search(jackettBase, jackettKey, pass.query),
      );
    }
    if (prowlarrReady) {
      searches.add(
        ProwlarrService().search(
          prowlarrBase,
          prowlarrKey,
          pass.query,
          indexerIds: prowlarrIndexerIds,
        ),
      );
    }

    debugPrint(
      '[EpSwitch] Searching torrents (${searches.length} backends): '
      '${pass.query}',
    );

    final batches = await Future.wait(searches);
    for (final batch in batches) {
      for (final r in batch) {
        combined[r.magnet] = r;
      }
    }
  }

  return combined.values.toList();
}

Future<EpisodeTorrentPlayback?> resolveEpisodeTorrentPlayback({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
  bool torrentEp = false,
}) async {
  final torrents = await searchTvTorrents(
    title: title,
    season: season,
    episode: episode,
    imdbId: imdbId,
    torrentEp: torrentEp,
  );
  if (torrents.isEmpty) return null;

  torrents.sort((a, b) => b.seeders.compareTo(a.seeders));

  final settings = SettingsService();
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  final localEngine = PlatformPlayback.capabilities.localTorrentEngine;

  final limit = torrents.length < _maxMagnetAttempts
      ? torrents.length
      : _maxMagnetAttempts;

  for (var i = 0; i < limit; i++) {
    final magnet = torrents[i].magnet;
    try {
      final playback = await resolveMagnetForPlayback(
        magnet: magnet,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: localEngine,
        season: season,
        episode: episode,
      );
      if (playback != null) {
        debugPrint(
          '[EpSwitch] Torrent resolved (${i + 1}/$limit via ${playback.sourceLabel})',
        );
        return EpisodeTorrentPlayback(
          url: playback.url,
          magnet: magnet,
          fileIndex: playback.fileIndex,
        );
      }
    } catch (e) {
      if (e is DebridAuthException) rethrow;
      debugPrint('[EpSwitch] Magnet ${i + 1}/$limit failed: $e');
    }
  }

  return null;
}
