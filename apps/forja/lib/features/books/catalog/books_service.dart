import 'package:flutter/foundation.dart';

import 'package:rust/rust.dart';

class BookEditionDetails {
  final String editionId;
  final String md5;
  final String adsUrl;
  final String? size;
  final String? extension;
  final String? pages;

  const BookEditionDetails({
    required this.editionId,
    required this.md5,
    required this.adsUrl,
    this.size,
    this.extension,
    this.pages,
  });

  factory BookEditionDetails.fromJson(Map<String, dynamic> json) =>
      BookEditionDetails(
        editionId: (json['editionId'] ?? json['edition_id'] ?? '') as String,
        md5: (json['md5'] ?? '') as String,
        adsUrl: (json['adsUrl'] ?? json['ads_url'] ?? '') as String,
        size: json['size'] as String?,
        extension: json['extension'] as String?,
        pages: json['pages'] as String?,
      );
}

class BooksService {
  Future<List<BookResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final decoded = await booksCatalog({
        'action': 'search',
        'query': query,
      });
      return ((decoded['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BookResult.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e, st) {
      debugPrint('[LibGen] search error: $e\n$st');
      return [];
    }
  }

  Future<BookEditionDetails?> getEditionDetails(String editionId) async {
    try {
      final decoded = await booksCatalog({
        'action': 'edition',
        'edition_id': editionId,
      });
      final edition = decoded['edition'];
      if (edition is! Map) return null;
      return BookEditionDetails.fromJson(edition.cast<String, dynamic>());
    } catch (e) {
      debugPrint('[LibGen] edition details error: $e');
      return null;
    }
  }

  Future<String?> getDownloadUrl(String md5) async {
    try {
      final decoded = await booksCatalog({
        'action': 'download_url',
        'md5': md5,
      });
      final url = decoded['url'] as String?;
      return url?.isNotEmpty == true ? url : null;
    } catch (e) {
      debugPrint('[LibGen] download url error: $e');
      return null;
    }
  }

  Future<String?> resolveDownloadUrl(String editionId) async {
    try {
      final decoded = await booksCatalog({
        'action': 'resolve',
        'edition_id': editionId,
      });
      final url = decoded['downloadUrl'] as String? ?? decoded['download_url'] as String?;
      return url?.isNotEmpty == true ? url : null;
    } catch (e) {
      debugPrint('[LibGen] resolve download error: $e');
      return null;
    }
  }
}
