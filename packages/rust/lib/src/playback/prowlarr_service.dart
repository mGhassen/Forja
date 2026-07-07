import 'package:rust/rust.dart';

/// A tag defined in Prowlarr
class ProwlarrTag {
  final int id;
  final String label;

  const ProwlarrTag({required this.id, required this.label});

  factory ProwlarrTag.fromJson(Map<String, dynamic> json) => ProwlarrTag(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
      );
}

/// Result of a Prowlarr connection test
class ConnectionTestResult {
  final bool success;
  final String message;
  final String? version;

  ConnectionTestResult({
    required this.success,
    required this.message,
    this.version,
  });

  factory ConnectionTestResult.fromJson(Map<String, dynamic> json) =>
      ConnectionTestResult(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        version: json['version'] as String?,
      );
}

/// Service for searching torrents via Prowlarr
class ProwlarrService {
  Future<List<TorrentResult>> search(
    String baseUrl,
    String apiKey,
    String query, {
    List<int>? indexerIds,
  }) async {
    final decoded = await indexerRequest({
      'action': 'prowlarr_search',
      'base_url': baseUrl,
      'api_key': apiKey,
      'query': query,
      if (indexerIds != null) 'indexer_ids': indexerIds,
    });
    final results = decoded['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => TorrentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConnectionTestResult> testConnection(
    String baseUrl,
    String apiKey,
  ) async {
    final decoded = await indexerRequest({
      'action': 'prowlarr_test',
      'base_url': baseUrl,
      'api_key': apiKey,
    });
    return ConnectionTestResult.fromJson(decoded);
  }

  Future<List<ProwlarrTag>> fetchTags(String baseUrl, String apiKey) async {
    final decoded = await indexerRequest({
      'action': 'prowlarr_tags',
      'base_url': baseUrl,
      'api_key': apiKey,
    });
    final tags = decoded['tags'] as List<dynamic>? ?? [];
    return tags
        .map((e) => ProwlarrTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<int>> resolveTagIndexerIds(
    String baseUrl,
    String apiKey,
    List<int> tagIds,
  ) async {
    final decoded = await indexerRequest({
      'action': 'prowlarr_resolve_tags',
      'base_url': baseUrl,
      'api_key': apiKey,
      'tag_ids': tagIds,
    });
    final ids = decoded['indexer_ids'] as List<dynamic>? ?? [];
    return ids.map((e) => e as int).toList();
  }

  void dispose() {}
}
