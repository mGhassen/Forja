/// Which Forja surfaces a Stremio addon is wired into.
class StremioAddonFeatures {
  StremioAddonFeatures._();

  static const vod = 'vod';
  static const live = 'live';

  static const all = [vod, live];

  static const _vodTypes = {
    'movie',
    'series',
    'channel',
    'tv',
    'anime',
    'other',
  };

  /// Live / sport catalog (Search must skip these; Live Matches may use them).
  static bool catalogLooksLive(Map catalog) {
    final type = catalog['type']?.toString().trim().toLowerCase() ?? '';
    final id = catalog['id']?.toString().trim().toLowerCase() ?? '';
    final name = catalog['name']?.toString().trim().toLowerCase() ?? '';
    if (type == 'sport') return true;
    if (id.contains('live') || name.contains('live')) return true;
    if (id.contains('sport') || name.contains('sport')) return true;
    return false;
  }

  /// Infer targets from a Stremio manifest (`types` + catalog types).
  static List<String> inferFromManifest(Map? manifest) {
    if (manifest == null) return const [vod];
    final types = <String>{};
    final rawTypes = manifest['types'];
    if (rawTypes is List) {
      for (final t in rawTypes) {
        final s = t?.toString().trim().toLowerCase() ?? '';
        if (s.isNotEmpty) types.add(s);
      }
    }
    final catalogs = manifest['catalogs'];
    var hasLiveCatalog = false;
    var hasNonLiveVodCatalog = false;
    if (catalogs is List) {
      for (final c in catalogs) {
        if (c is! Map) continue;
        final t = c['type']?.toString().trim().toLowerCase() ?? '';
        if (t.isNotEmpty) types.add(t);
        if (catalogLooksLive(c)) {
          hasLiveCatalog = true;
        } else if (_vodTypes.contains(t) || t == 'tv') {
          hasNonLiveVodCatalog = true;
        }
      }
    }

    final hasSport = types.contains('sport') || hasLiveCatalog;
    // `tv` alone from live-named catalogs must not force VOD (flixnest, etc.).
    final hasVod = hasNonLiveVodCatalog ||
        types.any((t) => t != 'tv' && _vodTypes.contains(t));
    if (hasSport && hasVod) return [vod, live];
    if (hasSport) return const [live];
    return const [vod];
  }

  /// Normalize persisted / synced feature lists; infer when missing.
  static List<String> normalize(
    dynamic raw, {
    Map? manifest,
  }) {
    final out = <String>[];
    if (raw is List) {
      for (final v in raw) {
        final s = v?.toString().trim().toLowerCase() ?? '';
        if (s == vod || s == live) {
          if (!out.contains(s)) out.add(s);
        }
      }
    }
    if (out.isEmpty) return inferFromManifest(manifest);
    return out;
  }

  static List<String> read(Map<String, dynamic> addon) {
    final manifest = addon['manifest'];
    return normalize(
      addon['features'],
      manifest: manifest is Map ? Map<String, dynamic>.from(manifest) : null,
    );
  }

  static bool targetsVod(Map<String, dynamic> addon) =>
      read(addon).contains(vod);

  static bool targetsLive(Map<String, dynamic> addon) =>
      read(addon).contains(live);

  /// Master on/off — missing / null means enabled (legacy installs).
  static bool isEnabled(Map addon) => addon['enabled'] != false;

  /// Persist as bool; default on.
  static bool normalizeEnabled(dynamic raw) => raw != false;

  /// Toggle [feature]; keeps at least one target.
  static List<String> toggle(List<String> current, String feature) {
    final next = List<String>.from(current);
    if (next.contains(feature)) {
      if (next.length <= 1) return next;
      next.remove(feature);
    } else {
      next.add(feature);
    }
    next.sort((a, b) {
      const order = [vod, live];
      return order.indexOf(a).compareTo(order.indexOf(b));
    });
    return next;
  }
}
