import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/playback/stream_media_classifier.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Leaf open technique (Stage 3).
enum StreamOpenAction { openDirect, openPngStrip }

/// Outcome of executing a step - feeds Stage 6 re-branch.
enum StreamOpenStepResult {
  success,
  openFailed,
  decodeFailed,
  techniqueUnavailable,
}

/// One decided play step from the pipeline.
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

/// Single owner of the stream open path (RFC-045).
///
/// Stages: identity → classify → technique → open-once (caller) → observe
/// (caller) → report / re-branch.
class StreamOpenPipeline {
  StreamOpenPipeline._({
    required this.catalogUrl,
    required Map<String, String> headers,
    required this.providerId,
    required this.pngMode,
    required this.mediaClass,
    required this.isHls,
    required this.isProgressive,
    String Function(String url, Map<String, String> headers)? buildStripProxy,
  }) : _headers = headers,
       _buildStripProxy = buildStripProxy;

  final String catalogUrl;
  final String? providerId;
  final AnimePngStripMode pngMode;
  final StreamMediaClass mediaClass;
  final bool isHls;
  final bool isProgressive;
  final Map<String, String> _headers;
  final String Function(String url, Map<String, String> headers)?
  _buildStripProxy;

  final Set<StreamOpenAction> _tried = {};
  StreamOpenStep? _current;
  bool _openFailed = false;
  bool _decodeFailed = false;

  /// Stage 1–2: identity headers + byte classify.
  static Future<StreamOpenPipeline> start({
    required String catalogUrl,
    Map<String, String>? headers,
    String? providerId,
    @visibleForTesting StreamMediaClass? mediaClassOverride,
    @visibleForTesting
    String Function(String url, Map<String, String> headers)? buildStripProxy,
  }) async {
    final catalog = normalizePlaybackStreamUrl(
      playbackStreamIdentityUrl(catalogUrl),
    );
    final hdrs = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: catalog,
      providerId: providerId,
    );
    final mode = ProviderRuntimeConfig.instance
        .animePlaybackProfile(providerId ?? '')
        .pngStrip;

    final lower = catalog.toLowerCase();
    final isHls = urlLooksLikeHls(catalog);
    final isProgressive =
        !isHls &&
        (lower.contains('.mp4') ||
            lower.contains('.mkv') ||
            lower.contains('.webm') ||
            lower.contains('.mpd'));

    StreamMediaClass mediaClass = StreamMediaClass.unknown;
    if (mediaClassOverride != null) {
      mediaClass = mediaClassOverride;
    } else if (isHls && mode != AnimePngStripMode.never) {
      mediaClass = await StreamMediaClassifier.classifyPlaylist(catalog, hdrs);
    } else if (isHls) {
      mediaClass = StreamMediaClass.plainMedia;
    } else if (isProgressive) {
      mediaClass = StreamMediaClass.plainMedia;
    }

    if (kDebugMode) {
      debugPrint(
        '[OpenPipeline] start $providerId class=${mediaClass.name} '
        'hls=$isHls mode=${mode.name}',
      );
    }

    return StreamOpenPipeline._(
      catalogUrl: catalog,
      headers: hdrs,
      providerId: providerId,
      pngMode: mode,
      mediaClass: mediaClass,
      isHls: isHls,
      isProgressive: isProgressive,
      buildStripProxy: buildStripProxy,
    );
  }

  /// Canonical identity headers from Stage 1.
  Map<String, String> get identityHeaders => Map.unmodifiable(_headers);

  /// Next technique, or `null` when exhausted / unplayable class.
  Future<StreamOpenStep?> next() async {
    if (mediaClass == StreamMediaClass.imageNoTs ||
        mediaClass == StreamMediaClass.httpBlocked) {
      if (kDebugMode) {
        debugPrint(
          '[OpenPipeline] exhaust $providerId - class=${mediaClass.name}',
        );
      }
      return null;
    }

    final action = _decide();
    if (action == null) {
      if (kDebugMode) {
        debugPrint('[OpenPipeline] exhausted $providerId');
      }
      return null;
    }
    _tried.add(action);
    final step = await _materialize(action);
    if (step == null) {
      if (kDebugMode) {
        debugPrint('[OpenPipeline] $action unavailable');
      }
      // Mark failure so we can re-branch (e.g. strip down → direct).
      _openFailed = true;
      return next();
    }
    _current = step;
    if (kDebugMode) {
      debugPrint('[OpenPipeline] branch → ${step.label} (${step.reason})');
    }
    return step;
  }

  void report(StreamOpenStepResult result) {
    switch (result) {
      case StreamOpenStepResult.success:
        break;
      case StreamOpenStepResult.openFailed:
      case StreamOpenStepResult.techniqueUnavailable:
        _openFailed = true;
      case StreamOpenStepResult.decodeFailed:
        _decodeFailed = true;
    }
    if (kDebugMode && result != StreamOpenStepResult.success) {
      debugPrint(
        '[OpenPipeline] ${result.name} after ${_current?.label ?? "?"} '
        '→ re-branch',
      );
    }
  }

  @visibleForTesting
  StreamOpenAction? decideForTest() => _decide();

  StreamOpenAction? _decide() {
    if (pngMode == AnimePngStripMode.never) {
      return _once(StreamOpenAction.openDirect);
    }

    if (isProgressive && !isHls) {
      return _once(StreamOpenAction.openDirect);
    }

    if (pngMode == AnimePngStripMode.force) {
      if (!_tried.contains(StreamOpenAction.openPngStrip)) {
        return StreamOpenAction.openPngStrip;
      }
      if (_openFailed || _decodeFailed) {
        return _once(StreamOpenAction.openDirect);
      }
      return null;
    }

    // auto
    if (mediaClass == StreamMediaClass.pngWrapTs) {
      if (!_tried.contains(StreamOpenAction.openPngStrip)) {
        return StreamOpenAction.openPngStrip;
      }
      if ((_openFailed || _decodeFailed) &&
          !_tried.contains(StreamOpenAction.openDirect)) {
        return StreamOpenAction.openDirect;
      }
      return null;
    }

    // plainMedia / unknown HLS
    if (!_tried.contains(StreamOpenAction.openDirect)) {
      return StreamOpenAction.openDirect;
    }
    if ((_openFailed || _decodeFailed) &&
        isHls &&
        !_tried.contains(StreamOpenAction.openPngStrip)) {
      return StreamOpenAction.openPngStrip;
    }
    return null;
  }

  StreamOpenAction? _once(StreamOpenAction a) => _tried.contains(a) ? null : a;

  Future<StreamOpenStep?> _materialize(StreamOpenAction action) async {
    switch (action) {
      case StreamOpenAction.openDirect:
        return StreamOpenStep(
          action: action,
          catalogUrl: catalogUrl,
          playUrl: catalogUrl,
          headers: _headers.isEmpty ? null : _headers,
          reason: _reasonFor(action),
        );
      case StreamOpenAction.openPngStrip:
        final proxied = await _pngStripUrl();
        if (proxied == null || proxied.isEmpty) {
          debugPrint(
            '[OpenPipeline] openPngStrip aborted - local HLS proxy unavailable',
          );
          return null;
        }
        return StreamOpenStep(
          action: action,
          catalogUrl: catalogUrl,
          playUrl: proxied,
          headers: null,
          reason: _reasonFor(action),
        );
    }
  }

  String _reasonFor(StreamOpenAction action) {
    if (mediaClass == StreamMediaClass.pngWrapTs &&
        action == StreamOpenAction.openPngStrip) {
      return 'class:pngWrapTs';
    }
    if (_openFailed || _decodeFailed) {
      return 'priorFail→${action.name}';
    }
    if (mediaClass == StreamMediaClass.plainMedia) {
      return 'class:plainMedia';
    }
    if (isHls) return 'class:hls';
    if (isProgressive) return 'class:progressive';
    return 'class:default';
  }

  Future<String?> _pngStripUrl() async {
    final builder = _buildStripProxy;
    if (builder != null) {
      final u = builder(catalogUrl, _headers);
      return u.isEmpty ? null : u;
    }
    final ls = LocalServerService();
    if (ls.port == 0) await ls.start();
    if (ls.port == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await ls.start();
    }
    if (ls.port == 0) return null;
    return ls.getHlsProxyUrl(catalogUrl, _headers, stripMode: 'png');
  }
}
