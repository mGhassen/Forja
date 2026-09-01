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

Future<List<Map<String, dynamic>>> searchTorrentsViaPlugins(
  String query, {
  String? imdbId,
  int? season,
  int? episode,
  List<String>? enabledProviders,
}) async {
  await syncTorrentSearchCatalog();
  final enabled = enabledProviders ??
      await SettingsService().getEnabledTorrentProviders();
  if (enabled.isEmpty) return [];

  final batches = await Future.wait([
    for (final id in enabled)
      EngineService.instance.runTorrentSearch(
        pluginId: id,
        query: query,
        imdbId: imdbId,
        season: season,
        episode: episode,
      ),
  ]);

  final byMagnet = <String, Map<String, dynamic>>{};
  for (final batch in batches) {
    TorrentSearchProviders.mergeByMagnet(byMagnet, batch);
  }
  return byMagnet.values.toList();
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
  final enabled = enabledProviders ??
      await SettingsService().getEnabledTorrentProviders();
  if (enabled.isEmpty) return [];

  bool cancelled() => isCancelled?.call() == true;

  if (enabled.length == 1) {
    List<Map<String, dynamic>> one = const [];
    try {
      one = await EngineService.instance.runTorrentSearch(
        pluginId: enabled.first,
        query: query,
        imdbId: imdbId,
        season: season,
        episode: episode,
        isCancelled: isCancelled,
      );
    } catch (_) {}
    if (cancelled()) return [];
    onProviderDone?.call(enabled.first);
    onPartial?.call(one);
    return one;
  }

  final byMagnet = <String, Map<String, dynamic>>{};
  await Future.wait([
    for (final id in enabled)
      () async {
        List<Map<String, dynamic>> batch = const [];
        try {
          batch = await EngineService.instance.runTorrentSearch(
            pluginId: id,
            query: query,
            imdbId: imdbId,
            season: season,
            episode: episode,
            isCancelled: isCancelled,
          );
        } catch (_) {}
        if (cancelled()) return;
        onProviderDone?.call(id);
        TorrentSearchProviders.mergeByMagnet(byMagnet, batch);
        onPartial?.call(List<Map<String, dynamic>>.from(byMagnet.values));
      }(),
  ]);
  if (cancelled()) return [];
  return byMagnet.values.toList();
}

void registerTorrentSearchBridge() {
  TorrentSearchBridge.register(
    search: searchTorrentsViaPlugins,
    progressive: searchTorrentsProgressiveViaPlugins,
  );
}
