import 'package:forja/shared/catalog/services/catalog_watch_history.dart';

/// Opaque resume rows for pack `because` rails — host does not interpret meta.
Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId) async {
  final entries = await CatalogWatchHistory.getAll(pluginId);
  return [
    for (final e in entries)
      {
        'title': e['title'],
        if (e['meta'] is Map) 'meta': e['meta'],
      },
  ];
}
