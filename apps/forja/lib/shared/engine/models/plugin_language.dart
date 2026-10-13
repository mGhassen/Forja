import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';

/// Home hub Settings field + play-filter source for stream languages.
abstract final class PluginStreamLanguages {
  static const settingsFieldId = 'streamLanguages';
  static const sourcePluginLanguages = 'pluginLanguages';

  /// Empty selection = run all plugins.
  static Future<Set<String>> selectedKeys(String? hubPluginId) async {
    final id = hubPluginId?.trim() ?? '';
    if (id.isEmpty) return const {};
    final list = await PackSettingsStore.getStringList(
      id,
      settingsFieldId,
      defaultValue: const [],
    );
    return {
      for (final e in list)
        if (PluginLanguage.tryParseKey(e) != null) e.trim().toLowerCase(),
    };
  }

  static Future<void> saveSelectedKeys(
    String hubPluginId,
    Iterable<String> keys,
  ) async {
    final id = hubPluginId.trim();
    if (id.isEmpty) return;
    final parsed = <PluginLanguage>[
      for (final e in keys)
        if (PluginLanguage.tryParseKey(e) case final lang?) lang,
    ];
    // SUB and DUB are exclusive — if both slip in, keep the last kind touched.
    String? lastKind;
    for (final e in keys) {
      final lang = PluginLanguage.tryParseKey(e);
      if (lang != null) lastKind = lang.kind;
    }
    final hasSub = parsed.any((l) => l.kind == 'sub');
    final hasDub = parsed.any((l) => l.kind == 'dub');
    final kind = (hasSub && hasDub) ? (lastKind ?? 'sub') : null;
    final clean = <String>[
      for (final l in parsed)
        if (kind == null || l.kind == kind) l.key,
    ]..sort();
    await PackSettingsStore.setStringList(
      id,
      settingsFieldId,
      clean,
      reloadHub: false,
    );
  }

  /// Union of declared languages on enabled extractable plugins matching [types].
  static List<PluginLanguage> unionFromPacks({
    required Iterable<EnginePack> packs,
    required Iterable<String> types,
    Set<String>? enabledIds,
  }) {
    final want = {
      for (final t in types)
        if (t.trim().isNotEmpty) t.trim().toLowerCase(),
    };
    if (want.isEmpty) return const [];
    final byKey = <String, PluginLanguage>{};
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isExtractable || p.isLive) continue;
        if (enabledIds != null && !enabledIds.contains(p.id)) continue;
        if (!p.types.any((t) => want.contains(t.toLowerCase()))) continue;
        for (final lang in p.languages) {
          byKey.putIfAbsent(lang.key, () => lang);
        }
      }
    }
    final out = byKey.values.toList()
      ..sort((a, b) {
        if (a.kind != b.kind) {
          if (a.kind == 'sub') return -1;
          if (b.kind == 'sub') return 1;
          return a.kind.compareTo(b.kind);
        }
        // VOST / VO (en) always first within kind.
        if (a.code == 'en' && b.code != 'en') return -1;
        if (b.code == 'en' && a.code != 'en') return 1;
        return a.code.compareTo(b.code);
      });
    return out;
  }

  /// Empty [selected] → all. Undeclared languages never match a filter.
  static bool pluginMatches(EnginePlugin plugin, Set<String> selected) {
    if (selected.isEmpty) return true;
    if (plugin.languages.isEmpty) return false;
    for (final lang in plugin.languages) {
      if (selected.contains(lang.key)) return true;
    }
    return false;
  }

  static List<String> filterPluginIds({
    required Iterable<EnginePack> packs,
    required Iterable<String> ids,
    required Set<String> selected,
  }) {
    if (selected.isEmpty) return [for (final id in ids) id];
    final byId = <String, EnginePlugin>{};
    for (final pack in packs) {
      for (final p in pack.plugins) {
        byId[p.id] = p;
      }
    }
    return [
      for (final id in ids)
        if (byId[id] != null && pluginMatches(byId[id]!, selected)) id,
    ];
  }

  /// Stamp selected languages into extract ctx for plugins that scrape by lang.
  static void applyToExtractCtx(
    Map<String, dynamic> extractCtx,
    Set<String> selected,
  ) {
    if (selected.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (final key in selected) {
      final lang = PluginLanguage.tryParseKey(key);
      if (lang == null) continue;
      rows.add(lang.toJson());
    }
    if (rows.isEmpty) return;
    extractCtx['languages'] = rows;
  }
}
