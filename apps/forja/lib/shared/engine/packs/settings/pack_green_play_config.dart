import 'dart:convert';

import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/settings/pack_settings_store.dart';
import 'package:forja/shared/playback/open/play_source_effective.dart';

/// Opaque tech ids for pack-owned green Play (RFC-118).
abstract final class PackGreenPlayTechs {
  static const engine = 'engine';
  static const stremio = 'stremio';
  static const nuvio = 'nuvio';
  static const torrent = 'torrent';

  static const all = <String>[engine, stremio, nuvio, torrent];

  static String label(String id) => switch (id) {
        engine => 'Forja',
        stremio => 'Stremio',
        nuvio => 'Nuvio',
        torrent => 'Direct torrent',
        _ => id,
      };
}

/// Per-tech provider allowlist / preferred / order.
class PackGreenPlayProviderPrefs {
  const PackGreenPlayProviderPrefs({
    this.allowlist = const [],
    this.preferred = const [],
    this.order = const [],
  });

  /// Empty = all currently enabled providers for this tech.
  final List<String> allowlist;
  final List<String> preferred;
  final List<String> order;

  Map<String, dynamic> toJson() => {
        'allowlist': allowlist,
        'preferred': preferred,
        'order': order,
      };

  static PackGreenPlayProviderPrefs fromJson(Object? raw) {
    if (raw is! Map) return const PackGreenPlayProviderPrefs();
    final m = Map<String, dynamic>.from(raw);
    return PackGreenPlayProviderPrefs(
      allowlist: _stringList(m['allowlist']),
      preferred: _stringList(m['preferred']),
      order: _stringList(m['order']),
    );
  }
}

/// Pack `settings.greenPlay` + user overlay (RFC-118).
class PackGreenPlayConfig {
  const PackGreenPlayConfig({
    this.techAllowlist = const [PackGreenPlayTechs.engine],
    this.techPreferred = const [],
    this.techOrder = const [PackGreenPlayTechs.engine],
    this.providers = const {},
  });

  /// Host fallback when the hub pack omits `settings.greenPlay`.
  static const hostFallback = PackGreenPlayConfig();

  /// Forja-only preferred list (Settings UI). Empty preferred = race all enabled.
  factory PackGreenPlayConfig.forjaPreferred(List<String> preferred) {
    final prefs = [
      for (final id in preferred)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    return PackGreenPlayConfig(
      techAllowlist: const [PackGreenPlayTechs.engine],
      techPreferred: const [PackGreenPlayTechs.engine],
      techOrder: const [PackGreenPlayTechs.engine],
      providers: {
        PackGreenPlayTechs.engine: PackGreenPlayProviderPrefs(
          preferred: prefs,
          order: prefs,
        ),
      },
    );
  }

  final List<String> techAllowlist;
  final List<String> techPreferred;
  final List<String> techOrder;
  final Map<String, PackGreenPlayProviderPrefs> providers;

  static const fieldId = 'greenPlay';

  PackGreenPlayProviderPrefs providerPrefs(String tech) =>
      providers[tech] ?? const PackGreenPlayProviderPrefs();

  Map<String, dynamic> toJson() => {
        'technologies': {
          'allowlist': techAllowlist,
          'preferred': techPreferred,
          'order': techOrder,
        },
        'providers': {
          for (final e in providers.entries) e.key: e.value.toJson(),
        },
      };

  static PackGreenPlayConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final techRaw = m['technologies'];
    var allow = const <String>[PackGreenPlayTechs.engine];
    var preferred = const <String>[];
    var order = const <String>[PackGreenPlayTechs.engine];
    if (techRaw is Map) {
      final t = Map<String, dynamic>.from(techRaw);
      final a = _stringList(t['allowlist']);
      if (a.isNotEmpty) allow = a;
      preferred = _stringList(t['preferred']);
      final o = _stringList(t['order']);
      if (o.isNotEmpty) order = o;
    }
    final providers = <String, PackGreenPlayProviderPrefs>{};
    final provRaw = m['providers'];
    if (provRaw is Map) {
      for (final e in provRaw.entries) {
        final id = e.key.toString().trim();
        if (id.isEmpty) continue;
        providers[id] = PackGreenPlayProviderPrefs.fromJson(e.value);
      }
    }
    return PackGreenPlayConfig(
      techAllowlist: allow,
      techPreferred: preferred,
      techOrder: order,
      providers: providers,
    );
  }

  /// Manifest default when the plugin declares `settings.greenPlay`.
  static PackGreenPlayConfig? fromPlugin(EnginePlugin plugin) {
    final settings = plugin.settings;
    if (settings == null) return null;
    final raw = settings['greenPlay'] ?? settings['green_play'];
    if (raw == null) return null;
    return fromJson(raw);
  }

  /// True when this hub plugin declares a greenPlay block (Settings UI gate).
  static bool isDeclared(EnginePlugin plugin) => fromPlugin(plugin) != null;

  /// Resolve effective config for a hub [pluginId].
  ///
  /// Pack declares → store overlay or manifest default.
  /// Undeclared → [hostFallback] (ignore stray store).
  static Future<PackGreenPlayConfig> resolve(String? pluginId) async {
    final id = pluginId?.trim() ?? '';
    if (id.isEmpty) return hostFallback;

    final packs = await EngineService.instance.listPacks();
    EnginePlugin? plugin;
    for (final p in activePluginsFromPacks(packs)) {
      if (p.id == id) {
        plugin = p;
        break;
      }
    }
    final manifest = plugin == null ? null : fromPlugin(plugin);
    if (manifest == null) return hostFallback;

    final stored = await PackSettingsStore.getString(
      id,
      fieldId,
      defaultValue: '',
    );
    if (stored.trim().isEmpty) return manifest;
    try {
      final decoded = jsonDecode(stored);
      return fromJson(decoded) ?? manifest;
    } catch (_) {
      return manifest;
    }
  }

  static Future<void> save(String pluginId, PackGreenPlayConfig config) async {
    final id = pluginId.trim();
    if (id.isEmpty) return;
    await PackSettingsStore.setString(
      id,
      fieldId,
      jsonEncode(config.toJson()),
      reloadHub: false,
    );
  }

  /// Technologies to race after play-source gates (preferred → order → rest).
  Future<List<String>> effectiveTechIds() async {
    final gated = <String>[];
    for (final tech in _orderedTechs()) {
      if (await _techEnabled(tech)) gated.add(tech);
    }
    return gated;
  }

  List<String> _orderedTechs() {
    final allow = techAllowlist.isEmpty
        ? PackGreenPlayTechs.all
        : [
            for (final t in techAllowlist)
              if (PackGreenPlayTechs.all.contains(t)) t,
          ];
    if (allow.isEmpty) return const [PackGreenPlayTechs.engine];

    final ordered = <String>[];
    for (final t in techOrder) {
      if (allow.contains(t) && !ordered.contains(t)) ordered.add(t);
    }
    for (final t in allow) {
      if (!ordered.contains(t)) ordered.add(t);
    }

    final preferred = <String>[
      for (final t in techPreferred)
        if (ordered.contains(t)) t,
    ];
    return [
      ...preferred,
      ...ordered.where((t) => !preferred.contains(t)),
    ];
  }

  /// Order [available] provider ids with this tech's allowlist / preferred / order.
  List<String> orderProviderIds({
    required String tech,
    required Iterable<String> available,
  }) {
    final prefs = providerPrefs(tech);
    final avail = [
      for (final id in available)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final pool = prefs.allowlist.isEmpty
        ? avail
        : [
            for (final id in avail)
              if (prefs.allowlist.contains(id)) id,
          ];
    if (pool.isEmpty) return const [];

    final ordered = <String>[];
    for (final id in prefs.order) {
      if (pool.contains(id) && !ordered.contains(id)) ordered.add(id);
    }
    for (final id in pool) {
      if (!ordered.contains(id)) ordered.add(id);
    }

    final preferred = <String>[
      for (final id in prefs.preferred)
        if (ordered.contains(id)) id,
    ];
    return [
      ...preferred,
      ...ordered.where((id) => !preferred.contains(id)),
    ];
  }

  /// First preferred provider for [tech] that is in [ordered], if any.
  String? firstPreferredIn(String tech, List<String> ordered) {
    if (ordered.isEmpty) return null;
    final prefs = providerPrefs(tech);
    for (final id in prefs.preferred) {
      if (ordered.contains(id)) return id;
    }
    return null;
  }

  static Future<bool> _techEnabled(String tech) async {
    switch (tech) {
      case PackGreenPlayTechs.engine:
        return PlaySourceEffective.engine();
      case PackGreenPlayTechs.stremio:
        return PlaySourceEffective.stremio();
      case PackGreenPlayTechs.nuvio:
        return PlaySourceEffective.nuvio();
      case PackGreenPlayTechs.torrent:
        return PlaySourceEffective.torrent();
      default:
        return false;
    }
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}
