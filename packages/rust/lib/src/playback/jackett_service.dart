import 'package:rust/rust.dart';

/// Result of a Jackett connection test
class ConnectionTestResult {
  final bool success;
  final String message;
  final int? indexerCount;

  ConnectionTestResult({
    required this.success,
    required this.message,
    this.indexerCount,
  });

  factory ConnectionTestResult.fromJson(Map<String, dynamic> json) =>
      ConnectionTestResult(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        indexerCount: json['indexer_count'] as int?,
      );
}

/// Service for searching torrents via Jackett
class JackettService {
  Future<List<TorrentResult>> search(
    String baseUrl,
    String apiKey,
    String query,
  ) async {
    final decoded = await indexerRequest({
      'action': 'jackett_search',
      'base_url': baseUrl,
      'api_key': apiKey,
      'query': query,
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
      'action': 'jackett_test',
      'base_url': baseUrl,
      'api_key': apiKey,
    });
    return ConnectionTestResult.fromJson(decoded);
  }

  void dispose() {}
}
