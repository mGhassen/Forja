import 'package:rust/rust.dart';

/// Bridges legacy [StreamSource] lists with [PlayableSource] metadata in the player.
abstract final class PlayableSourceBridge {
  static bool isArabicEmbedCatalogRow(Map<String, dynamic> stream) =>
      stream['type']?.toString() == 'arabic_embed';

  static Future<List<PlayableSource>> rankWidgetSources({
    required List<StreamSource>? sources,
    required String? providerId,
    int providerRank = 0,
  }) async {
    if (sources == null || sources.isEmpty) return [];
    return PlaybackSelection.rankLegacySources(
      sources: sources,
      providerId: providerId ?? '',
      providerRank: providerRank,
    );
  }

  static bool isArabicEmbed(
    List<PlayableSource>? playable,
    int index,
    StreamSource source,
  ) {
    if (playable != null && index < playable.length) {
      return playable[index].isArabicEmbed;
    }
    return source.type == 'arabic_embed';
  }

  static bool requiresProxy(
    List<PlayableSource>? playable,
    int index,
    String? providerId, {
    String? streamUrl,
  }) {
    if (playable != null &&
        index < playable.length &&
        playable[index].requiresProxy) {
      return true;
    }
    final url = streamUrl ??
        (playable != null && index < playable.length
            ? playable[index].url
            : null);
    // Seek proxy only for raw *111477* CDN hosts (a./p.). Addon workers.dev
    // URLs play direct — PlayTorrio path. Do not key off provider id alone.
    return is111477UpstreamUrl(url ?? '');
  }
}
