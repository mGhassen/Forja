import 'package:flutter/foundation.dart';
import 'package:forja/shared/playback/sources_panel_stream_probe.dart';
import 'package:forja/shared/player/player/playable_source_bridge.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

List<Map<String, dynamic>> sortEngineCatalogStreamRows(
  List<Map<String, dynamic>> rows,
) {
  final copy = List<Map<String, dynamic>>.from(rows);
  copy.sort((a, b) {
    final aUrl = a['url']?.toString() ?? '';
    final bUrl = b['url']?.toString() ?? '';
    final aBox = isMovieBoxCdnStreamUrl(aUrl);
    final bBox = isMovieBoxCdnStreamUrl(bUrl);
    if (aBox != bBox) return aBox ? 1 : -1;
    return 0;
  });
  return copy;
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
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  var ordered = sortEngineCatalogStreamRows(rows);
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
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (check is StremioPlayable) probeTotal++;
  }
  for (final row in ordered) {
    if (isAborted()) break;
    final check = classifyStremioStream(
      row,
      profile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (check is! StremioPlayable) continue;
    probeOrdinal++;
    messageNotifier?.value = probeTotal > 1
        ? 'Probing streams ($probeOrdinal/$probeTotal)…'
        : 'Probing streams…';
    final isArabicEmbed = PlayableSourceBridge.isArabicEmbedCatalogRow(row);
    final catalogUrl = row['url']?.toString() ?? '';
    if (isArabicEmbed) {
      if (catalogUrl.isEmpty) continue;
      final rawHeaders = row['headers'];
      Map<String, String>? hdrs;
      if (rawHeaders is Map) {
        hdrs = {
          for (final e in rawHeaders.entries)
            if (e.value != null) e.key.toString(): e.value.toString(),
        };
      }
      sources.add(
        normalizeStreamSourcePlayUrl(
          StreamSource(
            url: catalogUrl,
            title: (row['title'] ?? row['name'] ?? 'Forja').toString(),
            type: 'arabic_embed',
            headers: hdrs,
            providerId: catalogHttpPlayProviderId(row),
            catalogUrl: catalogUrl,
          ),
        ),
      );
      continue;
    }
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
    final pluginId = row['_enginePluginId']?.toString() ?? '';
    final type = urlLooksLikeHls(url)
        ? 'hls'
        : (pluginId == 'movieblast' ? 'mkv' : 'mp4');
    sources.add(
      normalizeStreamSourcePlayUrl(
        StreamSource(
          url: url,
          title: (row['title'] ?? row['name'] ?? 'Forja').toString(),
          type: type,
          headers: proxied.headers,
          providerId: catalogHttpPlayProviderId(row),
          catalogUrl: resolvedCatalogUrl,
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
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  for (final row in sortEngineCatalogStreamRows(rows)) {
    final check = classifyStremioStream(
      row,
      profile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (check is StremioExternalLink || check is StremioResolveFailure) {
      continue;
    }
    if (check is! StremioPlayable) return row;
  }
  return null;
}
