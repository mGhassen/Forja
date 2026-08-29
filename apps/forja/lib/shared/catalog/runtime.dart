import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/service.dart';

import 'cache.dart';
import 'protocol.dart';

/// Runs catalog hub actions through [EngineService.runCatalog] with caching.
///
/// Not the JS engine runtime (`shared/engine/runtime.dart`) — this is the
/// protocol-level caller hubs use.
class CatalogRuntime {
  CatalogRuntime._();
  static final CatalogRuntime instance = CatalogRuntime._();

  final Set<String> _revalidating = {};

  Future<CatalogEnvelope> run({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? auth,
    String? authSubject,
    bool forceRefresh = false,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final key = CatalogCache.keyFor(
      pluginId: pluginId,
      action: action,
      params: params,
      authSubject: authSubject,
    );
    final cached = forceRefresh ? null : CatalogCache.instance.get(key);

    if (cached != null && cached.isFresh) {
      return _pipeEnrichCached(
        sourcePluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        envelope: _cachedEnvelope(action, cached),
        timeout: timeout,
      );
    }
    if (cached != null && cached.isRevalidatable) {
      _reviveInBackground(
        key: key,
        pluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        entry: cached,
        timeout: timeout,
      );
      return _pipeEnrichCached(
        sourcePluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        envelope: _cachedEnvelope(action, cached),
        timeout: timeout,
      );
    }

    return _fetch(
      key: key,
      pluginId: pluginId,
      action: action,
      params: params,
      auth: auth,
      entry: cached,
      timeout: timeout,
    );
  }

  Future<CatalogEnvelope> _fetch({
    required String key,
    required String pluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    CatalogCacheEntry? entry,
    required Duration timeout,
  }) async {
    final raw = await EngineService.instance.runCatalog(
      pluginId: pluginId,
      action: action,
      params: params,
      auth: auth,
      cache: entry?.etag == null ? const {} : {'etag': entry!.etag},
      timeout: timeout,
    );
    if (raw == null) {
      if (entry != null) return _cachedEnvelope(action, entry);
      return CatalogEnvelope.failure(
        CatalogErrorCode.upstream,
        message: '$pluginId did not answer $action',
        action: action,
      );
    }

    var envelope = parseEnvelope(raw);
    if (envelope == null) {
      if (entry != null) return _cachedEnvelope(action, entry);
      return CatalogEnvelope.failure(
        CatalogErrorCode.parse,
        message: '$pluginId returned a non-protocol payload',
        action: action,
      );
    }
    if (envelope.isUnsupportedKit) {
      return CatalogEnvelope.failure(
        CatalogErrorCode.unsupportedKit,
        message:
            '$pluginId needs host kit ${envelope.kit} (this build has $hostKitVersion)',
        action: action,
      );
    }
    if (envelope.notModified && entry != null) {
      CatalogCache.instance.touch(key);
      return _cachedEnvelope(action, entry);
    }
    if (!envelope.ok) {
      if (entry != null && !entry.isExpired) {
        debugPrint('[catalog] $pluginId $action ${envelope.error} — serving cache');
        return _cachedEnvelope(action, entry);
      }
      return envelope;
    }

    envelope = await _pipeEnrich(
      sourcePluginId: pluginId,
      action: action,
      params: params,
      auth: auth,
      envelope: envelope,
      timeout: timeout,
    );

    final data = envelope.data;
    if (data != null) {
      CatalogCache.instance.put(
        key: key,
        pluginId: pluginId,
        data: data,
        hints: envelope.cache,
      );
    }
    return envelope;
  }

  /// Companion enrich on cache hits — spotlight rows cached before enrich
  /// shipped (or from an older build) must still get TMDB backdrops.
  Future<CatalogEnvelope> _pipeEnrichCached({
    required String sourcePluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogEnvelope envelope,
    required Duration timeout,
  }) async {
    if (action != 'rail' && action != 'details') return envelope;
    return _pipeEnrich(
      sourcePluginId: sourcePluginId,
      action: action,
      params: params,
      auth: auth,
      envelope: envelope,
      timeout: timeout,
    );
  }

  /// After a source catalog answers `rail` / `details`, optionally run the
  /// companion enrich plugin declared as `EnginePlugin.enrich`.
  Future<CatalogEnvelope> _pipeEnrich({
    required String sourcePluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogEnvelope envelope,
    required Duration timeout,
  }) async {
    if (action == 'enrich') return envelope;
    if (action != 'rail' && action != 'details') return envelope;
    if (!envelope.ok) return envelope;

    final source = await _resolvePlugin(sourcePluginId);
    final enrichId = source?.enrich?.trim() ?? '';
    if (enrichId.isEmpty || enrichId == sourcePluginId) return envelope;

    final data = envelope.data;
    if (data == null) return envelope;

    final enrichParams = <String, dynamic>{...params};
    if (action == 'rail') {
      final items = data['items'];
      if (items is! List || items.isEmpty) return envelope;
      enrichParams['items'] = items;
    } else {
      final meta = data['meta'];
      if (meta is! Map) return envelope;
      enrichParams['meta'] = Map<String, dynamic>.from(meta);
    }

    final raw = await EngineService.instance.runCatalog(
      pluginId: enrichId,
      action: 'enrich',
      params: enrichParams,
      auth: auth,
      timeout: timeout,
    );
    if (raw == null) {
      debugPrint('[catalog] $sourcePluginId enrich via $enrichId skipped (no answer)');
      return envelope;
    }
    final enriched = parseEnvelope(raw);
    if (enriched == null || !enriched.ok || enriched.data == null) {
      debugPrint(
        '[catalog] $sourcePluginId enrich via $enrichId failed — keeping source',
      );
      return envelope;
    }

    final merged = Map<String, dynamic>.from(data);
    if (action == 'rail') {
      final items = enriched.data!['items'];
      if (items is List) merged['items'] = items;
    } else {
      final meta = enriched.data!['meta'];
      if (meta is Map) merged['meta'] = Map<String, dynamic>.from(meta);
    }
    return CatalogEnvelope(
      ok: true,
      action: action,
      kit: envelope.kit,
      protocol: envelope.protocol,
      data: merged,
      cache: envelope.cache,
    );
  }

  Future<EnginePlugin?> _resolvePlugin(String pluginId) async {
    final packs = await EngineService.instance.listPacks();
    return PluginRegistry.packPluginFromPacks(packs, pluginId)?.plugin;
  }

  void _reviveInBackground({
    required String key,
    required String pluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogCacheEntry entry,
    required Duration timeout,
  }) {
    if (!_revalidating.add(key)) return;
    unawaited(
      _fetch(
        key: key,
        pluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        entry: entry,
        timeout: timeout,
      ).catchError((Object e) {
        debugPrint('[catalog] $pluginId $action revalidate failed: $e');
        return _cachedEnvelope(action, entry);
      }).whenComplete(() => _revalidating.remove(key)),
    );
  }

  CatalogEnvelope _cachedEnvelope(String action, CatalogCacheEntry entry) =>
      CatalogEnvelope(
        ok: true,
        action: action,
        data: entry.data,
        cache: CatalogCacheHints(etag: entry.etag),
      );
}
