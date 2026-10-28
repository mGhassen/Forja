import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

const _maxMagnetAttempts = 5;

final _seasonOrdinal = RegExp(
  r'(\d+)(?:st|nd|rd|th)\s+season',
  caseSensitive: false,
);
final _seasonWritten = RegExp(r'\bseason\s*(\d+)\b', caseSensitive: false);
final _stripSeasonPart = RegExp(
  r'\s+(?:'
  r'(?:\d+(?:st|nd|rd|th)\s+)?season(?:\s+\d+)?'
  r'(?:\s+part\s+\d+(?:\s*[&+]\s*\d+)?)?'
  r'|part\s+\d+(?:\s*[&+]\s*\d+)?'
  r'|final\s+season'
  r'|cour\s*\d+'
  r')\s*$',
  caseSensitive: false,
);
final _sceneSxe = RegExp(
  r's(\d{1,2})\s*[._\-\s]*e(\d{1,3})',
  caseSensitive: false,
);
final _sceneSxeRange = RegExp(
  r's(\d{1,2})\s*[._\-\s]*e(\d{1,3})\s*[._\-\s]*-\s*[._\-\s]*e?(\d{1,3})',
  caseSensitive: false,
);

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

  const TorrentSearchPass({required this.query, this.season, this.episode});
}

/// Pack sets `open.torrentEp: true` → absolute ep + franchise `SxxExx`.
bool metaOpenTorrentEp(MetaOpen? open) => open?.extraBool('torrentEp') ?? false;

/// Strip trailing season / part / cour markers so indexers AND-match.
String torrentSearchBaseTitle(String title) {
  var t = title.trim();
  if (t.isEmpty) return t;
  for (var i = 0; i < 4; i++) {
    final next = t.replaceFirst(_stripSeasonPart, '').trim();
    if (next == t || next.isEmpty) break;
    t = next;
  }
  return t;
}

/// Franchise season for indexers: chip `Season 4` → 4, else title `4th Season`,
/// else host [season] (media-local).
int torrentSearchSeason({
  required int season,
  String? seasonLabel,
  String? title,
}) {
  final code = sourcesSeasonCodeFromLabel(seasonLabel);
  if (code != null && code.startsWith('S')) {
    final n = int.tryParse(code.substring(1));
    if (n != null && n > 0) return n;
  }
  final blob = (title ?? '').trim();
  if (blob.isNotEmpty) {
    final ordinal = _seasonOrdinal.firstMatch(blob);
    if (ordinal != null) {
      final n = int.tryParse(ordinal.group(1) ?? '');
      if (n != null && n > 0) return n;
    }
    final written = _seasonWritten.firstMatch(blob);
    if (written != null) {
      final n = int.tryParse(written.group(1) ?? '');
      if (n != null && n > 0) return n;
    }
  }
  return season;
}

/// Drop rows whose scene `SxxExx` disagrees with the target. Keep absolute /
/// untagged names (common for single-cour fansubs).
List<TorrentResult> filterTorrentsForEpisode(
  Iterable<TorrentResult> rows, {
  required int season,
  required int episode,
}) {
  return [
    for (final r in rows)
      if (_torrentNameMatchesEpisode(r.name, season: season, episode: episode))
        r,
  ];
}

bool _torrentNameMatchesEpisode(
  String name, {
  required int season,
  required int episode,
}) {
  final range = _sceneSxeRange.firstMatch(name);
  if (range != null) {
    final ps = int.tryParse(range.group(1) ?? '') ?? -1;
    final a = int.tryParse(range.group(2) ?? '') ?? -1;
    final b = int.tryParse(range.group(3) ?? '') ?? -1;
    if (ps != season) return false;
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    return episode >= lo && episode <= hi;
  }
  final single = _sceneSxe.firstMatch(name);
  if (single != null) {
    final ps = int.tryParse(single.group(1) ?? '') ?? -1;
    final pe = int.tryParse(single.group(2) ?? '') ?? -1;
    return ps == season && pe == episode;
  }
  return true;
}

/// TV torrent query passes.
///
/// [torrentEp] true → short base + `SxxExx` (chip/title season), then
/// `Title 05` / `Title - 05`. False → `Title Sxx` / `SxxExx` (host season).
List<TorrentSearchPass> tvTorrentSearchPasses({
  required String title,
  required int season,
  required int episode,
  bool torrentEp = false,
  String? seasonLabel,
}) {
  final raw = title.trim();
  if (raw.isEmpty) return const [];

  if (torrentEp) {
    final base = torrentSearchBaseTitle(raw);
    final t = base.isNotEmpty ? base : raw;
    final sNum = torrentSearchSeason(
      season: season,
      seasonLabel: seasonLabel,
      title: raw,
    );
    final ss = sNum.toString().padLeft(2, '0');
    final ep = episode.toString().padLeft(2, '0');
    return [
      TorrentSearchPass(query: '$t S${ss}E$ep', season: sNum, episode: episode),
      TorrentSearchPass(query: '$t $ep', season: sNum, episode: episode),
      TorrentSearchPass(query: '$t - $ep', season: sNum, episode: episode),
    ];
  }

  final s = season.toString().padLeft(2, '0');
  final e = episode.toString().padLeft(2, '0');
  return [
    TorrentSearchPass(query: '$raw S$s', season: season),
    TorrentSearchPass(query: '$raw S${s}E$e', season: season, episode: episode),
  ];
}

Future<List<TorrentResult>> searchTvTorrents({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
  bool torrentEp = false,
  String? seasonLabel,
}) async {
  final passes = tvTorrentSearchPasses(
    title: title,
    season: season,
    episode: episode,
    torrentEp: torrentEp,
    seasonLabel: seasonLabel,
  );
  if (passes.isEmpty) return const [];

  final settings = SettingsService();
  final jackettConfigured = await settings.isJackettConfigured();
  final jackettBase = jackettConfigured
      ? await settings.getJackettBaseUrl()
      : null;
  final jackettKey = jackettConfigured
      ? await settings.getJackettApiKey()
      : null;
  final jackettReady =
      jackettBase != null && jackettKey != null && jackettBase.isNotEmpty;

  final prowlarrConfigured = await settings.isProwlarrConfigured();
  final prowlarrBase = prowlarrConfigured
      ? await settings.getProwlarrBaseUrl()
      : null;
  final prowlarrKey = prowlarrConfigured
      ? await settings.getProwlarrApiKey()
      : null;
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
  final filterSeason = passes.first.season ?? season;

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

  return filterTorrentsForEpisode(
    combined.values,
    season: filterSeason,
    episode: episode,
  );
}

Future<EpisodeTorrentPlayback?> resolveEpisodeTorrentPlayback({
  required String title,
  required int season,
  required int episode,
  String? imdbId,
  bool torrentEp = false,
  String? seasonLabel,
}) async {
  final torrents = await searchTvTorrents(
    title: title,
    season: season,
    episode: episode,
    imdbId: imdbId,
    torrentEp: torrentEp,
    seasonLabel: seasonLabel,
  );
  if (torrents.isEmpty) return null;

  torrents.sort((a, b) => b.seeders.compareTo(a.seeders));

  final localEngine = PlatformPlayback.capabilities.localTorrentEngine;

  final limit = torrents.length < _maxMagnetAttempts
      ? torrents.length
      : _maxMagnetAttempts;

  for (var i = 0; i < limit; i++) {
    final magnet = torrents[i].magnet;
    try {
      final playback = await resolveMagnetForPlayback(
        magnet: magnet,
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
