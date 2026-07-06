import 'package:api/api/debrid_api.dart';
import 'package:api/playback/playback_profile.dart';
import 'package:api/playback/torrent_stream_service.dart';
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

/// Builds a magnet link from a Stremio addon stream map.
String buildMagnetFromStremioStream(Map<String, dynamic> stream) {
  final infoHash = stream['infoHash'] as String;
  final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
  final dn =
      streamTitle.isNotEmpty ? '&dn=${Uri.encodeComponent(streamTitle)}' : '';

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

  if (stream['url'] != null) {
    return StremioPlayable(
      streamUrl: stream['url'] as String,
      headers: Map<String, String>.from(
        stream['behaviorHints']?['proxyHeaders']?['request'] ?? {},
      ),
      loadingMessage: '',
    );
  }

  if (stream['infoHash'] == null) {
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
  if (useDebrid && debridService != 'None') {
    return 'Resolving with $debridService...';
  }
  return 'Starting Torrent Engine...';
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
  final loadingMessage = stremioResolveLoadingMessage(
    profile: profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );

  try {
    if (useDebrid && debridService != 'None') {
      final debrid = DebridApi();
      final files = await debrid.resolveByService(
        debridService,
        magnet,
        season: season,
        episode: episode,
      );
      if (isCancelled?.call() == true) {
        return StremioResolveFailure(
          error: StremioPlaybackError.cancelled,
          message: '',
        );
      }
      if (files.isNotEmpty) {
        return StremioPlayable(
          streamUrl: files.first.downloadUrl,
          magnetLink: magnet,
          fileIndex: 0,
          loadingMessage: loadingMessage,
        );
      }
    } else if (!profile.localTorrentEngine) {
      return StremioResolveFailure(
        error: StremioPlaybackError.engineUnavailable,
        message: stremioPlaybackErrorMessage(
          StremioPlaybackError.engineUnavailable,
        ),
      );
    } else {
      final url = await TorrentStreamService().streamTorrent(
        magnet,
        season: season,
        episode: episode,
      );
      if (isCancelled?.call() == true) {
        return StremioResolveFailure(
          error: StremioPlaybackError.cancelled,
          message: '',
        );
      }
      if (url != null && url.isNotEmpty) {
        int? fileIndex;
        final idx = Uri.parse(url).queryParameters['index'];
        if (idx != null) fileIndex = int.tryParse(idx);
        return StremioPlayable(
          streamUrl: url,
          magnetLink: magnet,
          fileIndex: fileIndex,
          loadingMessage: loadingMessage,
        );
      }
    }
  } catch (_) {}

  return StremioResolveFailure(
    error: StremioPlaybackError.resolveFailed,
    message: stremioPlaybackErrorMessage(StremioPlaybackError.resolveFailed),
  );
}
