import 'dart:convert';
import 'dart:io';

import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/forja_packs_root.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';

/// Home hub Settings field + play-filter source for stream languages.
abstract final class PluginStreamLanguages {
  static const settingsFieldId = 'streamLanguages';
  static const sourcePluginLanguages = 'pluginLanguages';

  static Map<String, List<PluginLanguage>>? _localProvidersLangs;
  static DateTime? _localProvidersLangsMtime;

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
      for (final e in keys) ?PluginLanguage.tryParseKey(e),
    ];
    // SUB and DUB are exclusive — if both slip in, keep the last kind touched.
    // Spanish `es` is one hub bucket (Sub ES + Latino): never strip the sibling
    // es key when the other kind is selected.
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
        if (l.code == 'es' || kind == null || l.kind == kind) l.key,
    ]..sort();
    await PackSettingsStore.setStringList(
      id,
      settingsFieldId,
      clean,
      reloadHub: false,
    );
  }

  /// Debug: `languages` from local `providers/manifest.json` (mtime-cached).
  ///
  /// Lean installs keep stale plugin metadata while [FORJA_PACKS_ROOT] hot-reloads
  /// JS — overlay so the language dropdown matches the checkout manifest.
  static Map<String, List<PluginLanguage>> localProvidersLanguagesById() {
    final path = ForjaPacksRoot.manifest('providers/manifest.json');
    if (path == null) return const {};
    final file = File(path);
    DateTime? mtime;
    try {
      mtime = file.lastModifiedSync();
    } catch (_) {
      return const {};
    }
    final hit = _localProvidersLangs;
    if (hit != null && _localProvidersLangsMtime == mtime) return hit;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const {};
      final out = <String, List<PluginLanguage>>{};
      final plugins = decoded['plugins'];
      if (plugins is! List) return const {};
      for (final raw in plugins) {
        if (raw is! Map) continue;
        final id = (raw['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final langs = <PluginLanguage>[
          for (final e in (raw['languages'] as List? ?? const []))
            ?PluginLanguage.tryParse(e),
        ];
        if (langs.isNotEmpty) out[id] = langs;
      }
      _localProvidersLangs = out;
      _localProvidersLangsMtime = mtime;
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Stamp local checkout `languages` onto matching plugin ids (debug only).
  static List<EnginePack> overlayLocalProviderLanguages(
    Iterable<EnginePack> packs,
  ) {
    final local = localProvidersLanguagesById();
    if (local.isEmpty) return [for (final p in packs) p];
    return [
      for (final pack in packs)
        pack.copyWithPlugins([
          for (final p in pack.plugins)
            local.containsKey(p.id) ? p.copyWith(languages: local[p.id]!) : p,
        ]),
    ];
  }

  /// Union of declared languages on extractable plugins matching [types].
  ///
  /// [kinds] (`sub` / `dub`) narrows the union; empty = both.
  /// [enabledIds] when set only keeps those plugins (extract gate). Language
  /// **option** lists pass null so the menu mirrors the full manifest union.
  static List<PluginLanguage> unionFromPacks({
    required Iterable<EnginePack> packs,
    required Iterable<String> types,
    Iterable<String> kinds = const [],
    Set<String>? enabledIds,
  }) {
    final want = {
      for (final t in types)
        if (t.trim().isNotEmpty) t.trim().toLowerCase(),
    };
    if (want.isEmpty) return const [];
    final wantKinds = {
      for (final k in kinds)
        if (k.trim().isNotEmpty) k.trim().toLowerCase(),
    };
    final byKey = <String, PluginLanguage>{};
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isExtractable || p.isLive) continue;
        if (enabledIds != null && !enabledIds.contains(p.id)) continue;
        if (!p.types.any((t) => want.contains(t.toLowerCase()))) continue;
        for (final lang in p.languages) {
          if (wantKinds.isNotEmpty && !wantKinds.contains(lang.kind)) continue;
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

  /// When every selected key shares one kind (`sub` / `dub`), return that kind
  /// for extract lane scrape + stream filter. Empty / mixed → null (both).
  ///
  /// Spanish (`es`) is one hub chip that covers Sub ES + Latino/Castellano —
  /// never strip either lane when only ES is selected.
  static String? audioCategoryFromKeys(Iterable<String> selected) {
    String? kind;
    var saw = false;
    var onlyEs = true;
    for (final key in selected) {
      final lang = PluginLanguage.tryParseKey(key);
      if (lang == null) continue;
      saw = true;
      if (lang.code != 'es') onlyEs = false;
      kind ??= lang.kind;
      if (lang.kind != kind) return null;
    }
    if (!saw) return null;
    if (onlyEs) return null;
    return normalizeEngineAudioCategory(kind);
  }
}
