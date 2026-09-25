import 'dart:convert';
import 'dart:io';

import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/downloads/download_source_match.dart';
import 'package:forja/shared/downloads/download_task.dart';
import 'package:forja/shared/engine/runtime/open/meta_movie.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:path/path.dart' as p;
import 'package:rust/rust.dart';

/// Hub kind id for a saved title (`movie` / `tv` / `anime` / `asian_drama`).
String downloadHubKind(String type) {
  switch (type.trim().toLowerCase()) {
    case 'series':
    case 'tv':
      return 'tv';
    case 'drama':
    case 'asian_drama':
      return 'asian_drama';
    case 'anime':
      return 'anime';
    default:
      return 'movie';
  }
}

/// Download library type. Drama stays `drama` (not folded into movie).
String downloadTypeForMeta(MetaItem item) {
  final kind = item.type.trim().toLowerCase();
  final surface = (item.open?.surface ?? '').trim().toLowerCase();
  if (kind == 'asian_drama' || kind == 'drama' || surface == 'drama') {
    return 'drama';
  }
  if (kind == 'anime' || surface == 'anime') return 'anime';
  if (kind == 'movie' || item.tmdbMediaType == 'movie') return 'movie';
  if (kind == 'tv' || kind == 'series' || item.tmdbMediaType == 'tv') {
    return 'series';
  }
  return 'movie';
}

String downloadTypeForMovie(Movie? movie) {
  if (movie == null) return 'movie';
  final meta = metaItemForMovie(movie);
  if (meta != null) return downloadTypeForMeta(meta);
  final mt = movie.mediaType.toLowerCase();
  if (mt == 'drama' || mt == 'asian_drama') return 'drama';
  if (mt == 'tv' || mt == 'series') return 'series';
  if (mt == 'anime') return 'anime';
  return 'movie';
}

String mediaIdForMetaItem(MetaItem item) {
  final imdb = imdbIdOnMeta(item);
  final movie = metaItemToMovie(item);
  if (movie == null) return imdb ?? item.id;
  return mediaIdForDownloadMovie(imdbId: imdb ?? movie.imdbId, id: movie.id);
}

/// First finished file: lowest season, then episode, then earliest finish.
DownloadTask? firstCompletedDownload(
  Iterable<DownloadTask> tasks,
  String mediaId,
) {
  final id = mediaId.trim();
  if (id.isEmpty) return null;
  final hits = [
    for (final task in tasks)
      if (task.mediaId == id && task.isCompleted) task,
  ];
  if (hits.isEmpty) return null;
  hits.sort((a, b) {
    final season = (a.season ?? 0).compareTo(b.season ?? 0);
    if (season != 0) return season;
    final episode = (a.episode ?? 0).compareTo(b.episode ?? 0);
    if (episode != 0) return episode;
    final aAt = a.completedAt ?? a.createdAt;
    final bAt = b.completedAt ?? b.createdAt;
    return aAt.compareTo(bAt);
  });
  return hits.first;
}

bool _episodeSaved(
  Set<(int, int)> slots,
  int? season,
  int? episode,
) {
  return slots.contains((season ?? 1, episode ?? 1));
}

/// Keep only episodes that have a finished file. Films stay as-is.
MetaItem filterMetaToDownloadedEpisodes(
  MetaItem item,
  Iterable<DownloadTask> tasks,
  String mediaId,
) {
  if (downloadTypeForMeta(item) == 'movie' || item.type == 'movie') {
    return item.copyWith(videos: const []);
  }
  final slots = <(int, int)>{
    for (final task in tasks)
      if (task.mediaId == mediaId && task.isCompleted)
        (task.season ?? 1, task.episode ?? 1),
  };
  if (item.videos.isEmpty) return item;
  return item.copyWith(
    videos: [
      for (final video in item.videos)
        if (_episodeSaved(slots, video.season, video.episode)) video,
    ],
  );
}

bool downloadMetaIsRich(Map<String, dynamic> meta) {
  final description = (meta['description'] ?? '').toString().trim();
  if (description.length > 40) return true;
  final cast = meta['cast'];
  if (cast is List && cast.isNotEmpty) return true;
  final videos = meta['videos'];
  if (videos is List && videos.isNotEmpty) return true;
  final facts = meta['facts'];
  if (facts is Map && facts.isNotEmpty) return true;
  return false;
}

/// On-disk page for one saved title: `details.json` plus poster and backdrop.
class DownloadPageStore {
  DownloadPageStore._();

  static final Map<String, MetaItem> _noted = {};

  static const _detailsName = 'details.json';

  /// Latest details page for [mediaId], held until the next enqueue.
  static void note(String mediaId, MetaItem item) {
    final id = mediaId.trim();
    if (id.isEmpty) return;
    _noted[id] = item;
  }

  static String folderKey(String mediaId) {
    final cleaned = mediaId.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'title' : cleaned;
  }

  static Future<Directory> directoryFor(String mediaId) async {
    final file = await _detailsFile(mediaId, create: true);
    return file.parent;
  }

  static Future<File> _detailsFile(String mediaId, {required bool create}) async {
    final root = await DownloadPathHelper.getDownloadsDirectoryPath();
    final dir = Directory(p.join(root, 'pages', folderKey(mediaId)));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, _detailsName));
  }

  static Future<Map<String, dynamic>?> readEnvelope(String mediaId) async {
    try {
      final file = await _detailsFile(mediaId, create: false);
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<MetaItem?> readMeta(String mediaId) async {
    final envelope = await readEnvelope(mediaId);
    final meta = envelope?['meta'];
    if (meta is! Map) return null;
    return MetaItem.fromJson(Map<String, dynamic>.from(meta));
  }

  /// Write the page for [mediaId]. A thin player snapshot does not replace
  /// a page that already has description, cast, or episodes.
  static Future<void> capture({
    required String mediaId,
    required String type,
    String? title,
    String? posterUrl,
    String? backdropUrl,
    String? year,
    String? overview,
  }) async {
    final id = mediaId.trim();
    if (id.isEmpty) return;
    final existing = await readEnvelope(id);
    final existingMeta = existing?['meta'];
    final existingMap = existingMeta is Map
        ? Map<String, dynamic>.from(existingMeta)
        : null;
    final noted = _noted[id];
    final notedMap = noted?.toJson();

    Map<String, dynamic> meta;
    if (notedMap != null && downloadMetaIsRich(notedMap)) {
      meta = notedMap;
    } else if (existingMap != null && downloadMetaIsRich(existingMap)) {
      meta = existingMap;
    } else if (notedMap != null) {
      meta = notedMap;
    } else {
      meta = {
        'id': id,
        'type': downloadHubKind(type) == 'tv' ? 'tv' : type,
        'name': (title ?? '').trim(),
        if ((posterUrl ?? '').trim().isNotEmpty) 'poster': posterUrl!.trim(),
        if ((backdropUrl ?? '').trim().isNotEmpty)
          'background': backdropUrl!.trim(),
        if ((overview ?? '').trim().isNotEmpty) 'description': overview!.trim(),
        if ((year ?? '').trim().isNotEmpty) 'releaseInfo': year!.trim(),
      };
    }

    meta['open'] = {
      'surface': 'offline',
      'id': id,
      'preferredSourcesKind': 'downloaded',
    };

    final dir = await directoryFor(id);
    final posterFile = await _saveImage(
      url: (meta['poster'] ?? posterUrl ?? '').toString(),
      dir: dir,
      name: 'poster',
    );
    final backdropFile = await _saveImage(
      url: (meta['background'] ?? backdropUrl ?? '').toString(),
      dir: dir,
      name: 'backdrop',
    );
    if (posterFile != null) {
      meta['poster'] = posterFile.path;
    } else if (_isLocalPath((existingMap?['poster'] ?? '').toString())) {
      meta['poster'] = existingMap!['poster'];
    }
    if (backdropFile != null) {
      meta['background'] = backdropFile.path;
      meta['backdrops'] = [backdropFile.path];
    } else if (_isLocalPath((existingMap?['background'] ?? '').toString())) {
      meta['background'] = existingMap!['background'];
    }

    final envelope = {
      'downloadType': type,
      'meta': meta,
    };
    final file = File(p.join(dir.path, _detailsName));
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(envelope));
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await tmp.rename(file.path);
  }

  /// One card per title that has a finished file.
  static Future<List<Map<String, dynamic>>> titles() async {
    await DownloadService.instance.initialize();
    final grouped = <String, DownloadTask>{};
    for (final task in DownloadService.instance.tasksNotifier.value) {
      if (!task.isCompleted || task.mediaId.trim().isEmpty) continue;
      grouped.putIfAbsent(task.mediaId, () => task);
    }
    final rows = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final task = entry.value;
      final envelope = await readEnvelope(entry.key);
      final meta = envelope?['meta'];
      final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : null;
      final storedType = (envelope?['downloadType'] ?? task.type).toString();
      final kind = downloadHubKind(storedType);
      final name = (metaMap?['name'] ?? task.title).toString().trim();
      final poster = (metaMap?['poster'] ?? task.posterUrl ?? '').toString();
      final year = (metaMap?['releaseInfo'] ?? task.year ?? '').toString();
      rows.add({
        'id': entry.key,
        'type': kind,
        'kind': kind,
        'name': name.isEmpty ? task.title : name,
        'poster': poster,
        'releaseInfo': year,
        'year': year,
        'open': {
          'surface': 'offline',
          'id': entry.key,
          'preferredSourcesKind': 'downloaded',
        },
      });
    }
    rows.sort((a, b) {
      final left = (a['name'] ?? '').toString().toLowerCase();
      final right = (b['name'] ?? '').toString().toLowerCase();
      return left.compareTo(right);
    });
    return rows;
  }

  static bool _isLocalPath(String raw) {
    final value = raw.trim();
    return value.startsWith('/') || value.startsWith('file://');
  }

  static Future<File?> _saveImage({
    required String url,
    required Directory dir,
    required String name,
  }) async {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    if (_isLocalPath(raw)) {
      final path = raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;
      final file = File(path);
      if (await file.exists()) return file;
      return null;
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) return null;
    final dest = File(p.join(dir.path, name));
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse(raw));
      request.followRedirects = true;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buf, chunk) => buf..addAll(chunk),
      );
      if (bytes.length < 32) return null;
      final tmp = File('${dest.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      if (await dest.exists()) {
        try {
          await dest.delete();
        } catch (_) {}
      }
      await tmp.rename(dest.path);
      return dest;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
