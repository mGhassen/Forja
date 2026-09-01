/// Title/scene filter for torrent search — skips IMDb-keyed providers (Torrentio).
abstract final class TorrentSearchFilter {
  TorrentSearchFilter._();

  /// Providers that query by IMDb id; release-name title filter drops valid rows.
  static const imdbKeyedProviderIds = {'torrentio'};

  static bool isImdbKeyedSearchRow(Map<String, dynamic> row) {
    final pid =
        row['_providerId']?.toString() ?? row['providerId']?.toString() ?? '';
    return imdbKeyedProviderIds.contains(pid);
  }

  static ({
    List<Map<String, dynamic>> passThrough,
    List<Map<String, dynamic>> titleFilter,
  }) partitionSearchRows(List<Map<String, dynamic>> rows) {
    final passThrough = <Map<String, dynamic>>[];
    final titleFilter = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (isImdbKeyedSearchRow(row)) {
        passThrough.add(row);
      } else {
        titleFilter.add(row);
      }
    }
    return (passThrough: passThrough, titleFilter: titleFilter);
  }
}
