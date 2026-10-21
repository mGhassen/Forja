import 'package:forja/shared/player/exo/exo_player_bridge.dart';

/// Per-open subtitle bookkeeping for the Exo player, kept pure so the
/// screen's merge / select rules can be tested without a platform view.
///
/// Vocabulary:
/// - **row** — a subtitle menu entry (`url`, `lang`/`language`, `display`,
///   …). Provider rows arrive with the stream; online rows come from the
///   subtitle search (Wyzie, Levrx, SubtitleCat, addons).
/// - **sideload** — a row downloaded to a local file and attached to Media3
///   (`url` file://, `lang`, `label`, `sourceUrl`, optional `mime`).

/// Row key marking an online search result (vs. a provider-attached row).
/// Not `origin`: that row key is the HTTP `Origin` header for the download.
const String exoSubtitleOriginKey = 'forjaRowOrigin';

/// [exoSubtitleOriginKey] value for online search results.
const String exoSubtitleOriginOnline = 'online';

/// Native sideload payload key carrying the row's source URL. Media3 reports
/// it back as the text track's format id so Dart can select the exact track.
const String exoSideloadIdKey = 'id';

List<Map<String, dynamic>> tagOnlineSubtitleRows(
  Iterable<Map<String, dynamic>> rows,
) {
  return [
    for (final r in rows) {...r, exoSubtitleOriginKey: exoSubtitleOriginOnline},
  ];
}

bool isOnlineSubtitleRow(Map<String, dynamic> row) =>
    row[exoSubtitleOriginKey] == exoSubtitleOriginOnline;

String _rowUrl(Map<String, dynamic> row) => (row['url'] ?? '').toString();

/// Menu rows after an open or reopen: this open's provider rows first, then
/// online results found earlier in the session. Rows from an earlier provider
/// list never survive — only rows tagged online do.
List<Map<String, dynamic>> externalSubtitleRowsForOpen({
  required List<Map<String, dynamic>> providerRows,
  required List<Map<String, dynamic>> previousRows,
}) {
  final providerUrls = {for (final r in providerRows) _rowUrl(r)}..remove('');
  final seen = <String>{...providerUrls};
  final out = <Map<String, dynamic>>[...providerRows];
  for (final r in previousRows) {
    if (!isOnlineSubtitleRow(r)) continue;
    final url = _rowUrl(r);
    if (url.isEmpty || !seen.add(url)) continue;
    out.add(r);
  }
  return out;
}

/// [current] plus [incoming], one entry per `sourceUrl`; an incoming entry
/// replaces a current one with the same source. Order is preserved.
List<Map<String, String>> mergeSideloads(
  List<Map<String, String>> current,
  Iterable<Map<String, String>> incoming,
) {
  final added = incoming.toList();
  final incomingUrls = {for (final s in added) s['sourceUrl']};
  final seen = <String?>{};
  final out = <Map<String, String>>[];
  for (final s in current) {
    final key = s['sourceUrl'];
    if (incomingUrls.contains(key) || !seen.add(key)) continue;
    out.add(s);
  }
  for (final s in added) {
    if (!seen.add(s['sourceUrl'])) continue;
    out.add(s);
  }
  return out;
}

/// Sideloads to attach when the stream changes under the same screen (manual
/// source switch, catalog pick): the new source's provider tracks plus the
/// user's current online pick, which is already on disk.
List<Map<String, String>> sideloadsForSourceSwitch({
  required List<Map<String, String>> providerPrepared,
  required List<Map<String, String>> previous,
  required String? selectedUrl,
}) {
  if (selectedUrl == null) return providerPrepared;
  if (providerPrepared.any((s) => s['sourceUrl'] == selectedUrl)) {
    return providerPrepared;
  }
  for (final s in previous) {
    if (s['sourceUrl'] == selectedUrl) {
      return [...providerPrepared, s];
    }
  }
  return providerPrepared;
}

/// Native `open` / `setSubtitles` payload. `id` carries the source URL so the
/// resulting Media3 text track can be matched by [exoTextTrackForSideload].
List<Map<String, String>> exoSideloadPayloads(
  Iterable<Map<String, String>> sideloads,
) {
  return [
    for (final e in sideloads)
      {
        'url': e['url']!,
        'lang': e['lang'] ?? 'und',
        'label': e['label'] ?? e['lang'] ?? 'und',
        exoSideloadIdKey: e['sourceUrl'] ?? e['url']!,
        if ((e['mime'] ?? '').isNotEmpty) 'mime': e['mime']!,
      },
  ];
}

Set<String> sideloadSourceUrls(Iterable<Map<String, String>> sideloads) => {
  for (final s in sideloads)
    if ((s['sourceUrl'] ?? '').isNotEmpty) s['sourceUrl']!,
};

final RegExp _mergedPeriodPrefix = RegExp(r'^\d+:');

/// The sideload id inside a Media3 `Format.id`. A sideload is merged with the
/// main media, and the merge prefixes each child's ids with its index
/// (`1:<id>`); the prefix is dropped.
String exoSideloadIdOf(String formatId) =>
    formatId.replaceFirst(_mergedPeriodPrefix, '');

/// The Media3 text track created from the sideload with [sourceUrl], or null
/// when the player has not reported it (yet).
ExoTrackInfo? exoTextTrackForSideload(
  List<ExoTrackInfo> text,
  String sourceUrl,
) {
  for (final t in text) {
    if (t.formatId.isNotEmpty && exoSideloadIdOf(t.formatId) == sourceUrl) {
      return t;
    }
  }
  return null;
}

/// Text tracks that are not sideloads. A sideloaded row is listed once, as
/// its menu row — never a second time as an in-stream track.
List<ExoTrackInfo> exoEmbeddedTextTracks(
  List<ExoTrackInfo> text,
  Set<String> sideloadUrls,
) {
  return [
    for (final t in text)
      if (t.formatId.isEmpty ||
          !sideloadUrls.contains(exoSideloadIdOf(t.formatId)))
        t,
  ];
}

/// Source URL of the sideload Media3 currently renders, or null when the
/// selected text track is in-stream or text is off.
String? selectedSideloadSourceUrl(
  ExoTracksSnapshot tracks,
  Set<String> sideloadUrls,
) {
  if (tracks.textOff) return null;
  for (final t in tracks.text) {
    if (!t.selected) continue;
    final id = exoSideloadIdOf(t.formatId);
    if (sideloadUrls.contains(id)) return id;
  }
  return null;
}
