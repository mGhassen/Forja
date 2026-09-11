import 'package:forja_foundation/protocol/protocol.dart';

/// Opaque kit play state passed through player + engine auto-play.
class PlaySession {
  const PlaySession({
    this.pluginId,
    this.metaItem,
    this.metaOpen,
    this.malId,
    this.episodeVideoIdByNumber = const {},
    this.audioCategory,
  });

  final String? pluginId;
  final MetaItem? metaItem;
  final MetaOpen? metaOpen;
  final int? malId;
  final Map<int, String> episodeVideoIdByNumber;
  final String? audioCategory;

  MetaOpen? get effectiveOpen => metaOpen ?? metaItem?.open;

  /// Back-compat aliases while call sites migrate.
  MetaItem? get meta => metaItem;
  MetaOpen? get open => metaOpen;

  bool get hasMetaContext => effectiveOpen != null || metaItem != null;

  String? episodeVideoIdFor(int episode) {
    final v = episodeVideoIdByNumber[episode]?.trim();
    return v != null && v.isNotEmpty ? v : null;
  }

  /// Kit episodic lists — flat episode numbers when meta carries videos.
  bool get isHubFlatList {
    final videos = metaItem?.videos;
    if (videos != null && videos.isNotEmpty) return true;
    return metaItem != null && effectiveOpen != null;
  }
}

/// Back-compat alias while player routes migrate imports.
typedef EnginePlaySession = PlaySession;
