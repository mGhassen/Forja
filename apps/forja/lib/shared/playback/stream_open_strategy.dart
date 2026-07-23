import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// What we observed about the catalog / last open.
enum StreamOpenFact {
  /// URL / type looks like HLS playlist.
  hls,

  /// URL looks like progressive media (mp4/mkv/…).
  progressive,

  /// Segment sample is PNG (wrap or Range decoy).
  pngShell,

  /// Segment sample is not PNG / looks like plain media.
  plainMedia,

  /// Sniff failed or inconclusive.
  unknownBody,

  /// Last play attempt failed to demux / open.
  openFailed,

  /// Last play opened but no video frame.
  decodeFailed,
}

/// Leaf action the player should execute.
enum StreamOpenAction {
  /// Open catalog URL with identity headers.
  playDirect,

  /// Open via `/hls-proxy?strip=png`.
  playPngStrip,
}

/// One decided play step from the mind tree.
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

  /// Why this branch was chosen (debug / logs).
  final String reason;

  String get label => action.name;
}

/// Outcome of executing a [StreamOpenStep] — feeds the next branch.
enum StreamOpenStepResult {
  success,
  openFailed,
  decodeFailed,
}

/// Mind-tree open middleware.
///
/// Not a precomputed try-list. Walk:
///   classify URL + sniff body
///     → pick ONE action
///     → player reports success/fail
///     → tree branches on that fact (next action or exhaust)
///
/// Add branches here when a new technique exists — never per-CDN hosts.
class StreamOpenMindTree {
  StreamOpenMindTree._({
    required this.catalogUrl,
    required Map<String, String> headers,
    required this.providerId,
    required this.pngMode,
    required this.facts,
    String Function(String url, Map<String, String> headers)? buildStripProxy,
  })  : _headers = headers,
        _buildStripProxy = buildStripProxy;

  final String catalogUrl;
  final String? providerId;
  final AnimePngStripMode pngMode;
  final Set<StreamOpenFact> facts;
  final Map<String, String> _headers;
  final String Function(String url, Map<String, String> headers)?
      _buildStripProxy;

  final Set<StreamOpenAction> _tried = {};
  StreamOpenStep? _current;

  /// Start: classify catalog, sniff when HLS + auto/force.
  static Future<StreamOpenMindTree> start({
    required String catalogUrl,
    Map<String, String>? headers,
    String? providerId,
    @visibleForTesting Future<Set<StreamOpenFact>> Function()? sniffFacts,
    @visibleForTesting
    String Function(String url, Map<String, String> headers)? buildStripProxy,
  }) async {
    final catalog = (hlsProxyTargetUrl(catalogUrl) ?? catalogUrl).trim();
    final hdrs = resolvePlaybackHttpHeaders(
      headers,
      streamUrl: catalog,
      providerId: providerId,
    );
    final mode = ProviderRuntimeConfig.instance
        .animePlaybackProfile(providerId ?? '')
        .pngStrip;

    final facts = <StreamOpenFact>{};
    final lower = catalog.toLowerCase();
    if (lower.contains('.m3u8')) {
      facts.add(StreamOpenFact.hls);
    } else if (lower.contains('.mp4') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('.mpd')) {
      facts.add(StreamOpenFact.progressive);
    } else {
      facts.add(StreamOpenFact.unknownBody);
    }

    if (facts.contains(StreamOpenFact.hls) &&
        mode != AnimePngStripMode.never) {
      final sniffed = sniffFacts != null
          ? await sniffFacts()
          : await _sniff(catalog, providerId, hdrs);
      facts.addAll(sniffed);
    }

    if (kDebugMode) {
      debugPrint(
        '[OpenMindTree] start $providerId facts=${facts.map((f) => f.name).join(",")}',
      );
    }

    return StreamOpenMindTree._(
      catalogUrl: catalog,
      headers: hdrs,
      providerId: providerId,
      pngMode: mode,
      facts: facts,
      buildStripProxy: buildStripProxy,
    );
  }

  /// Next leaf to try, or `null` when the tree is exhausted for this URL.
  Future<StreamOpenStep?> next() async {
    final action = _decide();
    if (action == null) {
      if (kDebugMode) {
        debugPrint('[OpenMindTree] exhausted $providerId');
      }
      return null;
    }
    _tried.add(action);
    final step = await _materialize(action);
    if (step == null) {
      if (kDebugMode) {
        debugPrint('[OpenMindTree] $action unavailable — exhausted');
      }
      return null;
    }
    _current = step;
    if (kDebugMode) {
      debugPrint(
        '[OpenMindTree] branch → ${step.label} (${step.reason})',
      );
    }
    return step;
  }

  /// Report how [step] went so the next [next] call can re-branch.
  void report(StreamOpenStepResult result) {
    switch (result) {
      case StreamOpenStepResult.success:
        break;
      case StreamOpenStepResult.openFailed:
        facts.add(StreamOpenFact.openFailed);
      case StreamOpenStepResult.decodeFailed:
        facts.add(StreamOpenFact.decodeFailed);
    }
    if (kDebugMode && result != StreamOpenStepResult.success) {
      debugPrint(
        '[OpenMindTree] ${result.name} after ${_current?.label ?? "?"} '
        '→ re-branch',
      );
    }
  }

  /// Pure decision: facts + tried → next action (or null).
  @visibleForTesting
  StreamOpenAction? decideForTest() => _decide();

  StreamOpenAction? _decide() {
    // Policy hard stops.
    if (pngMode == AnimePngStripMode.never) {
      return _once(StreamOpenAction.playDirect);
    }

    // Progressive / non-HLS: direct only.
    if (facts.contains(StreamOpenFact.progressive) &&
        !facts.contains(StreamOpenFact.hls)) {
      return _once(StreamOpenAction.playDirect);
    }

    // force: strip first; on fail, direct (false-sniff / proxy miss recovery).
    if (pngMode == AnimePngStripMode.force) {
      if (!_tried.contains(StreamOpenAction.playPngStrip)) {
        return StreamOpenAction.playPngStrip;
      }
      if (facts.contains(StreamOpenFact.openFailed) ||
          facts.contains(StreamOpenFact.decodeFailed)) {
        return _once(StreamOpenAction.playDirect);
      }
      return null;
    }

    // auto mind tree:
    //
    //   pngShell ──────────► playPngStrip
    //        │ fail
    //        └─────────────► playDirect
    //
    //   plain / unknown ───► playDirect
    //        │ fail
    //        └─────────────► playPngStrip
    //
    //   open/decode fail re-enters with openFailed / decodeFailed fact set.
    if (facts.contains(StreamOpenFact.pngShell)) {
      if (!_tried.contains(StreamOpenAction.playPngStrip)) {
        return StreamOpenAction.playPngStrip;
      }
      if ((facts.contains(StreamOpenFact.openFailed) ||
              facts.contains(StreamOpenFact.decodeFailed)) &&
          !_tried.contains(StreamOpenAction.playDirect)) {
        return StreamOpenAction.playDirect;
      }
      return null;
    }

    // plainMedia / unknownBody / hls without png
    if (!_tried.contains(StreamOpenAction.playDirect)) {
      return StreamOpenAction.playDirect;
    }
    if ((facts.contains(StreamOpenFact.openFailed) ||
            facts.contains(StreamOpenFact.decodeFailed)) &&
        facts.contains(StreamOpenFact.hls) &&
        !_tried.contains(StreamOpenAction.playPngStrip)) {
      return StreamOpenAction.playPngStrip;
    }
    return null;
  }

  StreamOpenAction? _once(StreamOpenAction a) =>
      _tried.contains(a) ? null : a;

  Future<StreamOpenStep?> _materialize(StreamOpenAction action) async {
    switch (action) {
      case StreamOpenAction.playDirect:
        return StreamOpenStep(
          action: action,
          catalogUrl: catalogUrl,
          playUrl: catalogUrl,
          headers: _headers.isEmpty ? null : _headers,
          reason: _reasonFor(action),
        );
      case StreamOpenAction.playPngStrip:
        final proxied = await _pngStripUrl();
        if (proxied == null || proxied.isEmpty) {
          debugPrint(
            '[OpenMindTree] playPngStrip aborted — local HLS proxy unavailable',
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
    if (facts.contains(StreamOpenFact.pngShell) &&
        action == StreamOpenAction.playPngStrip) {
      return 'fact:pngShell';
    }
    if (facts.contains(StreamOpenFact.openFailed) ||
        facts.contains(StreamOpenFact.decodeFailed)) {
      return 'fact:priorFail→${action.name}';
    }
    if (facts.contains(StreamOpenFact.plainMedia)) {
      return 'fact:plainMedia';
    }
    if (facts.contains(StreamOpenFact.hls)) return 'fact:hls';
    if (facts.contains(StreamOpenFact.progressive)) {
      return 'fact:progressive';
    }
    return 'fact:default';
  }

  Future<String?> _pngStripUrl() async {
    final builder = _buildStripProxy;
    if (builder != null) {
      return builder(catalogUrl, _headers);
    }
    final ls = LocalServerService();
    if (ls.port == 0) await ls.start();
    if (ls.port == 0) {
      // One more attempt — boot warm can race the first anime open.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await ls.start();
    }
    if (ls.port == 0) return null;
    return ls.getHlsProxyUrl(catalogUrl, _headers, stripMode: 'png');
  }

  static Future<Set<StreamOpenFact>> _sniff(
    String catalog,
    String? providerId,
    Map<String, String> headers,
  ) async {
    try {
      final png = await animeHlsSegmentLooksPngWrappedForStrategy(
        catalog,
        headers,
      );
      return {
        png ? StreamOpenFact.pngShell : StreamOpenFact.plainMedia,
      };
    } catch (_) {
      return {StreamOpenFact.unknownBody};
    }
  }
}

/// @nodoc — kept name for older call sites / tests during migration.
@Deprecated('Use StreamOpenMindTree')
abstract final class StreamOpenStrategy {
  static Future<StreamOpenMindTree> start({
    required String catalogUrl,
    Map<String, String>? headers,
    String? providerId,
  }) =>
      StreamOpenMindTree.start(
        catalogUrl: catalogUrl,
        headers: headers,
        providerId: providerId,
      );
}
