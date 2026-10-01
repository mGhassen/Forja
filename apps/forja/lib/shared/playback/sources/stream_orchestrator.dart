import 'dart:async';

import 'package:forja/shared/engine/models/models.dart';

/// Joins Sources and Play onto one in-flight extract per title and plugin.
///
/// Does not limit how many plugins run. Each extract is still a fresh QuickJS
/// runtime on a Rust job. A second caller for the same plugin awaits the first.
class StreamOrchestrator {
  StreamOrchestrator._();

  static final StreamOrchestrator instance = StreamOrchestrator._();

  static const rowsPerPluginCap = 30;

  final _jobs = <String, Future<EngineExtractResult?>>{};

  static String jobKey(String sessionKey, String pluginId) =>
      '$sessionKey\u0000$pluginId';

  /// Runs [job]. A second call with the same [sessionKey] and [pluginId]
  /// awaits the first future and does not start another extract.
  Future<EngineExtractResult?> schedule({
    required String sessionKey,
    required String pluginId,
    required Future<EngineExtractResult?> Function() job,
  }) {
    final key = jobKey(sessionKey, pluginId);
    final existing = _jobs[key];
    if (existing != null) return existing;
    final fut = job();
    _jobs[key] = fut;
    fut.whenComplete(() {
      if (identical(_jobs[key], fut)) _jobs.remove(key);
    });
    return fut;
  }
}
