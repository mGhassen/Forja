import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:forja/shared/playback/hubcloud_drive_quota.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nuvio_runtime.dart';

/// One scraper entry inside a Nuvio manifest.
class NuvioScraper {
  final String id;
  final String name;
  final String? description;
  final String? author;
  final String filename; // relative to manifest root
  final List<String> supportedTypes;
  final List<String> contentLanguage;
  final bool enabled;

  NuvioScraper({
    required this.id,
    required this.name,
    this.description,
    this.author,
    required this.filename,
    this.supportedTypes = const ['movie', 'tv'],
    this.contentLanguage = const [],
    this.enabled = true,
  });

  factory NuvioScraper.fromJson(Map<String, dynamic> j) => NuvioScraper(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? j['id'] as String,
    description: j['description'] as String?,
    author: j['author'] as String?,
    filename: (j['filename'] as String?) ?? '',
    supportedTypes: ((j['supportedTypes'] as List?) ?? const ['movie', 'tv'])
        .map((e) => e.toString())
        .toList(),
    contentLanguage: ((j['contentLanguage'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    enabled: (j['enabled'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'author': author,
    'filename': filename,
    'supportedTypes': supportedTypes,
    'contentLanguage': contentLanguage,
    'enabled': enabled,
  };

  NuvioScraper copyWith({bool? enabled}) => NuvioScraper(
    id: id,
    name: name,
    description: description,
    author: author,
    filename: filename,
    supportedTypes: supportedTypes,
    contentLanguage: contentLanguage,
    enabled: enabled ?? this.enabled,
  );
}

class NuvioAddon {
  final String manifestUrl;
  final String name;
  final String version;
  final List<NuvioScraper> scrapers;

  NuvioAddon({
    required this.manifestUrl,
    required this.name,
    required this.version,
    required this.scrapers,
  });

  Map<String, dynamic> toJson() => {
    'manifestUrl': manifestUrl,
    'name': name,
    'version': version,
    'scrapers': scrapers.map((s) => s.toJson()).toList(),
  };

  factory NuvioAddon.fromJson(Map<String, dynamic> j) => NuvioAddon(
    manifestUrl: j['manifestUrl'] as String,
    name: (j['name'] as String?) ?? 'Nuvio Addon',
    version: (j['version'] as String?) ?? '1.0.0',
    scrapers: ((j['scrapers'] as List?) ?? [])
        .map((e) => NuvioScraper.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Per-scraper batch emitted by [NuvioService.streamAll].
class NuvioScraperResult {
  final String scraperId;
  final String scraperName;
  final List<Map<String, dynamic>> streams;
  const NuvioScraperResult({
    required this.scraperId,
    required this.scraperName,
    required this.streams,
  });
}

String? nextNuvioScraperId({
  required Iterable<String> orderedIds,
  required Set<String> selectedIds,
  required Set<String> fetchedIds,
}) {
  for (final id in orderedIds) {
    if (selectedIds.contains(id) && !fetchedIds.contains(id)) return id;
  }
  return null;
}

const kNuvioScraperBatchDesktop = 10;
const kNuvioScraperBatchTv = 5;
const kNuvioScraperBatchSize = kNuvioScraperBatchDesktop;

int nuvioSourcesBatchLimit({required bool tv}) =>
    tv ? kNuvioScraperBatchTv : kNuvioScraperBatchDesktop;

List<String> nextNuvioScraperBatch({
  required Iterable<String> orderedIds,
  required Set<String> selectedIds,
  required Set<String> fetchedIds,
  int limit = kNuvioScraperBatchDesktop,
}) {
  final out = <String>[];
  for (final id in orderedIds) {
    if (out.length >= limit) break;
    if (selectedIds.contains(id) && !fetchedIds.contains(id)) out.add(id);
  }
  return out;
}

bool nuvioStreamBelongsToScraper(Map<String, dynamic> stream, String scraperId) {
  final id = stream['_nuvioScraperId'] as String?;
  if (id != null) return id == scraperId;
  final base = stream['_addonBaseUrl'] as String?;
  return base == 'nuvio:$scraperId';
}

/// Sequential All / open walk: keep going until every selected scraper has
/// been tried. A specific chip tap ([explicitScraper]) is one-shot.
bool shouldContinueNuvioScraperWalk({
  required bool explicitScraper,
  required bool hasPendingSelected,
}) {
  if (explicitScraper) return false;
  return hasPendingSelected;
}

/// Tap All: if every enabled scraper is selected, clear; otherwise select all.
Set<String> nextNuvioSelectedAfterAllTap({
  required Set<String> selectedIds,
  required Set<String> enabledIds,
}) {
  if (enabledIds.isEmpty) return selectedIds;
  final alreadyAll = enabledIds.every(selectedIds.contains);
  return alreadyAll ? <String>{} : Set<String>.from(enabledIds);
}

/// Tap a scraper chip when not in All mode — toggle load selection.
Set<String> nextNuvioSelectedAfterScraperTap({
  required Set<String> selectedIds,
  required String scraperId,
}) {
  if (selectedIds.contains(scraperId)) {
    return Set<String>.from(selectedIds)..remove(scraperId);
  }
  return {...selectedIds, scraperId};
}

/// All group vs provider group — [allMode] + [viewFilterScraperIds] (empty = all).
bool nuvioProviderChipSelected({
  required String optionId,
  required bool allMode,
  required Set<String> selectedScraperIds,
  required Set<String> viewFilterScraperIds,
}) {
  if (optionId == 'all_nuvio') return allMode;
  if (!optionId.startsWith('nuvio:')) return false;
  final scraperId = optionId.substring('nuvio:'.length);
  if (allMode) return viewFilterScraperIds.contains(scraperId);
  return selectedScraperIds.contains(scraperId);
}

/// Enabled scraper ids from Sources-panel addons (order not significant).
Set<String> enabledNuvioScraperIds(Iterable<NuvioAddon> addons) => {
  for (final addon in addons)
    for (final scraper in addon.scrapers)
      if (scraper.enabled) scraper.id,
};

bool nuvioFullAllSelected({
  required Set<String> enabledIds,
  required Set<String> selectedIds,
}) => enabledIds.isNotEmpty && enabledIds.every(selectedIds.contains);

/// Scrapers to fetch when expanding All — only newly selected ids that were
/// never fetched.
Set<String> nuvioScraperIdsToRefetchOnAllExpand({
  required Set<String> previousSelectedIds,
  required Set<String> nextSelectedIds,
  required Set<String> fetchedIds,
}) {
  final newlySelected = nextSelectedIds.difference(previousSelectedIds);
  return {
    for (final id in newlySelected)
      if (!fetchedIds.contains(id)) id,
  };
}

/// Drop stale saved ids that are no longer enabled / installed.
Set<String> filterNuvioSelectedScraperIds({
  required Iterable<String> savedIds,
  required Set<String> enabledIds,
}) => {
  for (final id in savedIds)
    if (enabledIds.contains(id)) id,
};

/// Missing chip selection → all enabled. Empty saved list is explicit none.
Set<String> resolveNuvioSelectedScraperIds({
  required bool selectionSaved,
  required Iterable<String> savedIds,
  required Set<String> enabledIds,
}) {
  if (!selectionSaved) return {...enabledIds};
  return filterNuvioSelectedScraperIds(
    savedIds: savedIds,
    enabledIds: enabledIds,
  );
}

class NuvioStreamResult {
  final String name; // provider display name (e.g. "SFlix (Global)")
  final String title; // verbose title (e.g. "SFlix - 1080p")
  final String url;
  final String? quality;
  final Map<String, String> headers;
  final List<Map<String, String>> subtitles;

  NuvioStreamResult({
    required this.name,
    required this.title,
    required this.url,
    this.quality,
    this.headers = const {},
    this.subtitles = const [],
  });

  /// Maps to the same shape Stremio addons return so existing UI consumes it
  /// without changes.
  Map<String, dynamic> toStremioStream({String? sourceLabel}) {
    return {
      'name': sourceLabel == null ? name : '$sourceLabel · $name',
      'title': title,
      'url': url,
      'description': quality,
      if (headers.isNotEmpty)
        'behaviorHints': {
          'notWebReady': true,
          'proxyHeaders': {'request': headers},
        },
      if (subtitles.isNotEmpty) 'subtitles': subtitles,
      'sourceName': 'Nuvio · ${sourceLabel ?? name}',
    };
  }
}

Map<String, String> _nuvioStreamRequestHeaders(Map<String, dynamic> stream) {
  final hints = stream['behaviorHints'];
  if (hints is! Map) return const {};
  final proxy = hints['proxyHeaders'];
  if (proxy is! Map) return const {};
  final request = proxy['request'];
  if (request is! Map) return const {};
  final out = <String, String>{};
  request.forEach((k, v) {
    final ks = k.toString().trim();
    final vs = v.toString().trim();
    if (ks.isNotEmpty && vs.isNotEmpty) out[ks] = vs;
  });
  return out;
}

class NuvioService {
  NuvioService._();
  static final NuvioService instance = NuvioService._();

  static const String _prefsKey = 'nuvio_addons_v1';
  static const String _scriptCachePrefix = 'nuvio_script_';
  static const String _kvMigratedKey = 'nuvio_addons_kv_v1';
  static const String _scriptsDiskMigratedKey = 'nuvio_scripts_disk_v1_migrated';

  /// Sources → Nuvio chip selection (device KV, same store as addons).
  static const String _sourcesSelectedKey =
      'nuvio_sources_selected_scrapers_v1';
  static const String _sourcesViewFilterKey =
      'nuvio_sources_view_filter_scrapers_v1';

  /// Manifest URLs that ship with the app. Persisted like any other addon so
  /// Settings and Sources share one list (scrapers toggleable / not ghosted).
  static const Set<String> bundledManifestUrls = {
    'https://raw.githubusercontent.com/D3adlyRocket/All-in-One-Nuvio/'
        'refs/heads/main/manifest.json',
  };

  static bool isBundled(String manifestUrl) =>
      bundledManifestUrls.contains(manifestUrl);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  int _scraperGeneration = 0;
  Future<void>? _bundledEnsureFuture;

  /// Abort in-flight scrapers (details panel, player Source checks, etc.).
  /// Bumps generation so Dart callers discard results, and tears down the
  /// shared JS runtime's HTTP/timers so Xpass-style scrapers stop fetching.
  void cancelPending() {
    _scraperGeneration++;
    NuvioRuntime.instance.abortPendingWork();
  }

  Future<void> _ensureAddonsInKv() async {
    if (await kvHasKey(_kvMigratedKey)) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      await kvSetString(_prefsKey, raw);
      await prefs.remove(_prefsKey);
    }
    await kvSetString(_kvMigratedKey, '1');
  }

  Future<List<NuvioAddon>> listAddons() async {
    await _ensureAddonsInKv();
    final raw = await kvGetString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NuvioAddon.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NuvioService] list parse failed: $e');
      return [];
    }
  }

  /// Persists the built-in All-in-One manifest when missing so Settings and
  /// Sources see the same scrapers. Network failures are non-fatal.
  Future<void> ensureBundledInstalled() async {
    final existing = await listAddons();
    if (existing.any((a) => isBundled(a.manifestUrl))) return;
    _bundledEnsureFuture ??= () async {
      try {
        await refreshFromUrl(bundledManifestUrls.first);
        _bundledVirtual = null;
      } catch (e) {
        debugPrint('[NuvioService] bundled ensure failed (non-fatal): $e');
      } finally {
        _bundledEnsureFuture = null;
      }
    }();
    await _bundledEnsureFuture;
  }

  Future<void>? _hydrateLeanInFlight;

  /// Sync / cloud lean rows — URL (+ optional name) only. **No network.**
  /// Full scrapers land via [hydrateLeanInstalled] on first Settings/Sources use.
  Future<void> applyLeanManifestUrls(
    Iterable<Map<String, dynamic>> rows, {
    bool removeMissingUserAddons = true,
  }) async {
    final remote = <String, String?>{};
    for (final raw in rows) {
      final url = (raw['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty) continue;
      final name = (raw['name'] as String?)?.trim();
      remote[url] = (name != null && name.isNotEmpty) ? name : null;
    }

    final all = await listAddons();
    final next = <NuvioAddon>[];
    final victims = <NuvioAddon>[];
    var changed = false;

    for (final addon in all) {
      if (isBundled(addon.manifestUrl)) {
        next.add(addon);
        continue;
      }
      if (removeMissingUserAddons && !remote.containsKey(addon.manifestUrl)) {
        victims.add(addon);
        changed = true;
        continue;
      }
      final leanName = remote[addon.manifestUrl];
      if (leanName != null &&
          addon.scrapers.isEmpty &&
          addon.name != leanName) {
        next.add(
          NuvioAddon(
            manifestUrl: addon.manifestUrl,
            name: leanName,
            version: addon.version,
            scrapers: addon.scrapers,
          ),
        );
        changed = true;
      } else {
        next.add(addon);
      }
    }

    final present = next.map((a) => a.manifestUrl).toSet();
    for (final entry in remote.entries) {
      if (present.contains(entry.key)) continue;
      next.add(
        NuvioAddon(
          manifestUrl: entry.key,
          name: entry.value ?? 'Nuvio Addon',
          version: '0.0.0',
          scrapers: const [],
        ),
      );
      changed = true;
    }

    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      for (final a in victims) {
        for (final s in a.scrapers) {
          await PluginScriptDiskStore.removeNuvioScraper(s.id);
          await prefs.remove(_scriptCachePrefix + s.id);
        }
      }
      await _saveAddons(next);
    }
  }

  /// Fetch manifests for lean stubs (`scrapers` empty). Idempotent; no-op when
  /// every listed addon already has scrapers.
  Future<void> hydrateLeanInstalled() {
    return _hydrateLeanInFlight ??= _hydrateLeanInstalledImpl().whenComplete(
      () {
        _hydrateLeanInFlight = null;
      },
    );
  }

  Future<void> _hydrateLeanInstalledImpl() async {
    final all = await listAddons();
    for (final addon in all) {
      if (addon.scrapers.isNotEmpty) continue;
      try {
        await refreshFromUrl(addon.manifestUrl);
      } catch (e) {
        debugPrint(
          '[NuvioService] lean hydrate failed (${addon.manifestUrl}): $e',
        );
      }
    }
  }

  /// Settings + Sources - same store, including the built-in addon.
  Future<List<NuvioAddon>> listUserAddons() async {
    await ensureBundledInstalled();
    await hydrateLeanInstalled();
    return listAddons();
  }

  /// Scraping list for Sources / batch runs. Prefers the persisted store;
  /// falls back to an in-memory bundled fetch only if ensure failed offline.
  Future<List<NuvioAddon>> listScrapingAddons() async {
    await ensureBundledInstalled();
    await hydrateLeanInstalled();
    final user = await listAddons();
    if (user.any((a) => isBundled(a.manifestUrl))) return user;
    final virt = await _getBundledVirtual();
    if (virt == null) return user;
    return [...user, virt];
  }

  /// Addons with at least one enabled scraper - for Sources panel chrome.
  Future<List<NuvioAddon>> listSourcesPanelAddons() async {
    final addons = await listScrapingAddons();
    return addons.where((a) => a.scrapers.any((s) => s.enabled)).toList();
  }

  /// Persisted Sources → Nuvio scraper chip selection (device profile KV).
  Future<Set<String>> loadSourcesSelectedScraperIds({
    required Set<String> enabledIds,
  }) async {
    await _ensureAddonsInKv();
    final selectionSaved = await kvHasKey(_sourcesSelectedKey);
    if (!selectionSaved) {
      final ids = resolveNuvioSelectedScraperIds(
        selectionSaved: false,
        savedIds: const [],
        enabledIds: enabledIds,
      );
      if (ids.isNotEmpty) {
        await saveSourcesSelectedScraperIds(ids);
      }
      return ids;
    }
    final saved = await kvGetStringList(
      _sourcesSelectedKey,
      fallback: const [],
    );
    return resolveNuvioSelectedScraperIds(
      selectionSaved: true,
      savedIds: saved,
      enabledIds: enabledIds,
    );
  }

  Future<void> saveSourcesSelectedScraperIds(Set<String> ids) async {
    await _ensureAddonsInKv();
    final sorted = ids.toList()..sort();
    await kvSetStringList(_sourcesSelectedKey, sorted);
  }

  /// All-mode scraper chip filters (view-only under All).
  Future<Set<String>> loadSourcesViewFilterScraperIds({
    required Set<String> enabledIds,
  }) async {
    await _ensureAddonsInKv();
    final saved = await kvGetStringList(
      _sourcesViewFilterKey,
      fallback: const [],
    );
    return filterNuvioSelectedScraperIds(
      savedIds: saved,
      enabledIds: enabledIds,
    );
  }

  Future<void> saveSourcesViewFilterScraperIds(Set<String> ids) async {
    await _ensureAddonsInKv();
    final sorted = ids.toList()..sort();
    await kvSetStringList(_sourcesViewFilterKey, sorted);
  }

  /// Offline fallback when [ensureBundledInstalled] cannot reach the network.
  NuvioAddon? _bundledVirtual;

  Future<NuvioAddon?> _getBundledVirtual() async {
    if (_bundledVirtual != null) return _bundledVirtual;
    final url = bundledManifestUrls.first;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return null;
      final mf = jsonDecode(resp.body) as Map<String, dynamic>;
      final scrapers = ((mf['scrapers'] as List?) ?? [])
          .map((e) => NuvioScraper.fromJson(e as Map<String, dynamic>))
          .toList();
      if (scrapers.isEmpty) return null;
      _bundledVirtual = NuvioAddon(
        manifestUrl: url,
        name: (mf['name'] as String?) ?? 'Built-in',
        version: (mf['version'] as String?) ?? '1.0.0',
        scrapers: scrapers,
      );
      return _bundledVirtual;
    } catch (e) {
      debugPrint('[NuvioService] bundled virtual fetch failed: $e');
      return null;
    }
  }

  Future<void> _saveAddons(List<NuvioAddon> addons) async {
    await _ensureAddonsInKv();
    await kvSetString(
      _prefsKey,
      jsonEncode(addons.map((e) => e.toJson()).toList()),
    );
    changeNotifier.value++;
  }

  /// Resolves a relative scraper filename against the manifest URL.
  String _resolveScriptUrl(String manifestUrl, String filename) {
    final mu = Uri.parse(manifestUrl);
    final basePath = mu.pathSegments.isEmpty
        ? '/'
        : '/${mu.pathSegments.sublist(0, mu.pathSegments.length - 1).join('/')}/';
    final base = mu.replace(path: basePath);
    return base.resolve(filename).toString();
  }

  /// Fetches the manifest, persists addon metadata and pre-downloads each
  /// scraper script onto disk (so providers work offline once installed).
  Future<NuvioAddon> install(String manifestUrl) async {
    final resp = await http.get(Uri.parse(manifestUrl));
    if (resp.statusCode != 200) {
      throw Exception('Manifest fetch failed: HTTP ${resp.statusCode}');
    }
    final mf = jsonDecode(resp.body) as Map<String, dynamic>;
    final scrapers = ((mf['scrapers'] as List?) ?? [])
        .map((e) => NuvioScraper.fromJson(e as Map<String, dynamic>))
        .toList();
    if (scrapers.isEmpty) {
      throw Exception('Manifest has no scrapers');
    }
    final addon = NuvioAddon(
      manifestUrl: manifestUrl,
      name: (mf['name'] as String?) ?? 'Nuvio Addon',
      version: (mf['version'] as String?) ?? '1.0.0',
      scrapers: scrapers,
    );

    // Pre-download every scraper script. Failures here are non-fatal - the
    // user can still toggle them and retry later; getStreams will redownload.
    for (final s in scrapers) {
      try {
        final scriptUrl = _resolveScriptUrl(manifestUrl, s.filename);
        final scriptResp = await http.get(Uri.parse(scriptUrl));
        if (scriptResp.statusCode == 200 && scriptResp.body.isNotEmpty) {
          await PluginScriptDiskStore.saveNuvioScraper(
            scraperId: s.id,
            body: scriptResp.body,
          );
        }
      } catch (e) {
        debugPrint('[NuvioService] script prefetch failed (${s.id}): $e');
      }
    }

    final all = await listAddons();
    final idx = all.indexWhere((a) => a.manifestUrl == manifestUrl);
    if (idx >= 0) {
      all[idx] = addon;
    } else {
      all.add(addon);
    }
    await _saveAddons(all);
    return addon;
  }

  /// Lightweight refresh - fetches the manifest, merges the new scraper list
  /// with the existing one (preserving each scraper's `enabled` flag), and
  /// invalidates cached scripts whose source filename changed. Does NOT
  /// pre-download every script (those load lazily on first use). Safe to
  /// call on every app launch.
  Future<NuvioAddon> refreshFromUrl(String manifestUrl) async {
    final resp = await http.get(Uri.parse(manifestUrl));
    if (resp.statusCode != 200) {
      throw Exception('Manifest fetch failed: HTTP ${resp.statusCode}');
    }
    final mf = jsonDecode(resp.body) as Map<String, dynamic>;
    final freshScrapers = ((mf['scrapers'] as List?) ?? [])
        .map((e) => NuvioScraper.fromJson(e as Map<String, dynamic>))
        .toList();
    if (freshScrapers.isEmpty) {
      throw Exception('Manifest has no scrapers');
    }

    final all = await listAddons();
    final existing = all.where((a) => a.manifestUrl == manifestUrl).toList();
    final priorEnabled = <String, bool>{};
    final priorFilenames = <String, String>{};
    if (existing.isNotEmpty) {
      for (final s in existing.first.scrapers) {
        priorEnabled[s.id] = s.enabled;
        priorFilenames[s.id] = s.filename;
      }
    }

    // De-dupe by id (some manifests list the same scraper twice).
    final seen = <String>{};
    final merged = <NuvioScraper>[];
    for (final s in freshScrapers) {
      if (!seen.add(s.id)) continue;
      final preservedEnabled = priorEnabled[s.id] ?? s.enabled;
      merged.add(s.copyWith(enabled: preservedEnabled));
    }

    // Evict cached scripts whose source filename changed (or that no longer
    // exist in the manifest).
    final prefs = await SharedPreferences.getInstance();
    final newIds = merged.map((s) => s.id).toSet();
    for (final id in priorFilenames.keys) {
      if (!newIds.contains(id)) {
        await PluginScriptDiskStore.removeNuvioScraper(id);
        await prefs.remove(_scriptCachePrefix + id);
      }
    }
    for (final s in merged) {
      final priorFn = priorFilenames[s.id];
      if (priorFn != null && priorFn != s.filename) {
        await PluginScriptDiskStore.removeNuvioScraper(s.id);
        await prefs.remove(_scriptCachePrefix + s.id);
      }
    }

    final addon = NuvioAddon(
      manifestUrl: manifestUrl,
      name: (mf['name'] as String?) ?? 'Nuvio Addon',
      version: (mf['version'] as String?) ?? '1.0.0',
      scrapers: merged,
    );
    final idx = all.indexWhere((a) => a.manifestUrl == manifestUrl);
    if (idx >= 0) {
      all[idx] = addon;
    } else {
      all.add(addon);
    }
    await _saveAddons(all);
    return addon;
  }

  Future<void> remove(String manifestUrl, {bool purgeScripts = true}) async {
    if (isBundled(manifestUrl)) {
      throw Exception('Built-in Nuvio addon cannot be removed');
    }
    final all = await listAddons();
    final removed = all.where((a) => a.manifestUrl == manifestUrl).toList();
    all.removeWhere((a) => a.manifestUrl == manifestUrl);
    final prefs = await SharedPreferences.getInstance();
    for (final a in removed) {
      for (final s in a.scrapers) {
        if (purgeScripts) {
          await PluginScriptDiskStore.removeNuvioScraper(s.id);
        }
        await prefs.remove(_scriptCachePrefix + s.id);
      }
    }
    await _saveAddons(all);
  }

  Future<void> setScraperEnabled({
    required String manifestUrl,
    required String scraperId,
    required bool enabled,
  }) async {
    if (isBundled(manifestUrl)) {
      await ensureBundledInstalled();
    }
    final all = await listAddons();
    final idx = all.indexWhere((a) => a.manifestUrl == manifestUrl);
    if (idx == -1) return;
    final addon = all[idx];
    final newScrapers = addon.scrapers
        .map((s) => s.id == scraperId ? s.copyWith(enabled: enabled) : s)
        .toList();
    all[idx] = NuvioAddon(
      manifestUrl: addon.manifestUrl,
      name: addon.name,
      version: addon.version,
      scrapers: newScrapers,
    );
    await _saveAddons(all);
  }

  /// Enable or disable every scraper in one addon (built-in included).
  Future<void> setAllScrapersEnabled({
    required String manifestUrl,
    required bool enabled,
  }) async {
    if (isBundled(manifestUrl)) {
      await ensureBundledInstalled();
    }
    final all = await listAddons();
    final idx = all.indexWhere((a) => a.manifestUrl == manifestUrl);
    if (idx == -1) return;
    final addon = all[idx];
    if (addon.scrapers.every((s) => s.enabled == enabled)) return;
    all[idx] = NuvioAddon(
      manifestUrl: addon.manifestUrl,
      name: addon.name,
      version: addon.version,
      scrapers: [
        for (final s in addon.scrapers) s.copyWith(enabled: enabled),
      ],
    );
    await _saveAddons(all);
  }

  /// Refreshes every installed addon's manifest in parallel. Safe to call
  /// on every app launch - [refreshFromUrl] preserves each scraper's
  /// `enabled` flag and only invalidates cached scripts whose filename
  /// changed. New scrapers added upstream show up automatically; removed
  /// ones get their cached scripts evicted. Failures are non-fatal so an
  /// offline launch doesn't break anything.
  Future<void> refreshAllInstalled() async {
    await ensureBundledInstalled();
    final addons = await listAddons();
    if (addons.isEmpty) return;
    await Future.wait(
      addons.map((a) async {
        try {
          await refreshFromUrl(a.manifestUrl);
          debugPrint('[NuvioService] refreshed ${a.manifestUrl}');
        } catch (e) {
          debugPrint('[NuvioService] refresh failed (${a.manifestUrl}): $e');
        }
      }),
    );
    _bundledVirtual = null;
  }

  Future<String?> _loadScriptBody(
    NuvioAddon addon,
    NuvioScraper s, {
    bool forceFresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Always try the network first - community scrapers get hot-fixed
    // upstream and we want users on the latest code without reinstalling.
    // Cache is only used as an offline fallback.
    try {
      final url = _resolveScriptUrl(addon.manifestUrl, s.filename);
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200 && r.body.isNotEmpty) {
        await PluginScriptDiskStore.saveNuvioScraper(
          scraperId: s.id,
          body: r.body,
        );
        await prefs.remove(_scriptCachePrefix + s.id);
        return r.body;
      }
    } catch (e) {
      debugPrint('[NuvioService] script fetch failed (${s.id}): $e');
    }
    if (forceFresh) return null;
    final disk = await PluginScriptDiskStore.loadNuvioScraper(s.id);
    if (disk != null && disk.isNotEmpty) return disk;
    final cached = prefs.getString(_scriptCachePrefix + s.id);
    if (cached != null && cached.isNotEmpty) {
      await PluginScriptDiskStore.saveNuvioScraper(
        scraperId: s.id,
        body: cached,
      );
      await prefs.remove(_scriptCachePrefix + s.id);
      return cached;
    }
    return null;
  }

  /// One-time: prefs `nuvio_script_*` → disk.
  Future<void> migrateScriptsToDiskIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_scriptsDiskMigratedKey) == true) return;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_scriptCachePrefix)) continue;
      final id = key.substring(_scriptCachePrefix.length);
      if (id.isEmpty) continue;
      final body = prefs.getString(key);
      if (body == null || body.isEmpty) {
        await prefs.remove(key);
        continue;
      }
      await PluginScriptDiskStore.saveNuvioScraper(scraperId: id, body: body);
      await prefs.remove(key);
    }
    await prefs.setBool(_scriptsDiskMigratedKey, true);
    debugPrint('[NuvioService] migrated scraper scripts to disk');
  }

  /// Prefetch any scraper missing from disk (boot coordinator).
  Future<void> ensureScriptsOnDisk() async {
    final addons = await listAddons();
    for (final addon in addons) {
      for (final s in addon.scrapers) {
        if (s.filename.isEmpty) continue;
        if (await PluginScriptDiskStore.hasNuvioScraper(s.id)) continue;
        try {
          final url = _resolveScriptUrl(addon.manifestUrl, s.filename);
          final r = await http.get(Uri.parse(url));
          if (r.statusCode == 200 && r.body.isNotEmpty) {
            await PluginScriptDiskStore.saveNuvioScraper(
              scraperId: s.id,
              body: r.body,
            );
          }
        } catch (e) {
          debugPrint('[NuvioService] ensureScriptsOnDisk (${s.id}): $e');
        }
      }
    }
  }

  /// Runs every enabled scraper that supports [type] in parallel and
  /// returns Stremio-shaped stream maps ready to merge into the existing
  /// streams list. [type] is either 'movie' or 'tv'.
  Future<List<Map<String, dynamic>>> getStreams({
    required String tmdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    final gen = _scraperGeneration;
    final addons = await listScrapingAddons();
    if (addons.isEmpty || gen != _scraperGeneration) return [];
    final futures = <Future<List<Map<String, dynamic>>>>[];
    for (final addon in addons) {
      for (final s in addon.scrapers) {
        if (!s.enabled) continue;
        if (s.supportedTypes.isNotEmpty &&
            !s.supportedTypes.contains(type) &&
            !(type == 'tv' && s.supportedTypes.contains('series'))) {
          continue;
        }
        futures.add(_runOne(addon, s, tmdbId, type, season, episode, gen));
      }
    }
    if (futures.isEmpty) return [];
    final results = await Future.wait(futures);
    if (gen != _scraperGeneration) return [];
    return results.expand((e) => e).toList();
  }

  /// Streaming variant - emits a [NuvioScraperResult] for every enabled
  /// scraper as soon as it finishes (or fails / times out, in which case
  /// `streams` is empty). The stream closes when every scraper has
  /// reported. Call [cancelPending] to abort in-flight scrapers (HTTP +
  /// JS timers); cancelling only the subscription stops UI updates but
  /// used to leave scrapers running - that path now also honors generation.
  Stream<NuvioScraperResult> streamAll({
    required String tmdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) {
    final ctrl = StreamController<NuvioScraperResult>();
    final gen = _scraperGeneration;
    () async {
      try {
        final addons = await listScrapingAddons();
        if (gen != _scraperGeneration) return;
        final tasks = <Future<void>>[];
        for (final addon in addons) {
          for (final s in addon.scrapers) {
            if (!s.enabled) continue;
            if (s.supportedTypes.isNotEmpty &&
                !s.supportedTypes.contains(type) &&
                !(type == 'tv' && s.supportedTypes.contains('series'))) {
              continue;
            }
            tasks.add(() async {
              final streams = await _runOne(
                addon,
                s,
                tmdbId,
                type,
                season,
                episode,
                gen,
              );
              if (gen != _scraperGeneration || ctrl.isClosed) return;
              ctrl.add(
                NuvioScraperResult(
                  scraperId: s.id,
                  scraperName: s.name,
                  streams: streams,
                ),
              );
            }());
          }
        }
        await Future.wait(tasks);
      } catch (e, st) {
        if (!ctrl.isClosed && gen == _scraperGeneration) {
          ctrl.addError(e, st);
        }
      } finally {
        if (!ctrl.isClosed) await ctrl.close();
      }
    }();
    return ctrl.stream;
  }

  /// Runs one Sources-panel scraper. Callers choose the next scraper so the
  /// panel can fetch providers lazily instead of starting every scraper.
  Future<NuvioScraperResult?> runSourcesScraper({
    required String scraperId,
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    final gen = _scraperGeneration;
    final addons = await listScrapingAddons();
    if (gen != _scraperGeneration) return null;

    for (final addon in addons) {
      for (final scraper in addon.scrapers) {
        if (scraper.id != scraperId || !scraper.enabled) continue;
        if (scraper.supportedTypes.isNotEmpty &&
            !scraper.supportedTypes.contains(type) &&
            !(type == 'tv' && scraper.supportedTypes.contains('series'))) {
          return NuvioScraperResult(
            scraperId: scraper.id,
            scraperName: scraper.name,
            streams: const [],
          );
        }
        final streams = await _runOne(
          addon,
          scraper,
          tmdbId,
          type,
          season,
          episode,
          gen,
        );
        if (gen != _scraperGeneration) return null;
        return NuvioScraperResult(
          scraperId: scraper.id,
          scraperName: scraper.name,
          streams: streams,
        );
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _runOne(
    NuvioAddon addon,
    NuvioScraper s,
    String tmdbId,
    String type,
    int? season,
    int? episode,
    int gen,
  ) async {
    try {
      if (gen != _scraperGeneration) return [];
      final code = await _loadScriptBody(addon, s);
      if (gen != _scraperGeneration || code == null) return [];
      final rt = NuvioRuntime.instance;
      if (!rt.isLoaded(s.id)) {
        await rt.loadScraper(scraperId: s.id, code: code);
      }
      if (gen != _scraperGeneration) return [];
      final raw = await rt.getStreams(
        scraperId: s.id,
        tmdbId: tmdbId,
        mediaType: type,
        season: season,
        episode: episode,
        isCancelled: () => gen != _scraperGeneration,
      );
      if (gen != _scraperGeneration) return [];
      final mapped = raw
          .map((m) {
            final headers = <String, String>{};
            final h = m['headers'];
            if (h is Map) {
              h.forEach((k, v) => headers[k.toString()] = v.toString());
            }
            final subs = <Map<String, String>>[];
            final sl = m['subtitles'];
            if (sl is List) {
              for (final sub in sl) {
                if (sub is Map) {
                  subs.add({
                    'url': sub['url']?.toString() ?? '',
                    'lang':
                        sub['lang']?.toString() ??
                        sub['label']?.toString() ??
                        'Unknown',
                  });
                }
              }
            }
            final out = NuvioStreamResult(
              name: (m['name'] ?? s.name).toString(),
              title: (m['title'] ?? m['name'] ?? s.name).toString(),
              url: (m['url'] ?? '').toString(),
              quality: m['quality']?.toString(),
              headers: headers,
              subtitles: subs,
            );
            return out.toStremioStream(sourceLabel: s.name);
          })
          .where((m) => (m['url'] as String?)?.isNotEmpty == true)
          .toList();
      return dropHubCloudDriveQuotaRows(
        rows: mapped,
        urlOf: (m) => m['url']?.toString() ?? '',
        headersOf: _nuvioStreamRequestHeaders,
        isCancelled: () => gen != _scraperGeneration,
      );
    } catch (e) {
      debugPrint('[NuvioService] ${s.id} failed: $e');
      return [];
    }
  }

  /// Runs a single scraper by id and returns the raw [NuvioStreamResult] list
  /// (NOT mapped to the Stremio shape). Used by the streaming-mode pipeline,
  /// which needs per-stream URLs + headers to build a [StreamSource] list for
  /// the player's multi-link menu.
  Future<List<NuvioStreamResult>> runOneScraper({
    required String scraperId,
    required String tmdbId,
    required String type, // 'movie' or 'tv'
    int? season,
    int? episode,
  }) async {
    final gen = _scraperGeneration;
    final addons = await listScrapingAddons();
    if (gen != _scraperGeneration) return const [];
    NuvioAddon? owner;
    NuvioScraper? target;
    for (final a in addons) {
      for (final s in a.scrapers) {
        if (s.id == scraperId) {
          owner = a;
          target = s;
          break;
        }
      }
      if (owner != null) break;
    }
    if (owner == null || target == null) return const [];
    if (gen != _scraperGeneration) return const [];

    try {
      final code = await _loadScriptBody(owner, target, forceFresh: true);
      if (gen != _scraperGeneration) return const [];
      if (code == null) return const [];
      final rt = NuvioRuntime.instance;
      await rt.loadScraper(scraperId: target.id, code: code);
      if (gen != _scraperGeneration) return const [];
      final raw = await rt.getStreams(
        scraperId: target.id,
        tmdbId: tmdbId,
        mediaType: type,
        season: season,
        episode: episode,
        isCancelled: () => gen != _scraperGeneration,
      );
      if (gen != _scraperGeneration) return const [];
      final out = <NuvioStreamResult>[];
      for (final m in raw) {
        final url = (m['url'] ?? '').toString();
        if (url.isEmpty) continue;
        final headers = <String, String>{};
        final h = m['headers'];
        if (h is Map) {
          h.forEach((k, v) => headers[k.toString()] = v.toString());
        }
        final subs = <Map<String, String>>[];
        final sl = m['subtitles'];
        if (sl is List) {
          for (final sub in sl) {
            if (sub is Map) {
              subs.add({
                'url': sub['url']?.toString() ?? '',
                'lang':
                    sub['lang']?.toString() ??
                    sub['label']?.toString() ??
                    'Unknown',
              });
            }
          }
        }
        out.add(
          NuvioStreamResult(
            name: (m['name'] ?? target.name).toString(),
            title: (m['title'] ?? m['name'] ?? target.name).toString(),
            url: url,
            quality: m['quality']?.toString(),
            headers: headers,
            subtitles: subs,
          ),
        );
      }
      return dropHubCloudDriveQuotaRows(
        rows: out,
        urlOf: (r) => r.url,
        headersOf: (r) => r.headers,
        isCancelled: () => gen != _scraperGeneration,
      );
    } catch (e) {
      debugPrint('[NuvioService] runOneScraper(${target.id}) failed: $e');
      return const [];
    }
  }
}
