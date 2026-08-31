import 'package:forja/shared/catalog/protocol.dart';

/// Opaque catalog play state passed through player + engine auto-play.
class CatalogPlaySession {
  const CatalogPlaySession({
    this.pluginId,
    this.catalogMeta,
    this.catalogOpen,
    this.malId,
    this.episodeVideoIdByNumber = const {},
    this.audioCategory,
  });

  final String? pluginId;
  final CatalogMetaItem? catalogMeta;
  final CatalogOpen? catalogOpen;
  final int? malId;
  final Map<int, String> episodeVideoIdByNumber;
  final String? audioCategory;

  CatalogOpen? get effectiveOpen => catalogOpen ?? catalogMeta?.open;

  bool get hasCatalogContext => effectiveOpen != null || catalogMeta != null;

  String? episodeVideoIdFor(int episode) {
    final v = episodeVideoIdByNumber[episode]?.trim();
    return v != null && v.isNotEmpty ? v : null;
  }

  /// Hub episodic lists — flat episode numbers when meta carries videos.
  bool get isHubFlatList {
    final videos = catalogMeta?.videos;
    if (videos != null && videos.isNotEmpty) return true;
    return catalogMeta != null && effectiveOpen != null;
  }
}

/// Back-compat alias while player routes migrate imports.
typedef EnginePlaySession = CatalogPlaySession;
