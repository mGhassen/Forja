import 'package:forja/shared/host/kit/kit_details_meta.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';

import 'package:forja/shared/host/kit/meta_runtime.dart';

/// Pack `details` action — generic metadata fetch (no feature services).
///
/// Pass [seed] when available so params match [hubDetailsParams] and
/// [MetaRuntime] reuses the same cache entry as hub details screens.
Future<MetaItem?> fetchMetaDetails({
  required String pluginId,
  required String metaId,
  MetaItem? seed,
}) async {
  final params = seed != null
      ? hubDetailsParams(seed)
      : <String, dynamic>{'id': metaId};
  final env = await MetaRuntime.instance.run(
    pluginId: pluginId,
    action: 'details',
    params: params,
  );
  if (!env.ok || env.data == null) return null;
  final raw = env.data!['meta'];
  if (raw is! Map) return null;
  return MetaItem.fromJson(Map<String, dynamic>.from(raw));
}
