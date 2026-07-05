import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exception thrown when link resolution fails
class TorrentLinkResolutionException implements Exception {
  final String message;
  final int? statusCode;

  TorrentLinkResolutionException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Represents a resolved torrent link
class ResolvedLink {
  final String link;
  final bool isMagnet;
  final List<int>? torrentBytes;

  ResolvedLink.magnet(this.link)
      : isMagnet = true,
        torrentBytes = null;

  ResolvedLink.torrentFile(this.torrentBytes)
      : isMagnet = false,
        link = '';
}

/// Resolves download links from Jackett/Prowlarr to magnet links or .torrent files
class LinkResolver {
  final http.Client _client = http.Client();
  static const int _maxRedirects = 10;
  static const Duration _timeout = Duration(seconds: 15);

  /// Resolves a URL to either a magnet link or torrent file bytes
  /// 
  /// Handles:
  /// - Direct magnet links (Type 1)
  /// - Jackett proxy URLs (Type 2)
  /// - Prowlarr proxy URLs (Type 3)
  /// - Direct .torrent file URLs (Type 4)
  Future<ResolvedLink> resolve(String url) async {
    return await _resolveWithRedirects(url, 0);
  }

  Future<ResolvedLink> _resolveWithRedirects(String url, int depth) async {
    // Type 1: Already a magnet link
    if (url.startsWith('magnet:')) {
      return ResolvedLink.magnet(url);
    }

    // Prevent infinite redirect loops
    if (depth >= _maxRedirects) {
      throw TorrentLinkResolutionException(
        'Could not resolve download link — too many redirects.'
      );
    }

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = false;

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final statusCode = streamedResponse.statusCode;

      // Handle redirects (301, 302, 307, 308)
      if (statusCode >= 301 && statusCode <= 308) {
        final location = streamedResponse.headers['location'];
        
        if (location == null || location.isEmpty) {
          throw TorrentLinkResolutionException(
            'Redirect response missing Location header',
            statusCode: statusCode
          );
        }

        // Type 2/3: Redirect to magnet link
        if (location.startsWith('magnet:')) {
          return ResolvedLink.magnet(location);
        }

        // Resolve relative URLs
        final Uri baseUri = Uri.parse(url);
        final Uri redirectUri = Uri.parse(location);
        final String nextUrl = redirectUri.isAbsolute
            ? location
            : baseUri.resolve(location).toString();

        // Recurse to follow the redirect
        return await _resolveWithRedirects(nextUrl, depth + 1);
      }

      // Handle successful response (200)
      if (statusCode == 200) {
        final contentType = streamedResponse.headers['content-type'] ?? '';
        final bytes = await streamedResponse.stream.toBytes();

        // Type 4: Torrent file
        if (contentType.contains('application/x-bittorrent') ||
            contentType.contains('application/octet-stream')) {
          return ResolvedLink.torrentFile(bytes);
        }

        // Check if body is a magnet link (some servers return text/plain)
        if (contentType.contains('text/plain')) {
          final body = utf8.decode(bytes).trim();
          if (body.startsWith('magnet:')) {
            return ResolvedLink.magnet(body);
          }
        }

        // Assume it's a torrent file if we got binary data
        if (bytes.isNotEmpty) {
          return ResolvedLink.torrentFile(bytes);
        }

        throw TorrentLinkResolutionException(
          'Received empty response from server'
        );
      }

      // Handle errors
      if (statusCode >= 400 && statusCode < 500) {
        throw TorrentLinkResolutionException(
          'Download link returned an error (HTTP $statusCode). The torrent may no longer be available.',
          statusCode: statusCode
        );
      }

      if (statusCode >= 500) {
        throw TorrentLinkResolutionException(
          'Server error (HTTP $statusCode)',
          statusCode: statusCode
        );
      }

      throw TorrentLinkResolutionException(
        'Unexpected HTTP status: $statusCode',
        statusCode: statusCode
      );

    } on http.ClientException catch (e) {
      throw TorrentLinkResolutionException(
        'Cannot reach indexer — is it running? ${e.message}'
      );
    } catch (e) {
      if (e is TorrentLinkResolutionException) rethrow;
      
      if (e.toString().contains('TimeoutException')) {
        throw TorrentLinkResolutionException(
          'Download link timed out. The indexer may be down.'
        );
      }
      
      throw TorrentLinkResolutionException(
        'Failed to download .torrent file. Check your connection.'
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
