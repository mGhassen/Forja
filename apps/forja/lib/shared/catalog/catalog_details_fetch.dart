import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';

/// Pack `details` action — generic metadata fetch (no feature services).
///
/// Pass [seed] when available so params match [hubDetailsParams] and
/// [CatalogRuntime] reuses the same cache entry as hub details screens.
Future<CatalogMetaItem?> fetchCatalogMetaDetails({
  required String pluginId,
  required String metaId,
  CatalogMetaItem? seed,
}) async {
  final params = seed != null
      ? hubDetailsParams(seed)
      : <String, dynamic>{'id': metaId};
  final env = await CatalogRuntime.instance.run(
    pluginId: pluginId,
    action: 'details',
    params: params,
  );
  if (!env.ok || env.data == null) return null;
  final raw = env.data!['meta'];
  if (raw is! Map) return null;
  return CatalogMetaItem.fromJson(Map<String, dynamic>.from(raw));
}
