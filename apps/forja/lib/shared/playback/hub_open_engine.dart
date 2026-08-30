import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/categories.dart';

/// Engine resolve ids derived from pack [CatalogOpen] — only at playback boundary.
class HubEngineResolveParams {
  const HubEngineResolveParams({
    this.anilistId,
    this.malId,
    this.kisskhId,
    this.kisskhEpisodeId,
    this.arabicVideoId,
  });

  final int? anilistId;
  final int? malId;
  final int? kisskhId;
  final int? kisskhEpisodeId;
  final String? arabicVideoId;

  bool get hasAnimeIds => (anilistId ?? 0) > 0 || (malId ?? 0) > 0;
}

String engineCategoryForOpen(CatalogOpen? open, {String? metaType}) {
  final surface = (open?.surface ?? metaType ?? '').trim();
  switch (surface) {
    case 'anime':
      return EngineCategories.anime;
    case 'drama':
      return EngineCategories.drama;
    case 'arabic':
      return EngineCategories.arabic;
    default:
      return EngineCategories.movie;
  }
}

HubEngineResolveParams hubEngineResolveParams({
  required CatalogOpen? catalogOpen,
  required String category,
  int? episode,
  int? malId,
  Map<int, String> episodeVideoIdByNumber = const {},
}) {
  final open = catalogOpen;
  final ep = episode ?? 1;
  final epVid = episodeVideoIdByNumber[ep]?.trim();

  switch (category) {
    case EngineCategories.anime:
      return HubEngineResolveParams(
        anilistId: open?.idInt,
        malId: malId ?? int.tryParse(open?.extraString('mal') ?? ''),
      );
    case EngineCategories.drama:
      return HubEngineResolveParams(
        kisskhId: open?.idInt,
        kisskhEpisodeId: int.tryParse(epVid ?? ''),
      );
    case EngineCategories.arabic:
      final vid = (epVid?.isNotEmpty == true ? epVid : open?.id)?.trim();
      return HubEngineResolveParams(
        arabicVideoId: vid != null && vid.isNotEmpty ? vid : null,
      );
    default:
      return const HubEngineResolveParams();
  }
}

String? providerIdFromEpisodeVideoId(String videoId) {
  final i = videoId.indexOf(':');
  if (i <= 0) return null;
  final id = videoId.substring(0, i).trim();
  return id.isEmpty ? null : id;
}
