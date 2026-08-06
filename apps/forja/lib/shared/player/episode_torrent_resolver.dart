import 'package:flutter/foundation.dart';
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

Future<List<TorrentResult>> searchTvTorrents({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
}) async {
  final s = season.toString().padLeft(2, '0');
  final e = episode.toString().padLeft(2, '0');
  final seasonQuery = '$title S$s';
  final episodeQuery = '$title S${s}E$e';

  final settings = SettingsService();
  final seasonSearches = <Future<List<TorrentResult>>>[
    Engine.searchTorrents(
      seasonQuery,
      imdbId: imdbId,
      season: season,
    ).then((list) => list.map(TorrentResult.fromJson).toList()),
  ];
  final episodeSearches = <Future<List<TorrentResult>>>[
    Engine.searchTorrents(
      episodeQuery,
      imdbId: imdbId,
      season: season,
      episode: episode,
    ).then((list) => list.map(TorrentResult.fromJson).toList()),
  ];

  if (await settings.isJackettConfigured()) {
    final baseUrl = await settings.getJackettBaseUrl();
    final apiKey = await settings.getJackettApiKey();
    if (baseUrl != null && apiKey != null) {
      final jackett = JackettService();
      seasonSearches.add(jackett.search(baseUrl, apiKey, seasonQuery));
      episodeSearches.add(jackett.search(baseUrl, apiKey, episodeQuery));
    }
  }

  if (await settings.isProwlarrConfigured()) {
    final baseUrl = await settings.getProwlarrBaseUrl();
    final apiKey = await settings.getProwlarrApiKey();
    if (baseUrl != null && apiKey != null) {
      final prowlarr = ProwlarrService();
      List<int>? indexerIds;
      final tagIds = await settings.getProwlarrTagIds();
      if (tagIds.isNotEmpty) {
        final resolved =
            await prowlarr.resolveTagIndexerIds(baseUrl, apiKey, tagIds);
        if (resolved.isNotEmpty) indexerIds = resolved;
      }
      seasonSearches.add(
        prowlarr.search(baseUrl, apiKey, seasonQuery, indexerIds: indexerIds),
      );
      episodeSearches.add(
        prowlarr.search(baseUrl, apiKey, episodeQuery, indexerIds: indexerIds),
      );
    }
  }

  final backendCount = seasonSearches.length;
  debugPrint(
    '[EpSwitch] Searching torrents ($backendCount queries): $episodeQuery',
  );

  final seasonBatches = await Future.wait(seasonSearches);
  final episodeBatches = await Future.wait(episodeSearches);

  final combined = <String, TorrentResult>{};

  for (final batch in seasonBatches) {
    final filtered = (await Engine.filterTorrents(
      batch.map((r) => r.toJson()).toList(),
      title,
      requiredSeason: season,
    ))
        .map(TorrentResult.fromJson)
        .toList();
    for (final r in filtered) {
      combined[r.magnet] = r;
    }
  }

  for (final batch in episodeBatches) {
    final filtered = (await Engine.filterTorrents(
      batch.map((r) => r.toJson()).toList(),
      title,
      requiredSeason: season,
      requiredEpisode: episode,
    ))
        .map(TorrentResult.fromJson)
        .toList();
    for (final r in filtered) {
      combined[r.magnet] = r;
    }
  }

  return combined.values.toList();
}

Future<EpisodeTorrentPlayback?> resolveEpisodeTorrentPlayback({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
}) async {
  final torrents = await searchTvTorrents(
    title: title,
    season: season,
    episode: episode,
    imdbId: imdbId,
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
