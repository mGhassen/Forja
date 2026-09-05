import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/official_forjahq_packs.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:http/http.dart' as http;

/// Resolve official ForjaHQ packs (catalog filter + baked URL fallback).
Future<List<OfficialForjaHqPack>> resolveOfficialForjaHqPacks() async {
  final byId = {
    for (final p in kOfficialForjaHqPacks) p.id: p,
  };
  try {
    final res = await http
        .get(Uri.parse(kPluginCatalogUrl))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final packs = decoded['packs'];
    if (packs is! List) {
      return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
    }
    final out = <OfficialForjaHqPack>[];
    for (final raw in packs) {
      if (raw is! Map) continue;
      if (raw['official'] != true) continue;
      final id = (raw['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      final baked = byId[id];
      if (baked == null) continue;
      final name = (raw['name'] as String?)?.trim();
      out.add(
        OfficialForjaHqPack(
          id: baked.id,
          name: (name != null && name.isNotEmpty) ? name : baked.name,
          manifestUrl: baked.manifestUrl,
        ),
      );
    }
    if (out.isNotEmpty) return out;
  } catch (e) {
    debugPrint('[OfficialPacks] catalog fetch failed: $e');
  }
  return List<OfficialForjaHqPack>.from(kOfficialForjaHqPacks);
}

typedef OfficialPackInstallProgress = void Function({
  required int done,
  required int total,
  required String status,
});

/// Sequential install of missing official packs. Returns failed pack names.
Future<List<String>> installOfficialForjaHqPacks({
  OfficialPackInstallProgress? onProgress,
}) async {
  final targets = await resolveOfficialForjaHqPacks();
  final installed = await PluginRegistry.instance.listPacksRaw();
  final have = {
    for (final p in installed) p.sourceUrl.trim(),
  };
  final todo = targets
      .where((p) => !have.contains(p.manifestUrl.trim()))
      .toList(growable: false);

  if (todo.isEmpty) {
    onProgress?.call(done: 0, total: 0, status: 'All official packs installed');
    return const [];
  }

  final failures = <String>[];
  for (var i = 0; i < todo.length; i++) {
    final pack = todo[i];
    onProgress?.call(
      done: i,
      total: todo.length,
      status: 'Installing ${pack.name} (${i + 1}/${todo.length})…',
    );
    try {
      await PluginInstallCoordinator.instance.installManifest(pack.manifestUrl);
    } catch (e) {
      debugPrint('[OfficialPacks] install ${pack.id} failed: $e');
      failures.add(pack.name);
    }
  }
  onProgress?.call(
    done: todo.length,
    total: todo.length,
    status: failures.isEmpty ? 'Ready' : 'Finished with errors',
  );
  return failures;
}
