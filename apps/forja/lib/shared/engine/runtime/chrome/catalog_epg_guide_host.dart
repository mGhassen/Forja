import 'package:flutter/material.dart';
import 'package:forja/shared/engine/portals/guide/guide_epg_cache.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';

/// Lazy portal EPG table loader for catalog guide paint.
class CatalogEpgGuideHost extends StatefulWidget {
  const CatalogEpgGuideHost({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context, {
    required Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)
        loadEpgProgrammes,
  }) builder;

  @override
  State<CatalogEpgGuideHost> createState() => _CatalogEpgGuideHostState();
}

class _CatalogEpgGuideHostState extends State<CatalogEpgGuideHost> {
  final Map<String, GuideEpgCache> _caches = {};
  Future<List<VerifiedPortal>>? _portalsFuture;

  Future<List<VerifiedPortal>> _portals() {
    return _portalsFuture ??= PortalStore.load();
  }

  Future<GuideEpgCache?> _cacheFor(String portalKey) async {
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    final existing = _caches[key];
    if (existing != null) return existing;
    final portals = await _portals();
    VerifiedPortal? match;
    for (final p in portals) {
      if (p.key == key) {
        match = p;
        break;
      }
    }
    if (match == null || !match.platform.supportsEpg) return null;
    final cache = GuideEpgCache(match);
    _caches[key] = cache;
    return cache;
  }

  Future<List<GuideEpgProgramme>> _load(Map<String, dynamic> item) async {
    final open = item['open'];
    final openMap = open is Map ? Map<String, dynamic>.from(open) : const {};
    final portalKey = (item['portalKey'] ?? openMap['portalKey'] ?? '')
        .toString()
        .trim();
    final streamId =
        (item['streamId'] ?? openMap['streamId'] ?? '').toString().trim();
    final epgId = (item['epgChannelId'] ?? openMap['epgChannelId'] ?? '')
        .toString()
        .trim();
    if (streamId.isEmpty && epgId.isEmpty) return const [];
    final cache = await _cacheFor(portalKey);
    if (cache == null) return const [];
    return cache.loadGuideProgrammes(
      streamId: streamId,
      epgChannelId: epgId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      loadEpgProgrammes: _load,
    );
  }
}
