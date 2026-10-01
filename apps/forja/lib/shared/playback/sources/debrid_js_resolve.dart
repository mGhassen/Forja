import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/engine/runtime/vm/service.dart';
import 'package:rust/rust.dart';

List<({String id, String name})> _installedDebrid = const [];

/// Sync catalog of installed active `kind: debrid` plugins.
Future<void> syncDebridResolveCatalog() async {
  final packs = await EngineService.instance.listPacks();
  final out = <({String id, String name})>[];
  for (final pack in packs) {
    if (!pack.enabled) continue;
    for (final plugin in pack.plugins) {
      if (!plugin.isDebrid || !pack.isPluginActive(plugin)) continue;
      out.add((id: plugin.id, name: plugin.name));
    }
  }
  _installedDebrid = List.unmodifiable(out);
}

List<({String id, String name})> installedDebridPlugins() =>
    List<({String id, String name})>.from(_installedDebrid);

/// Pref id when still installed + active; otherwise null.
Future<String?> activeDebridPluginId() async {
  await syncDebridResolveCatalog();
  final id = (await SettingsService().getMagnetResolvePluginId()).trim();
  if (id.isEmpty) return null;
  for (final p in _installedDebrid) {
    if (p.id == id) return id;
  }
  return null;
}

String? _activeDebridPluginIdSync() {
  final id = SettingsService().getMagnetResolvePluginIdSync().trim();
  if (id.isEmpty) return null;
  // Catalog hydrated → require still installed+active.
  if (_installedDebrid.isNotEmpty) {
    for (final p in _installedDebrid) {
      if (p.id == id) return id;
    }
    return null;
  }
  // Pref only until first sync (resolve re-validates via activeDebridPluginId).
  return id;
}

String? _activeDebridPluginLabelSync() {
  final id = _activeDebridPluginIdSync();
  if (id == null) return null;
  for (final p in _installedDebrid) {
    if (p.id == id) return p.name;
  }
  return id;
}

TorrentPlaybackUrl? _playbackUrlFromDebridRows(
  List<Map<String, dynamic>> rows, {
  required String label,
  int? fileIdx,
}) {
  for (final row in rows) {
    final files = row['files'];
    if (files is List && files.isNotEmpty) {
      final idx = (fileIdx != null && fileIdx >= 0 && fileIdx < files.length)
          ? fileIdx
          : 0;
      final file = files[idx];
      if (file is Map) {
        final url = (file['url'] ?? '').toString().trim();
        if (url.isNotEmpty) {
          return TorrentPlaybackUrl(
            url,
            fileIndex: idx,
            source: TorrentPlaybackSource.debrid,
            sourceLabel: label,
          );
        }
      }
    }
    final url = (row['url'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      return TorrentPlaybackUrl(
        url,
        fileIndex: fileIdx ?? 0,
        source: TorrentPlaybackSource.debrid,
        sourceLabel: label,
      );
    }
  }
  return null;
}

Future<TorrentPlaybackUrl?> resolveMagnetViaDebridPack({
  required String magnet,
  int? season,
  int? episode,
  int? fileIdx,
}) async {
  final pluginId = await activeDebridPluginId();
  if (pluginId == null) return null;
  final label = _activeDebridPluginLabelSync() ?? pluginId;
  final rows = await EngineService.instance.runDebridResolve(
    pluginId: pluginId,
    magnet: magnet,
    season: season,
    episode: episode,
    fileIdx: fileIdx,
  );
  final hit = _playbackUrlFromDebridRows(rows, label: label, fileIdx: fileIdx);
  if (hit == null) {
    throw Exception('debrid resolve failed');
  }
  return hit;
}

/// One-shot: SecureSettings vendor keys → pack `apiKey` secrets.
Future<void> migrateLegacyDebridSecretsToPackStore() async {
  Future<void> migrate(String secureKey, String pluginId) async {
    final existing = await PackSettingsStore.getSecret(pluginId, 'apiKey');
    if (existing.isNotEmpty) return;
    try {
      final legacy = await SecureSettings.read(secureKey);
      if (legacy == null || legacy.trim().isEmpty) return;
      await PackSettingsStore.setSecret(pluginId, 'apiKey', legacy.trim());
    } catch (e) {
      debugPrint('[debrid] secret migrate $pluginId failed: $e');
    }
  }

  await migrate(SecureSettings.rdAccessToken, 'realdebrid');
  await migrate(SecureSettings.torboxApiKey, 'torbox');
  await migrate(SecureSettings.alldebridApiKey, 'alldebrid');
  await migrate(SecureSettings.premiumizeApiKey, 'premiumize');
  await migrate(SecureSettings.debridlinkApiKey, 'debrid_link');
}

void registerDebridPackBridge() {
  DebridPackBridge.register(
    resolveFn: resolveMagnetViaDebridPack,
    pluginId: _activeDebridPluginIdSync,
    pluginLabel: _activeDebridPluginLabelSync,
  );
  unawaited(() async {
    await SettingsService().getMagnetResolvePluginId();
    await syncDebridResolveCatalog();
  }());
}
