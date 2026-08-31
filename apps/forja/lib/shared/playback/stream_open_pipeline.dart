import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/player/utils.dart';

/// Direct stream open — no playlist/segment sniff (removed with legacy anime path).
enum StreamOpenAction { openDirect }

enum StreamOpenStepResult {
  success,
  openFailed,
  decodeFailed,
  techniqueUnavailable,
}

@immutable
class StreamOpenStep {
  const StreamOpenStep({
    required this.action,
    required this.catalogUrl,
    required this.playUrl,
    required this.reason,
    this.headers,
  });

  final StreamOpenAction action;
  final String catalogUrl;
  final String playUrl;
  final Map<String, String>? headers;
  final String reason;

  String get label => action.name;
}

class StreamOpenPipeline {
  StreamOpenPipeline._({
    required this.catalogUrl,
    required Map<String, String> headers,
  }) : _headers = headers;

  final String catalogUrl;
  final Map<String, String> _headers;
  bool _done = false;

  static Future<StreamOpenPipeline> start({
    required String catalogUrl,
    Map<String, String>? headers,
    String? providerId,
  }) async {
    final catalog = normalizePlaybackStreamUrl(
      playbackStreamIdentityUrl(catalogUrl),
    );
    final hdrs = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: catalog,
      providerId: providerId,
    );
    if (kDebugMode) {
      debugPrint('[OpenPipeline] start $providerId direct');
    }
    return StreamOpenPipeline._(catalogUrl: catalog, headers: hdrs);
  }

  Map<String, String> get identityHeaders => Map.unmodifiable(_headers);

  Future<StreamOpenStep?> next() async {
    if (_done) return null;
    _done = true;
    return StreamOpenStep(
      action: StreamOpenAction.openDirect,
      catalogUrl: catalogUrl,
      playUrl: catalogUrl,
      headers: _headers.isEmpty ? null : _headers,
      reason: 'direct',
    );
  }

  void report(StreamOpenStepResult result) {
    if (kDebugMode && result != StreamOpenStepResult.success) {
      debugPrint('[OpenPipeline] ${result.name}');
    }
  }
}
