import 'package:rust/rust.dart';

enum StremioPlaybackError {
  requiresDebrid,
  engineUnavailable,
  resolveFailed,
  cancelled,
  unsupported,
}

sealed class StremioResolveOutcome {}

class StremioPlayable extends StremioResolveOutcome {
  final String streamUrl;
  final String? magnetLink;
  final Map<String, String> headers;
  final int? fileIndex;
  final String loadingMessage;

  StremioPlayable({
    required this.streamUrl,
    this.magnetLink,
    this.headers = const {},
    this.fileIndex,
    required this.loadingMessage,
  });
}

class StremioExternalLink extends StremioResolveOutcome {
  final String externalUrl;
  StremioExternalLink(this.externalUrl);
}

class StremioResolveFailure extends StremioResolveOutcome {
  final StremioPlaybackError error;
  final String message;

  StremioResolveFailure({required this.error, required this.message});
}

/// True when [url] is a magnet / torrent link — not a direct HTTP(S) stream.
bool isStremioTorrentUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('magnet:') ||
      u.contains('urn:btih:') ||
      u.endsWith('.torrent');
}

/// Stremio `fileIdx` / legacy `mapIdx` — which file inside the torrent to play.
int? stremioStreamFileIdx(Map<String, dynamic> stream) {
  final raw = stream['fileIdx'] ?? stream['fileIndex'] ?? stream['mapIdx'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

/// Builds a magnet link from a Stremio addon stream map.
///
/// Prefer [infoHash] (+ trackers). If the addon only put a magnet in `url`,
/// return that magnet as-is.
String buildMagnetFromStremioStream(Map<String, dynamic> stream) {
  final infoHash = stream['infoHash']?.toString();
  if (infoHash != null && infoHash.isNotEmpty) {
    final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
    final dn = streamTitle.isNotEmpty
        ? '&dn=${Uri.encodeComponent(streamTitle)}'
        : '';

    final trackerParams = StringBuffer();
    final sources = stream['sources'];
    if (sources is List) {
      for (final src in sources) {
        if (src is String && src.startsWith('tracker:')) {
          final tracker = src.substring('tracker:'.length);
          trackerParams.write('&tr=${Uri.encodeComponent(tracker)}');
        }
      }
    }

    return 'magnet:?xt=urn:btih:$infoHash$dn$trackerParams';
  }

  final url = stream['url']?.toString().trim() ?? '';
  if (isStremioTorrentUrl(url)) return url;

  throw ArgumentError(
    'Stremio stream has neither infoHash nor magnet url',
  );
}

bool isStremioStreamVisible(
  Map<String, dynamic> stream,
  PlaybackProfile profile,
) {
  if (stream['externalUrl'] != null &&
      stream['externalUrl'].toString().isNotEmpty) {
    return true;
  }
  if (stream['url'] != null) return true;
  if (stream['infoHash'] == null) return false;
  return profile.stremioInfoHash != StremioInfoHashPolicy.hidden;
}

List<Map<String, dynamic>> filterStremioStreamsForProfile(
  List<dynamic> streams,
  PlaybackProfile profile,
) {
  return streams
      .whereType<Map>()
      .map((s) => Map<String, dynamic>.from(s))
      .where((s) => isStremioStreamVisible(s, profile))
      .toList();
}

/// HTTP request headers on a Stremio / Nuvio / Forja engine stream map.
///
/// Stremio addons use `behaviorHints.proxyHeaders.request`. Nuvio and Forja
/// put the same map on `headers`. Both are merged; hints win on key clash.
Map<String, String> stremioStreamRequestHeaders(Map<String, dynamic> stream) {
  final out = <String, String>{};
  void add(dynamic raw) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (v == null) return;
      final key = k.toString().trim();
      final val = v.toString().trim();
      if (key.isEmpty || val.isEmpty) return;
      out[key] = val;
    });
  }

  add(stream['headers']);
  final hints = stream['behaviorHints'];
  if (hints is Map) {
    final proxy = hints['proxyHeaders'];
    if (proxy is Map) add(proxy['request']);
  }
  return out;
}

/// Classifies a stream before resolution (for UI / pre-checks).
StremioResolveOutcome? classifyStremioStream(
  Map<String, dynamic> stream,
  PlaybackProfile profile, {
  required bool useDebrid,
  required String debridService,
}) {
  final externalUrl = stream['externalUrl']?.toString();
  if (externalUrl != null && externalUrl.isNotEmpty) {
    return StremioExternalLink(externalUrl);
  }

  final url = stream['url']?.toString();
  // Magnet / .torrent in `url` must go through magnet resolve — never open as
  // a file path (mpv treats relative paths under temp → "File name too long").
  if (url != null && url.isNotEmpty && !isStremioTorrentUrl(url)) {
    return StremioPlayable(
      streamUrl: url,
      headers: stremioStreamRequestHeaders(stream),
      loadingMessage: '',
    );
  }

  final infoHash = stream['infoHash']?.toString();
  final hasInfoHash = infoHash != null && infoHash.isNotEmpty;
  final urlIsMagnet = url != null && isStremioTorrentUrl(url);
  if (!hasInfoHash && !urlIsMagnet) {
    return StremioResolveFailure(
      error: StremioPlaybackError.unsupported,
      message: 'Unsupported stream type.',
    );
  }

  if (!profile.localTorrentEngine &&
      profile.stremioInfoHash == StremioInfoHashPolicy.debridOnly &&
      (!useDebrid || debridService == 'None')) {
    return StremioResolveFailure(
      error: StremioPlaybackError.requiresDebrid,
      message:
          'This stream requires a debrid service on this platform. Enable debrid in Settings.',
    );
  }

  return null;
}

String stremioResolveLoadingMessage({
  required PlaybackProfile profile,
  required bool useDebrid,
  required String debridService,
}) {
  return playbackResolveLabel(
    useDebrid: useDebrid,
    debridService: debridService,
  );
}

String stremioPlaybackErrorMessage(StremioPlaybackError error) {
  switch (error) {
    case StremioPlaybackError.requiresDebrid:
      return 'This stream requires a debrid service on this platform. Enable debrid in Settings.';
    case StremioPlaybackError.engineUnavailable:
      return 'Torrent engine is not available on this platform.';
    case StremioPlaybackError.resolveFailed:
      return 'Failed to resolve stream.';
    case StremioPlaybackError.cancelled:
      return '';
    case StremioPlaybackError.unsupported:
      return 'Unsupported stream type.';
  }
}

/// Resolves a Stremio addon stream to a playable URL (or external link).
Future<StremioResolveOutcome> resolveStremioStream({
  required Map<String, dynamic> stream,
  required PlaybackProfile profile,
  SettingsService? settings,
  int? season,
  int? episode,
  bool Function()? isCancelled,
  void Function(String status)? onStatus,
}) async {
  final svc = settings ?? SettingsService();
  final useDebrid = await svc.useDebridForStreams();
  final debridService = await svc.getDebridService();

  final precheck = classifyStremioStream(
    stream,
    profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );
  if (precheck != null) return precheck;

  final magnet = buildMagnetFromStremioStream(stream);
  final fileIdx = stremioStreamFileIdx(stream);
  final loadingMessage = stremioResolveLoadingMessage(
    profile: profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );

  try {
    final result = await resolveMagnetForPlayback(
      magnet: magnet,
      useDebrid: useDebrid,
      debridService: debridService,
      localTorrentEngine: profile.localTorrentEngine,
      season: season,
      episode: episode,
      fileIdx: fileIdx,
      onStatus: onStatus == null
          ? null
          : (status) => onStatus(status.displayMessage),
    );
    if (isCancelled?.call() == true) {
      return StremioResolveFailure(
        error: StremioPlaybackError.cancelled,
        message: '',
      );
    }
    if (result != null) {
      return StremioPlayable(
        streamUrl: result.url,
        magnetLink: magnet,
        fileIndex: result.fileIndex,
        loadingMessage: loadingMessage,
      );
    }
    if (!profile.localTorrentEngine) {
      return StremioResolveFailure(
        error: StremioPlaybackError.engineUnavailable,
        message: stremioPlaybackErrorMessage(
          StremioPlaybackError.engineUnavailable,
        ),
      );
    }
  } catch (e) {
    final message = e is DebridAuthException
        ? e.toString()
        : debridUserMessage(e, debridService);
    return StremioResolveFailure(
      error: e is DebridAuthException
          ? StremioPlaybackError.requiresDebrid
          : StremioPlaybackError.resolveFailed,
      message: message,
    );
  }

  return StremioResolveFailure(
    error: StremioPlaybackError.resolveFailed,
    message: stremioPlaybackErrorMessage(StremioPlaybackError.resolveFailed),
  );
}
