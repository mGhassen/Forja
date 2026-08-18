import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Bridges legacy [StreamSource] lists with [PlayableSource] metadata in the player.
abstract final class PlayableSourceBridge {
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
    if (playable != null && index < playable.length) {
      return playable[index].requiresProxy;
    }
    if (providerId == 'service111477') return true;
    if (providerId == 'engine:service111477') return true;
    return false;
  }
}
