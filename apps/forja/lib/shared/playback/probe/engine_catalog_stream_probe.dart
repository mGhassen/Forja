import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/probe/sources_panel_stream_probe.dart';
import 'package:forja/shared/playback/probe/stream_drm_platform.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:rust/rust.dart';

List<Map<String, dynamic>> sortEngineMetaStreamRows(
  List<Map<String, dynamic>> rows,
) {
  return List<Map<String, dynamic>>.from(rows);
}

/// Classify → proxy → HTTP probe (Sources panel hover / engine auto check-all).
///
/// Player open/decode is separate — pass [streamsPrevalidated: true] when this
/// list is handed to the player so reachability is not re-probed on open.
Future<List<StreamSource>> buildProbedEngineCatalogSources({
  required PlaybackProfile profile,
  required SettingsService settings,
  required List<Map<String, dynamic>> rows,
  required bool Function() isAborted,
  Map<String, dynamic>? preferFirst,
  ValueNotifier<String>? messageNotifier,
}) async {
  var ordered = sortEngineMetaStreamRows(rows);
  if (preferFirst != null) {
    final preferUrl = preferFirst['url']?.toString();
    ordered = [
      preferFirst,
      ...ordered.where((r) => r['url']?.toString() != preferUrl),
    ];
  }
  final sources = <StreamSource>[];
  var probeOrdinal = 0;
  var probeTotal = 0;
  for (final row in ordered) {
    final check = classifyStremioStream(
      row,
      profile,
    );
    if (check is! StremioPlayable) continue;
    if (streamDrmBlockedOffAndroid(row['drm'])) continue;
    probeTotal++;
  }
  for (final row in ordered) {
    if (isAborted()) break;
    final check = classifyStremioStream(
      row,
      profile,
    );
    if (check is! StremioPlayable) continue;
    // Widevine only on Android Exo (RFC-101) — skip before HTTP probe.
    if (streamDrmBlockedOffAndroid(row['drm'])) continue;
    probeOrdinal++;
    messageNotifier?.value = probeTotal > 1
        ? 'Probing streams ($probeOrdinal/$probeTotal)…'
        : 'Probing streams…';
    final proxied = await proxyCatalogHttpStreamIfNeeded(
      streamUrl: check.streamUrl,
      headers: check.headers,
      stream: row,
    );
    if (isAborted()) break;
    final probeRow = Map<String, dynamic>.from(row)
      ..['url'] = proxied.url
      ..['headers'] = proxied.headers;
    if (!await probeSourcesPanelStream(probeRow)) continue;
    final url = proxied.url;
    final resolvedCatalogUrl = row['url']?.toString() ?? url;
    final drm = StreamDrmConfig.tryParse(row['drm']);
    final declared = row['type']?.toString().trim();
    final type = (declared != null && declared.isNotEmpty)
        ? declared
        : (urlLooksLikeHls(url) ? 'hls' : 'mp4');
    sources.add(
      normalizeStreamSourcePlayUrl(
        StreamSource(
          url: url,
          title: (row['_addonName'] ?? row['name'] ?? row['title'] ?? 'Forja')
              .toString(),
          type: type,
          headers: proxied.headers,
          providerId: catalogHttpPlayProviderId(row),
          catalogUrl: resolvedCatalogUrl,
          drm: drm,
          probe: row['probe']?.toString(),
          pngStrip: row['pngStrip']?.toString(),
        ),
      ),
    );
  }
  return sources;
}

Map<String, dynamic>? engineCatalogRowForSource(
  List<Map<String, dynamic>> rows,
  StreamSource source,
) {
  for (final row in rows) {
    final catalog = row['url']?.toString();
    if (catalog != null &&
        catalog.isNotEmpty &&
        source.catalogUrl == catalog) {
      return row;
    }
    if (row['url']?.toString() == source.url) return row;
  }
  return null;
}

/// First row that needs magnet/debrid resolve (not direct HTTP playable).
Future<Map<String, dynamic>?> firstEngineCatalogResolveRow({
  required List<Map<String, dynamic>> rows,
  required PlaybackProfile profile,
  required SettingsService settings,
}) async {
  for (final row in sortEngineMetaStreamRows(rows)) {
    final check = classifyStremioStream(
      row,
      profile,
    );
    if (check is StremioExternalLink || check is StremioResolveFailure) {
      continue;
    }
    if (check is! StremioPlayable) return row;
  }
  return null;
}
