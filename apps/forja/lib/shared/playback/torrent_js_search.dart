import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:rust/rust.dart';

/// Sync [TorrentSearchCatalog] from installed `kind: torrent` plugins.
Future<void> syncTorrentSearchCatalog() async {
  final packs = await EngineService.instance.listPacks();
  final metas = <TorrentSearchProviderMeta>[];
  for (final pack in packs) {
    if (!pack.enabled) continue;
    for (final plugin in pack.plugins) {
      if (!plugin.isTorrent || !pack.isPluginActive(plugin)) continue;
      final source = plugin.config['source']?.toString().trim();
      metas.add(
        TorrentSearchProviderMeta(
          id: plugin.id,
          label: plugin.name,
          resultSource: (source != null && source.isNotEmpty)
              ? source
              : plugin.name,
        ),
      );
    }
  }
  if (metas.isNotEmpty) {
    TorrentSearchCatalog.update(metas);
  } else {
    TorrentSearchCatalog.clear();
  }
}

/// Enabled torrent indexer ids — pack on and per-plugin toggle in Sources → Forja.
List<String> enabledTorrentSearchPluginIds() =>
    List<String>.from(TorrentSearchCatalog.allIds);

/// One JS heap per search — indexers run sequentially so we never spin up N
/// parallel QuickJS VMs (that OOM-killed desktop when all 9 providers fired).
Future<List<Map<String, dynamic>>> _searchIndexersSequential({
  required List<String> enabled,
  required String query,
  String? imdbId,
  int? season,
  int? episode,
  bool Function()? isCancelled,
  void Function(List<Map<String, dynamic>> soFar)? onPartial,
  void Function(String providerId)? onProviderDone,
}) async {
  bool cancelled() => isCancelled?.call() == true;

  final rt = EngineRuntime.fork();
  final byMagnet = <String, Map<String, dynamic>>{};
  try {
    for (final id in enabled) {
      if (cancelled()) break;
      List<Map<String, dynamic>> batch = const [];
      try {
        batch = await EngineService.instance.runTorrentSearch(
          pluginId: id,
          query: query,
          imdbId: imdbId,
          season: season,
          episode: episode,
          isCancelled: isCancelled,
          runtime: rt,
        );
      } catch (e) {
        debugPrint('[torrent] search $id failed: $e');
      }
      if (cancelled()) break;
      onProviderDone?.call(id);
      TorrentSearchProviders.mergeByMagnet(byMagnet, batch);
      onPartial?.call(List<Map<String, dynamic>>.from(byMagnet.values));
    }
  } finally {
    rt.dispose();
  }
  if (cancelled()) return [];
  return byMagnet.values.toList();
}

Future<List<Map<String, dynamic>>> searchTorrentsViaPlugins(
  String query, {
  String? imdbId,
  int? season,
  int? episode,
  List<String>? enabledProviders,
}) async {
  await syncTorrentSearchCatalog();
  final enabled = enabledProviders ?? enabledTorrentSearchPluginIds();
  if (enabled.isEmpty) {
    debugPrint(
      '[torrent] search skipped: no enabled indexers '
      '(installed=${TorrentSearchCatalog.allIds.length})',
    );
    return [];
  }

  return _searchIndexersSequential(
    enabled: enabled,
    query: query,
    imdbId: imdbId,
    season: season,
    episode: episode,
  );
}

Future<List<Map<String, dynamic>>> searchTorrentsProgressiveViaPlugins(
  String query, {
  String? imdbId,
  int? season,
  int? episode,
  List<String>? enabledProviders,
  void Function(List<Map<String, dynamic>> soFar)? onPartial,
  void Function(String providerId)? onProviderDone,
  bool Function()? isCancelled,
}) async {
  await syncTorrentSearchCatalog();
  final enabled = enabledProviders ?? enabledTorrentSearchPluginIds();
  if (enabled.isEmpty) {
    debugPrint(
      '[torrent] search skipped: no enabled indexers '
      '(installed=${TorrentSearchCatalog.allIds.length})',
    );
    return [];
  }

  return _searchIndexersSequential(
    enabled: enabled,
    query: query,
    imdbId: imdbId,
    season: season,
    episode: episode,
    isCancelled: isCancelled,
    onPartial: onPartial,
    onProviderDone: onProviderDone,
  );
}

void registerTorrentSearchBridge() {
  TorrentSearchBridge.register(
    search: searchTorrentsViaPlugins,
    progressive: searchTorrentsProgressiveViaPlugins,
  );
}
