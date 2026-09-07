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
  final Map<String, Future<CatalogEnvelope>> _inFlight = {};

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
        cacheKey: key,
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
        cacheKey: key,
        sourcePluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        envelope: _cachedEnvelope(action, cached),
        timeout: timeout,
      );
    }

    if (!forceRefresh) {
      final pending = _inFlight[key];
      if (pending != null) return pending;
    } else {
      _inFlight.remove(key);
    }

    final future = _fetch(
      key: key,
      pluginId: pluginId,
      action: action,
      params: params,
      auth: auth,
      entry: cached,
      timeout: timeout,
    );
    if (!forceRefresh) _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
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
      if (entry != null) {
        return _pipeEnrichCached(
          cacheKey: key,
          sourcePluginId: pluginId,
          action: action,
          params: params,
          auth: auth,
          envelope: _cachedEnvelope(action, entry),
          timeout: timeout,
        );
      }
      return CatalogEnvelope.failure(
        CatalogErrorCode.upstream,
        message: '$pluginId did not answer $action',
        action: action,
      );
    }

    var envelope = parseEnvelope(raw);
    if (envelope == null) {
      if (entry != null) {
        return _pipeEnrichCached(
          cacheKey: key,
          sourcePluginId: pluginId,
          action: action,
          params: params,
          auth: auth,
          envelope: _cachedEnvelope(action, entry),
          timeout: timeout,
        );
      }
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
      return _pipeEnrichCached(
        cacheKey: key,
        sourcePluginId: pluginId,
        action: action,
        params: params,
        auth: auth,
        envelope: _cachedEnvelope(action, entry),
        timeout: timeout,
      );
    }
    if (!envelope.ok) {
      if (entry != null && !entry.isExpired) {
        debugPrint(
          '[catalog] $pluginId $action ${envelope.error} — serving cache',
        );
        return _pipeEnrichCached(
          cacheKey: key,
          sourcePluginId: pluginId,
          action: action,
          params: params,
          auth: auth,
          envelope: _cachedEnvelope(action, entry),
          timeout: timeout,
        );
      }
      return envelope;
    }

    if (_envelopeAlreadyEnriched(action, envelope.data, params)) {
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

  /// Companion enrich on cache hits — skip when payload already carries kit
  /// `_hubTmdbEnriched`; merged payload is written back on first enrich.
  Future<CatalogEnvelope> _pipeEnrichCached({
    required String cacheKey,
    required String sourcePluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogEnvelope envelope,
    required Duration timeout,
  }) async {
    if (action != 'rail' && action != 'details' && action != 'feed') {
      return envelope;
    }
    if (_envelopeAlreadyEnriched(action, envelope.data, params)) {
      return envelope;
    }
    final enriched = await _pipeEnrich(
      sourcePluginId: sourcePluginId,
      action: action,
      params: params,
      auth: auth,
      envelope: envelope,
      timeout: timeout,
    );
    final data = enriched.data;
    if (data != null) {
      CatalogCache.instance.put(
        key: cacheKey,
        pluginId: sourcePluginId,
        data: data,
        hints: enriched.cache,
      );
    }
    return enriched;
  }

  /// After a source catalog answers `rail` / `details` / `feed`, optionally run
  /// the companion enrich plugin declared as [EnginePlugin.enrich].
  Future<CatalogEnvelope> _pipeEnrich({
    required String sourcePluginId,
    required String action,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogEnvelope envelope,
    required Duration timeout,
  }) async {
    if (action == 'enrich') return envelope;
    if (action != 'rail' && action != 'details' && action != 'feed') {
      return envelope;
    }
    if (!envelope.ok) return envelope;
    if (_envelopeAlreadyEnriched(action, envelope.data, params)) {
      return envelope;
    }

    final source = await _resolvePlugin(sourcePluginId);
    final enrichId = source?.enrich?.trim() ?? '';
    if (enrichId.isEmpty || enrichId == sourcePluginId) return envelope;

    final data = envelope.data;
    if (data == null) return envelope;

    if (action == 'feed') {
      return _pipeEnrichFeed(
        sourcePluginId: sourcePluginId,
        enrichId: enrichId,
        params: params,
        auth: auth,
        envelope: envelope,
        data: data,
        timeout: timeout,
      );
    }

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

    final merged = await _mergeEnrichAnswer(
      sourcePluginId: sourcePluginId,
      enrichId: enrichId,
      action: action,
      data: data,
      enrichParams: enrichParams,
      auth: auth,
      timeout: timeout,
    );
    if (merged == null) return envelope;
    return CatalogEnvelope(
      ok: true,
      action: action,
      kit: envelope.kit,
      protocol: envelope.protocol,
      data: merged,
      cache: envelope.cache,
    );
  }

  Future<CatalogEnvelope> _pipeEnrichFeed({
    required String sourcePluginId,
    required String enrichId,
    required Map<String, dynamic> params,
    Map<String, dynamic>? auth,
    required CatalogEnvelope envelope,
    required Map<String, dynamic> data,
    required Duration timeout,
  }) async {
    final railsRaw = data['rails'];
    if (railsRaw is! Map || railsRaw.isEmpty) return envelope;

    final enrichPlugin = await _resolvePlugin(enrichId);
    final railIds = _enrichRailIds(enrichPlugin);
    final mergedRails = <String, dynamic>{
      for (final entry in railsRaw.entries) entry.key.toString(): entry.value,
    };
    var changed = false;
    for (final railId in railIds) {
      final items = mergedRails[railId];
      if (items is! List || items.isEmpty) continue;
      final out = await _mergeEnrichAnswer(
        sourcePluginId: sourcePluginId,
        enrichId: enrichId,
        action: 'rail',
        data: const {'items': []},
        enrichParams: <String, dynamic>{
          ...params,
          'rail': railId,
          'items': items,
        },
        auth: auth,
        timeout: timeout,
      );
      if (out == null) continue;
      final enrichedItems = out['items'];
      if (enrichedItems is List) {
        mergedRails[railId] = enrichedItems;
        changed = true;
      }
    }
    if (!changed) return envelope;

    final merged = Map<String, dynamic>.from(data);
    merged['rails'] = mergedRails;
    return CatalogEnvelope(
      ok: true,
      action: envelope.action,
      kit: envelope.kit,
      protocol: envelope.protocol,
      data: merged,
      cache: envelope.cache,
    );
  }

  List<String> _enrichRailIds(EnginePlugin? enrichPlugin) {
    final raw = enrichPlugin?.config['rails'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final entry in raw)
          if (entry.toString().trim().isNotEmpty) entry.toString().trim(),
      ];
    }
    return const ['spotlight'];
  }

  Future<Map<String, dynamic>?> _mergeEnrichAnswer({
    required String sourcePluginId,
    required String enrichId,
    required String action,
    required Map<String, dynamic> data,
    required Map<String, dynamic> enrichParams,
    Map<String, dynamic>? auth,
    required Duration timeout,
  }) async {
    Map<String, dynamic>? raw;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      raw = await EngineService.instance.runCatalog(
        pluginId: enrichId,
        action: 'enrich',
        params: enrichParams,
        auth: auth,
        timeout: timeout,
      );
      if (raw != null) break;
    }
    if (raw == null) {
      debugPrint(
        '[catalog] $sourcePluginId enrich via $enrichId skipped (no answer)',
      );
      return null;
    }
    final enriched = parseEnvelope(raw);
    if (enriched == null || !enriched.ok || enriched.data == null) {
      debugPrint(
        '[catalog] $sourcePluginId enrich via $enrichId failed — keeping source',
      );
      return null;
    }

    final merged = Map<String, dynamic>.from(data);
    if (action == 'rail') {
      final items = enriched.data!['items'];
      if (items is List) merged['items'] = items;
    } else {
      final meta = enriched.data!['meta'];
      if (meta is Map) merged['meta'] = Map<String, dynamic>.from(meta);
    }
    return merged;
  }

  /// Kit sets `_hubTmdbEnriched` on meta after [hubApplyTmdbHit]. Skip repeat
  /// companion enrich on cache hits when that marker (or legacy TMDB backdrop)
  /// is already present.
  @visibleForTesting
  static bool envelopeAlreadyEnriched(
    String action,
    Map<String, dynamic>? data,
    Map<String, dynamic> params,
  ) => _envelopeAlreadyEnriched(action, data, params);

  static bool metaTmdbEnriched(Map<String, dynamic> meta) =>
      _metaTmdbEnriched(meta);

  static bool _envelopeAlreadyEnriched(
    String action,
    Map<String, dynamic>? data,
    Map<String, dynamic> params,
  ) {
    if (data == null) return false;
    switch (action) {
      case 'details':
        final meta = data['meta'];
        if (meta is! Map) return false;
        return Map<String, dynamic>.from(meta)['_hubTmdbEnriched'] == true;
      case 'rail':
        final rail = (params['rail'] ?? '').toString().trim();
        if (rail.isNotEmpty && rail != 'spotlight') return false;
        final items = data['items'];
        if (items is! List || items.isEmpty) return false;
        return _itemsTmdbEnriched(items, limit: 5);
      case 'feed':
        final rails = data['rails'];
        if (rails is! Map) return false;
        final spotlight = rails['spotlight'];
        if (spotlight is! List || spotlight.isEmpty) return false;
        return _itemsTmdbEnriched(spotlight, limit: 5);
      default:
        return false;
    }
  }

  static bool _metaTmdbEnriched(Map<String, dynamic> meta) {
    if (meta['_hubTmdbEnriched'] == true) return true;
    final ids = meta['ids'];
    if (ids is! Map) return false;
    final raw = ids['tmdb'];
    if (raw == null || int.tryParse(raw.toString()) == null) return false;
    final bg = (meta['background'] ?? '').toString();
    return bg.contains('image.tmdb.org/t/p/w1280');
  }

  static bool _itemsTmdbEnriched(List items, {required int limit}) {
    final n = limit > 0 ? limit : items.length;
    var checked = 0;
    for (final raw in items) {
      if (checked >= n) break;
      if (raw is! Map) continue;
      checked++;
      if (!_metaTmdbEnriched(Map<String, dynamic>.from(raw))) return false;
    }
    return checked > 0;
  }

  /// Host `kit.list` backends enrich legacy rows via the source pack's `enrich`
  /// companion (same pipe as rail/details).
  Future<List<Map<String, dynamic>>> enrichLegacyListItems({
    required String sourcePluginId,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic> params = const {},
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (items.isEmpty) return items;
    final source = await _resolvePlugin(sourcePluginId);
    final enrichId = source?.enrich?.trim() ?? '';
    if (enrichId.isEmpty || enrichId == sourcePluginId) return items;
    final out = await _mergeEnrichAnswer(
      sourcePluginId: sourcePluginId,
      enrichId: enrichId,
      action: 'rail',
      data: {'items': items},
      enrichParams: {...params, 'items': items},
      auth: null,
      timeout: timeout,
    );
    if (out == null) return items;
    final enriched = out['items'];
    if (enriched is! List) return items;
    return [
      for (final row in enriched)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
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
          )
          .catchError((Object e) {
            debugPrint('[catalog] $pluginId $action revalidate failed: $e');
            return _cachedEnvelope(action, entry);
          })
          .whenComplete(() => _revalidating.remove(key)),
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
