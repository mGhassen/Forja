import 'dart:convert';

import 'isolate_runner.dart';

/// Rust-backed anime stream extractors (AllAnime, Miruro pipe, AnimeRealms, adult).
Future<Map<String, dynamic>> animeExtractorRequest(
  Map<String, dynamic> payload,
) async {
  final raw = await runAnimeExtractorJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return decoded;
}

/// Provider names exposed by AllAnime (matches Rust `KNOWN_PROVIDERS`).
///
/// `Default` is a Forja alias that tries Yt-mp4 → S-mp4 → Luf-Mp4.
const allAnimeKnownProviders = [
  'Default',
  'Yt-mp4',
  'S-mp4',
  'Luf-Mp4',
];

/// Miruro pipe keys (matches Rust `KNOWN_PROVIDERS`).
const miruroKnownProviders = [
  'zoro',
  'kiwi',
  'bee',
  'hop',
  'bonk',
  'ally',
  'moo',
  'animedunya',
  'arc',
  'jet',
  'bun',
  'kuz',
  'telli',
];

const miruroUpstreamSources = <String, String>{
  'kiwi': 'AnimePahe',
  'ally': 'AllManga',
  'bonk': 'AnimeDao',
  'bee': 'AniKoto',
  'moo': 'AnimeGG',
  'hop': 'Miruro',
  'arc': 'Miruro internal',
  'zoro': 'HiAnime',
  'jet': 'Miruro internal',
  'animedunya': 'AnimeDunya',
  'bun': 'Miruro',
  'kuz': 'Miruro',
  'telli': 'Miruro',
};

/// AnimeRealms upstream shut down (`animerealms.org` is a parked lander;
/// `animerealms.com` is a collectibles storefront). Kept empty so old settings
/// keys drop out via [SettingsService.mergeProviderOrder].
const animeRealmsDefaultProviders = <String>[];

class AnimeExtractorTrack {
  final String url;
  final String label;
  final String language;
  final bool isDefault;

  const AnimeExtractorTrack({
    required this.url,
    required this.label,
    this.language = '',
    this.isDefault = false,
  });

  factory AnimeExtractorTrack.fromJson(Map<String, dynamic> j) =>
      AnimeExtractorTrack(
        url: (j['url'] ?? '') as String,
        label: (j['label'] ?? 'Unknown') as String,
        language: (j['language'] ?? '') as String,
        isDefault: j['is_default'] == true || j['isDefault'] == true,
      );
}

class AnimeExtractorStreamResult {
  final String url;
  final String referer;
  final String origin;
  final List<AnimeExtractorTrack> tracks;
  final String provider;
  final String? streamLabel;

  const AnimeExtractorStreamResult({
    required this.url,
    required this.referer,
    required this.origin,
    this.tracks = const [],
    this.provider = '',
    this.streamLabel,
  });

  factory AnimeExtractorStreamResult.fromJson(Map<String, dynamic> j) =>
      AnimeExtractorStreamResult(
        url: (j['url'] ?? '') as String,
        referer: (j['referer'] ?? '') as String,
        origin: (j['origin'] ?? '') as String,
        provider: (j['provider'] ?? '') as String,
        streamLabel: j['stream_label'] as String? ?? j['streamLabel'] as String?,
        tracks: ((j['tracks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AnimeExtractorTrack.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

Future<AnimeExtractorStreamResult?> allAnimeExtractWithProvider({
  required List<String> titleCandidates,
  required int episodeNumber,
  required String category,
  required String provider,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'allanime_sources',
    'title_candidates': titleCandidates,
    'episode_number': episodeNumber,
    'category': category,
    'provider': provider,
  });
  final result = decoded['result'];
  if (result is! Map) return null;
  return AnimeExtractorStreamResult.fromJson(result.cast<String, dynamic>());
}

Future<List<AnimeExtractorStreamResult>> miruroExtractAllStreams({
  required int anilistId,
  required int episodeNumber,
  required String category,
  required String provider,
  String? webviewBody,
  String? webviewXObfuscated,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'miruro_resolve',
    'anilist_id': anilistId,
    'episode_number': episodeNumber,
    'category': category,
    'provider': provider,
    if (webviewBody != null) 'webview_body': webviewBody,
    if (webviewXObfuscated != null) 'webview_x_obfuscated': webviewXObfuscated,
  });
  final streams = decoded['streams'];
  if (streams is! List) return const [];
  return streams
      .whereType<Map>()
      .map((e) => AnimeExtractorStreamResult.fromJson(e.cast<String, dynamic>()))
      .toList();
}

/// When Rust returns [cf_blocked], fetch [pipeUrl] via WebView then retry.
///
/// Miruro needs two pipes (episodes → sources). Each WebView body is tagged
/// with [webview_pipe_path] so Rust never reuses episodes JSON as sources.
Future<MiruroRustResolve> miruroResolveWithCfFallback({
  required int anilistId,
  required int episodeNumber,
  required String category,
  required String provider,
  required Future<({int status, String body, String? xObf})?> Function(String pipeUrl)
      fetchPipeViaWebView,
}) async {
  Future<Map<String, dynamic>> resolve({
    String? webviewBody,
    String? webviewXObf,
    String? webviewPipePath,
  }) {
    return animeExtractorRequest({
      'action': 'miruro_resolve',
      'anilist_id': anilistId,
      'episode_number': episodeNumber,
      'category': category,
      'provider': provider,
      if (webviewBody != null) 'webview_body': webviewBody,
      if (webviewXObf != null) 'webview_x_obfuscated': webviewXObf,
      if (webviewPipePath != null) 'webview_pipe_path': webviewPipePath,
    });
  }

  var decoded = await resolve();
  // At most two CF hops: episodes pipe, then sources pipe.
  for (var hop = 0; hop < 2 && decoded['cf_blocked'] == true; hop++) {
    final pipeUrl = decoded['pipe_url'] as String?;
    if (pipeUrl == null || pipeUrl.isEmpty) break;
    final pipePath = (decoded['pipe_path'] as String?)?.trim();
    final viaBrowser = await fetchPipeViaWebView(pipeUrl);
    if (viaBrowser == null || viaBrowser.status != 200) break;
    decoded = await resolve(
      webviewBody: viaBrowser.body,
      webviewXObf: viaBrowser.xObf,
      webviewPipePath: (pipePath != null && pipePath.isNotEmpty)
          ? pipePath
          : (hop == 0 ? 'episodes' : 'sources'),
    );
  }
  final streams = decoded['streams'];
  if (streams is! List) {
    return MiruroRustResolve(streams: const [], cfBlocked: decoded['cf_blocked'] == true);
  }
  return MiruroRustResolve(
    streams: streams
        .whereType<Map>()
        .map((e) => AnimeExtractorStreamResult.fromJson(e.cast<String, dynamic>()))
        .toList(),
    cfBlocked: false,
  );
}

class MiruroRustResolve {
  final List<AnimeExtractorStreamResult> streams;
  final bool cfBlocked;

  const MiruroRustResolve({required this.streams, required this.cfBlocked});
}

Future<AnimeExtractorStreamResult?> animeRealmsExtractWithProvider({
  required int anilistId,
  required int episodeNumber,
  required String provider,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'animerealms_streams',
    'anilist_id': anilistId,
    'episode_number': episodeNumber,
    'provider': provider,
  });
  final result = decoded['result'];
  if (result is! Map) return null;
  return AnimeExtractorStreamResult.fromJson(result.cast<String, dynamic>());
}

Future<AnimeExtractorStreamResult?> hentainiExtract({
  required List<String> titleCandidates,
  required int episode,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'hentaini_streams',
    'title_candidates': titleCandidates,
    'episode': episode,
  });
  final result = decoded['result'];
  if (result is! Map) return null;
  return AnimeExtractorStreamResult.fromJson(result.cast<String, dynamic>());
}

Future<AnimeExtractorStreamResult?> watchHentaiExtract({
  required List<String> titleCandidates,
  required int episode,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'watchhentai_streams',
    'title_candidates': titleCandidates,
    'episode': episode,
  });
  final result = decoded['result'];
  if (result is! Map) return null;
  return AnimeExtractorStreamResult.fromJson(result.cast<String, dynamic>());
}

// ─── Anikoto catalog + direct embed resolve (Rust `anime/resolve`) ───

class AnikotoEpisodeData {
  final int id;
  final int number;
  final String title;
  final String embedId;

  const AnikotoEpisodeData({
    required this.id,
    required this.number,
    required this.title,
    required this.embedId,
  });

  factory AnikotoEpisodeData.fromJson(Map<String, dynamic> j) =>
      AnikotoEpisodeData(
        id: (j['id'] as num?)?.toInt() ?? 0,
        number: (j['number'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '') as String,
        embedId: (j['embed_id'] ?? j['episode_embed_id'] ?? '') as String,
      );
}

class AnikotoSeriesData {
  final int id;
  final List<AnikotoEpisodeData> episodes;

  const AnikotoSeriesData({required this.id, required this.episodes});

  factory AnikotoSeriesData.fromJson(Map<String, dynamic> j) =>
      AnikotoSeriesData(
        id: (j['id'] as num?)?.toInt() ?? 0,
        episodes: ((j['episodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AnikotoEpisodeData.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

Future<AnikotoSeriesData?> anikotoResolveSeries({
  required int anilistId,
  required String titleEnglish,
  required String titleRomaji,
  int expectedEpisodes = 0,
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'anikoto_resolve',
    'anilist_id': anilistId,
    'title_english': titleEnglish,
    'title_romaji': titleRomaji,
    'expected_episodes': expectedEpisodes,
  });
  final series = decoded['series'];
  if (series is! Map) return null;
  return AnikotoSeriesData.fromJson(series.cast<String, dynamic>());
}

Future<AnimeExtractorStreamResult?> directEmbedExtract({
  required String embedUrl,
  String referer = 'https://www.enma.lol/',
}) async {
  final decoded = await animeExtractorRequest({
    'action': 'direct_embed_extract',
    'embed_url': embedUrl,
    'referer': referer,
  });
  final result = decoded['result'];
  if (result is! Map) return null;
  return AnimeExtractorStreamResult.fromJson(result.cast<String, dynamic>());
}

Future<bool> probeStreamUrlRust(
  String url,
  Map<String, String> headers,
) async {
  final decoded = await animeExtractorRequest({
    'action': 'probe_stream_url',
    'url': url,
    'headers': headers,
  });
  return decoded['reachable'] == true;
}

String miruroUpstreamLabel(String pipeKey) =>
    miruroUpstreamSources[pipeKey.toLowerCase()] ?? pipeKey;
