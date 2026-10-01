import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Opaque pack action run — painter never branches on action names.
Future<MetaEnvelope> packOpaqueRun({
  required String pluginId,
  required String action,
  Map<String, dynamic> params = const {},
  String? packSourceUrl,
  bool forceRefresh = false,
}) {
  final a = action.trim();
  if (a.isEmpty) {
    return Future.value(
      MetaEnvelope.failure(
        MetaErrorCode.invalidAction,
        message: 'empty action',
        action: action,
      ),
    );
  }
  return MetaRuntime.instance.run(
    pluginId: pluginId,
    action: a,
    params: params,
    packSourceUrl: packSourceUrl,
    forceRefresh: forceRefresh,
  );
}

/// Parse a pack `load: { action, params }` map. Null if missing/invalid.
({String action, Map<String, dynamic> params})? packLoadSpec(Object? raw) {
  if (raw is! Map) return null;
  final action = (raw['action'] ?? '').toString().trim();
  if (action.isEmpty) return null;
  final paramsRaw = raw['params'];
  final params = paramsRaw is Map
      ? Map<String, dynamic>.from(paramsRaw)
      : <String, dynamic>{};
  return (action: action, params: params);
}
