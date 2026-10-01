import 'package:flutter/material.dart';
import 'package:forja/shared/downloads/download_guards.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:rust/rust.dart';

/// Best-effort auto-resolve for offline download — never opens the player.
///
/// Returns a pick with a downloadable HTTP URL when the Forja race wins.
/// Callers fall back to Sources download mode when this returns null.
Future<EngineAutoPlayPick?> resolveEngineStreamForDownload({
  required BuildContext context,
  required Movie movie,
  required String engineCategory,
  int? season,
  int? episode,
  int? malId,
  String? audioCategory,
  String? loadingSubtitle,
  PlaySession? playSession,
  String? preferredPluginId,
  String? savedStreamUrl,
  Set<String>? selectedPluginIds,
  List<PlayerKitEpisode>? episodes,
}) {
  return runEngineAutoPlay(
    context: context,
    movie: movie,
    engineCategory: engineCategory,
    season: season,
    episode: episode,
    malId: malId,
    audioCategory: audioCategory,
    loadingSubtitle: loadingSubtitle ?? 'Finding a stream…',
    playSession: playSession,
    preferredPluginId: preferredPluginId,
    savedStreamUrl: savedStreamUrl,
    selectedPluginIds: selectedPluginIds,
    episodes: episodes,
    hubEpisodeNumber: episode,
    downloadOnly: true,
  );
}

/// URL + headers from an [EngineAutoPlayPick], if downloadable.
({String url, Map<String, String>? headers, String? sourceName})?
    downloadableUrlFromAutoPlayPick(EngineAutoPlayPick pick) {
  if (pick.sources.isNotEmpty) {
    final primary = pick.sources.first;
    final url = primary.url.trim();
    if (isDownloadableHttpUrl(url)) {
      return (
        url: url,
        headers: primary.headers,
        sourceName: primary.title.isNotEmpty
            ? primary.title
            : (pick.pluginId.isNotEmpty ? pick.pluginId : 'Stream'),
      );
    }
  }

  final stream = pick.stream;
  final url = (stream['url'] ?? stream['streamUrl'] ?? '').toString().trim();
  if (!isDownloadableHttpUrl(url)) return null;

  Map<String, String>? headers;
  final rawHeaders = stream['headers'] ?? stream['behaviorHints']?['headers'];
  if (rawHeaders is Map) {
    headers = {
      for (final e in rawHeaders.entries)
        if (e.key.toString().trim().isNotEmpty &&
            e.value.toString().trim().isNotEmpty)
          e.key.toString(): e.value.toString(),
    };
  }

  final name = (stream['name'] ??
          stream['title'] ??
          stream['_addonName'] ??
          pick.pluginId)
      .toString();
  return (
    url: url,
    headers: headers,
    sourceName: name.isNotEmpty ? name : 'Stream',
  );
}
