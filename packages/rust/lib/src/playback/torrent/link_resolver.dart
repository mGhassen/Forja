import 'dart:convert';

import 'package:rust/rust.dart';

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

  ResolvedLink.magnet(this.link) : isMagnet = true, torrentBytes = null;

  ResolvedLink.torrentFile(this.torrentBytes) : isMagnet = false, link = '';
}

/// Resolves download links from Jackett/Prowlarr to magnet links or .torrent files
class LinkResolver {
  Future<ResolvedLink> resolve(String url) async {
    try {
      final decoded = await indexerRequest({
        'action': 'resolve_link',
        'url': url,
      });
      final isMagnet = decoded['is_magnet'] as bool? ?? false;
      if (isMagnet) {
        return ResolvedLink.magnet(decoded['link'] as String? ?? '');
      }
      final b64 = decoded['torrent_base64'] as String?;
      if (b64 == null || b64.isEmpty) {
        throw TorrentLinkResolutionException('Received empty torrent data');
      }
      return ResolvedLink.torrentFile(base64Decode(b64));
    } on Exception catch (e) {
      throw TorrentLinkResolutionException(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void dispose() {}
}
