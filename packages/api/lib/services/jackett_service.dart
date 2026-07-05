import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:core/models/torrent_result.dart';

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
}

/// Service for searching torrents via Jackett
class JackettService {
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 20);

  /// Torznab categories for movies and TV shows
  static const String _categories = '2000,5000,5030,5040,5045,2010,2020,2030,2040,2045';

  /// Search for torrents using Jackett
  Future<List<TorrentResult>> search(
    String baseUrl,
    String apiKey,
    String query,
  ) async {
    try {
      final normalizedUrl = _normalizeBaseUrl(baseUrl);
      final uri = Uri.parse('$normalizedUrl/api/v2.0/indexers/all/results/torznab/api')
          .replace(queryParameters: {
        'apikey': apiKey,
        't': 'search',
        'q': query,
        'cat': _categories,
      });

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 401 || response.body.contains('Unauthorized')) {
        throw Exception('❌ Invalid API Key. Check your Jackett API key in Settings.');
      }

      if (response.statusCode == 403) {
        throw Exception('❌ Access denied. Check your Jackett API key and server configuration.');
      }

      if (response.statusCode == 500) {
        throw Exception('❌ Jackett returned a server error. Check the Jackett logs.');
      }

      if (response.statusCode != 200) {
        throw Exception('❌ Jackett returned HTTP ${response.statusCode}');
      }

      return _parseTorznabXml(response.body);
    } on http.ClientException {
      throw Exception('⚠️ Cannot connect to Jackett. Is it running? Check your Base URL in Settings.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('⚠️ Jackett timed out. It may be overloaded or the URL is wrong.');
      }
      if (e is Exception) rethrow;
      throw Exception('⚠️ Unexpected error: $e');
    }
  }

  /// Test connection to Jackett
  Future<ConnectionTestResult> testConnection(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      final normalizedUrl = _normalizeBaseUrl(baseUrl);
      final uri = Uri.parse('$normalizedUrl/api/v2.0/indexers/all/results/torznab/api')
          .replace(queryParameters: {
        'apikey': apiKey,
        't': 'indexers',
        'configured': 'true',
      });

      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 || response.body.contains('Unauthorized')) {
        return ConnectionTestResult(
          success: false,
          message: '❌ Wrong API key',
        );
      }

      if (response.statusCode == 200) {
        try {
          final document = XmlDocument.parse(response.body);
          final indexers = document.findAllElements('indexer').length;
          return ConnectionTestResult(
            success: true,
            message: '✅ Connected — $indexers indexers configured',
            indexerCount: indexers,
          );
        } catch (e) {
          return ConnectionTestResult(
            success: true,
            message: '✅ Connected',
          );
        }
      }

      return ConnectionTestResult(
        success: false,
        message: '❌ HTTP ${response.statusCode}',
      );
    } on http.ClientException {
      return ConnectionTestResult(
        success: false,
        message: '❌ Cannot connect to Jackett',
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return ConnectionTestResult(
          success: false,
          message: '❌ Connection timed out',
        );
      }
      return ConnectionTestResult(
        success: false,
        message: '❌ Error: $e',
      );
    }
  }

  /// Parse Torznab XML response
  List<TorrentResult> _parseTorznabXml(String xmlBody) {
    try {
      final document = XmlDocument.parse(xmlBody);
      final items = document.findAllElements('item');
      final results = <TorrentResult>[];

      for (final item in items) {
        try {
          final title = _getElementText(item, 'title') ?? 'Unknown';
          final sizeStr = _getElementText(item, 'size') ??
              item.findElements('enclosure').firstOrNull?.getAttribute('length') ??
              '0';
          final size = int.tryParse(sizeStr) ?? 0;

          // Extract torznab attributes (namespace: '*' required for <torznab:attr> elements)
          final seeders = _getTorznabAttr(item, 'seeders') ?? '0';
          final magnetUrl = _getTorznabAttr(item, 'magneturl');
          final infoHash = _getTorznabAttr(item, 'infohash');

          // Get indexer name
          final indexer = item.findElements('jackettindexer').firstOrNull?.innerText ??
                          'Jackett';

          // Determine download link priority
          String? downloadLink;

          // Priority 1: magneturl attribute
          if (magnetUrl != null && magnetUrl.isNotEmpty && magnetUrl.startsWith('magnet:')) {
            downloadLink = magnetUrl;
          }

          // Priority 2: enclosure with magnet
          if (downloadLink == null) {
            final enclosure = item.findElements('enclosure').firstOrNull;
            final enclosureUrl = enclosure?.getAttribute('url');
            if (enclosureUrl != null && enclosureUrl.startsWith('magnet:')) {
              downloadLink = enclosureUrl;
            }
          }

          // Priority 3: link element (Jackett proxy URL)
          downloadLink ??= _getElementText(item, 'link');

          // Priority 4: construct from infohash
          if ((downloadLink == null || downloadLink.isEmpty) &&
              infoHash != null && infoHash.isNotEmpty) {
            downloadLink = 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}';
          }

          if (downloadLink != null && downloadLink.isNotEmpty) {
            results.add(TorrentResult(
              name: title,
              magnet: downloadLink,
              seeders: seeders,
              size: _formatSize(size),
              source: indexer,
            ));
          }
        } catch (e) {
          // Skip malformed items
          continue;
        }
      }

      return results;
    } catch (e) {
      throw Exception('⚠️ Unexpected response from Jackett. The server may be misconfigured.');
    }
  }

  /// Get text content of an XML element
  String? _getElementText(XmlElement parent, String name) {
    try {
      return parent.findElements(name).firstOrNull?.innerText;
    } catch (_) {
      return null;
    }
  }

  /// Get torznab:attr value by name.
  /// Must use namespace: '*' because Jackett returns torznab:attr elements
  /// which are invisible to findAllElements without a namespace qualifier.
  String? _getTorznabAttr(XmlElement item, String attrName) {
    try {
      for (final el in item.findAllElements('attr', namespace: '*')) {
        if (el.getAttribute('name') == attrName) {
          return el.getAttribute('value');
        }
      }
    } catch (_) {}
    return null;
  }

  /// Format size in bytes to human-readable string
  String _formatSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Normalize base URL by removing trailing slashes
  String _normalizeBaseUrl(String url) {
    return url.trimRight().replaceAll(RegExp(r'/+$'), '');
  }

  void dispose() {
    _client.close();
  }
} 