/// Runtime catalog for installed torrent indexer plugins.
class TorrentSearchProviderMeta {
  const TorrentSearchProviderMeta({
    required this.id,
    required this.label,
    required this.resultSource,
  });

  final String id;
  final String label;
  final String resultSource;
}

abstract final class TorrentSearchCatalog {
  static List<TorrentSearchProviderMeta> _installed = [];

  static List<TorrentSearchProviderMeta> get providers =>
      List<TorrentSearchProviderMeta>.unmodifiable(_installed);

  static bool get hasInstalled => _installed.isNotEmpty;

  static List<String> get allIds => [for (final p in _installed) p.id];

  static Map<String, String> get labels => {
        for (final p in _installed) p.id: p.label,
      };

  static Map<String, String> get resultSources => {
        for (final p in _installed) p.id: p.resultSource,
      };

  static void update(List<TorrentSearchProviderMeta> next) {
    _installed = List<TorrentSearchProviderMeta>.from(next);
  }

  static void clear() {
    _installed = [];
  }
}
