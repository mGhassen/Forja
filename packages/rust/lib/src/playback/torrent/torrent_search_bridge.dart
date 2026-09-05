typedef TorrentSearchHandler = Future<List<Map<String, dynamic>>> Function(
  String query, {
  String? imdbId,
  int? season,
  int? episode,
  Map<String, String>? ids,
  List<String>? enabledProviders,
});

typedef TorrentSearchProgressiveHandler =
    Future<List<Map<String, dynamic>>> Function(
  String query, {
  String? imdbId,
  int? season,
  int? episode,
  Map<String, String>? ids,
  List<String>? enabledProviders,
  void Function(List<Map<String, dynamic>> soFar)? onPartial,
  void Function(String providerId)? onProviderDone,
  bool Function()? isCancelled,
});

/// Host registers JS torrent search here — [Engine.searchTorrents] delegates.
abstract final class TorrentSearchBridge {
  static TorrentSearchHandler? handler;
  static TorrentSearchProgressiveHandler? progressiveHandler;

  static void register({
    required TorrentSearchHandler search,
    required TorrentSearchProgressiveHandler progressive,
  }) {
    handler = search;
    progressiveHandler = progressive;
  }
}
