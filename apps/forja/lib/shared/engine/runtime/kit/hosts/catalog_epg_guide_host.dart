import 'package:flutter/material.dart';
import 'package:forja/shared/engine/portals/guide/guide_epg_cache.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/portals_host.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';
import 'package:rust/rust.dart';

/// Lazy portal EPG table loader for catalog guide / channel-card NOW paint.
class CatalogEpgGuideHost extends StatefulWidget {
  const CatalogEpgGuideHost({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context, {
    required Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)
        loadEpgProgrammes,
    required Future<List<GuideEpgProgramme>> Function(Map<String, dynamic> item)
        loadShortEpgProgrammes,
  }) builder;

  @override
  State<CatalogEpgGuideHost> createState() => _CatalogEpgGuideHostState();
}

class _CatalogEpgGuideHostState extends State<CatalogEpgGuideHost> {
  final Map<String, GuideEpgCache> _caches = {};
  final Map<String, Future<List<GuideEpgProgramme>>> _shortFutures = {};
  final Map<String, Future<List<GuideEpgProgramme>>> _guideFutures = {};
  Future<List<VerifiedPortal>>? _portalsFuture;

  @override
  void initState() {
    super.initState();
    SettingsService.iptvEpgEnabledNotifier.addListener(_onEpgPrefChanged);
  }

  @override
  void dispose() {
    SettingsService.iptvEpgEnabledNotifier.removeListener(_onEpgPrefChanged);
    super.dispose();
  }

  void _onEpgPrefChanged() {
    _caches.clear();
    _shortFutures.clear();
    _guideFutures.clear();
    _portalsFuture = null;
    if (mounted) setState(() {});
  }

  bool get _epgEnabled => SettingsService.iptvEpgEnabledNotifier.value;

  /// Vault-first — pack Add/Import never write [PortalStore] alone.
  Future<List<VerifiedPortal>> _portals() {
    return _portalsFuture ??= PortalsHost.loadVaultVerifiedPortals();
  }

  String _itemCacheKey(Map<String, dynamic> item) {
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
    return '$portalKey|$streamId|$epgId';
  }

  Future<GuideEpgCache?> _cacheFor(String portalKey) async {
    if (!_epgEnabled) return null;
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    final existing = _caches[key];
    if (existing != null) return existing;
    final portals = await _portals();
    var match = PortalChannelGuideOpen.matchPortal(portals, key);
    // Single EPG portal — still paint when pack key drifted.
    if (match == null) {
      final epgCapable = [
        for (final p in portals)
          if (p.platform.supportsEpg) p,
      ];
      if (epgCapable.length == 1) match = epgCapable.first;
    }
    if (match == null || !match.platform.supportsEpg) return null;
    final cache = GuideEpgCache(match);
    _caches[key] = cache;
    _caches[match.key] = cache;
    _caches[PortalChannelGuideOpen.packPortalKey(match.portal)] = cache;
    return cache;
  }

  Future<List<GuideEpgProgramme>> _load(Map<String, dynamic> item) {
    if (!_epgEnabled) return Future.value(const []);
    final key = _itemCacheKey(item);
    if (key == '||') return Future.value(const []);
    return _guideFutures.putIfAbsent(key, () => _loadGuideUncached(item));
  }

  Future<List<GuideEpgProgramme>> _loadGuideUncached(
    Map<String, dynamic> item,
  ) async {
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

  Future<List<GuideEpgProgramme>> _loadShort(Map<String, dynamic> item) {
    if (!_epgEnabled) return Future.value(const []);
    final key = _itemCacheKey(item);
    if (key == '||') return Future.value(const []);
    return _shortFutures.putIfAbsent(key, () => _loadShortUncached(item));
  }

  Future<List<GuideEpgProgramme>> _loadShortUncached(
    Map<String, dynamic> item,
  ) async {
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
    final name = (item['name'] ?? openMap['name'] ?? '').toString();
    final icon = (item['poster'] ?? openMap['icon'] ?? '').toString();
    if (streamId.isEmpty && epgId.isEmpty) return const [];
    final cache = await _cacheFor(portalKey);
    if (cache == null) return const [];
    return cache.loadProgrammes(
      PortalStream(
        streamId: streamId,
        name: name,
        icon: icon,
        categoryId: (item['categoryId'] ?? openMap['categoryId'] ?? '')
            .toString(),
        containerExt: 'ts',
        kind: 'live',
        epgChannelId: epgId,
      ),
      limit: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      loadEpgProgrammes: _load,
      loadShortEpgProgrammes: _loadShort,
    );
  }
}
