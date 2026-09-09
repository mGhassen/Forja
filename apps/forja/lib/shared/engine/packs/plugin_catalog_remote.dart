import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/official_forjahq_packs.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/api/sync_service.dart';

/// Published pack + product-bundle catalog from Supabase (RFC-100).
///
/// Pack files stay on GitHub (`manifest_url`). This only loads catalog metadata
/// and install URLs for official picker / onboarding bundles.
class PluginCatalogRemote {
  PluginCatalogRemote._();

  /// Fetch published packs. Returns empty on failure / unconfigured.
  static Future<List<OfficialForjaHqPack>> fetchPublishedPacks() async {
    try {
      await ForjaSupabase.ensureInitialized();
      final client = ForjaSupabase.clientOrNull;
      if (client == null) return const [];
      final rows = await SyncService.retryAfterJwtIatSkew(
        () => client
            .from('plugin_packs')
            .select(
              'id, name, description, kind, tags, recommended, official, '
              'manifest_url, sort_order',
            )
            .eq('published', true)
            .order('sort_order', ascending: true)
            .order('id', ascending: true),
      );
      if (rows.isEmpty) return const [];
      final out = <OfficialForjaHqPack>[];
      for (final raw in rows) {
        final id = (raw['id'] as String?)?.trim() ?? '';
        final url = (raw['manifest_url'] as String?)?.trim() ?? '';
        final name = (raw['name'] as String?)?.trim() ?? '';
        if (id.isEmpty || url.isEmpty || name.isEmpty) continue;
        final tagsRaw = raw['tags'];
        final tags = <String>[
          if (tagsRaw is List)
            for (final t in tagsRaw)
              if (t is String && t.trim().isNotEmpty) t.trim(),
        ];
        out.add(
          OfficialForjaHqPack(
            id: id,
            name: name,
            manifestUrl: url,
            description: (raw['description'] as String?)?.trim(),
            kind: (raw['kind'] as String?)?.trim(),
            tags: tags,
            recommended: raw['recommended'] == true,
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('[PluginCatalog] packs fetch failed: $e');
      return const [];
    }
  }

  /// Fetch published product bundles with ordered pack ids.
  static Future<List<PluginProductBundle>> fetchPublishedBundles() async {
    try {
      await ForjaSupabase.ensureInitialized();
      final client = ForjaSupabase.clientOrNull;
      if (client == null) return const [];
      final bundles = await SyncService.retryAfterJwtIatSkew(
        () => client
            .from('plugin_bundles')
            .select('id, name, description, recommended, sort_order')
            .eq('published', true)
            .order('sort_order', ascending: true)
            .order('id', ascending: true),
      );
      if (bundles.isEmpty) return const [];
      final items = await SyncService.retryAfterJwtIatSkew(
        () => client
            .from('plugin_bundle_items')
            .select('bundle_id, pack_id, sort_order')
            .order('sort_order', ascending: true),
      );
      final byBundle = <String, List<({String packId, int sort})>>{};
      for (final raw in items) {
        final bid = (raw['bundle_id'] as String?)?.trim() ?? '';
        final pid = (raw['pack_id'] as String?)?.trim() ?? '';
        if (bid.isEmpty || pid.isEmpty) continue;
        final sort = (raw['sort_order'] as num?)?.toInt() ?? 0;
        (byBundle[bid] ??= []).add((packId: pid, sort: sort));
      }
      final out = <PluginProductBundle>[];
      for (final raw in bundles) {
        final id = (raw['id'] as String?)?.trim() ?? '';
        final name = (raw['name'] as String?)?.trim() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final packIds = [...(byBundle[id] ?? [])]
          ..sort((a, b) => a.sort.compareTo(b.sort));
        out.add(
          PluginProductBundle(
            id: id,
            name: name,
            description: (raw['description'] as String?)?.trim() ?? '',
            recommended: raw['recommended'] == true,
            packIds: [for (final p in packIds) p.packId],
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('[PluginCatalog] bundles fetch failed: $e');
      return const [];
    }
  }
}

@immutable
class PluginProductBundle {
  const PluginProductBundle({
    required this.id,
    required this.name,
    required this.packIds,
    this.description = '',
    this.recommended = false,
  });

  final String id;
  final String name;
  final String description;
  final bool recommended;
  final List<String> packIds;
}
