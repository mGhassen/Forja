import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Manga {
  final String id;
  final String title;
  final String coverSmall;
  final String coverNormal;
  final String type;
  final String status;
  final String year;
  final String author;
  final List<String> tags;
  final String synopsis;
  final String url;

  Manga({
    required this.id,
    required this.title,
    required this.coverSmall,
    required this.coverNormal,
    this.type = '',
    this.status = '',
    this.year = '',
    this.author = '',
    this.tags = const [],
    this.synopsis = '',
    this.url = '',
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverSmall: json['cover_small'] ?? json['coverSmall'] ?? '',
      coverNormal: json['cover_normal'] ?? json['coverNormal'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      year: json['year'] ?? '',
      author: json['author'] ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      synopsis: json['synopsis'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_small': coverSmall,
      'cover_normal': coverNormal,
      'type': type,
      'status': status,
      'year': year,
      'author': author,
      'tags': tags,
      'synopsis': synopsis,
      'url': url,
    };
  }
}

class MangaChapter {
  final String id;
  final double number;
  final String name;
  final String url;
  final String rawName;

  MangaChapter({
    required this.id,
    required this.number,
    this.name = '',
    this.url = '',
    this.rawName = '',
  });

  factory MangaChapter.fromRaw(String id, String rawName, String url) {
    String cleaned = rawName;
    if (cleaned.toLowerCase().startsWith('chapter')) {
      cleaned = cleaned.substring(7).trim();
    }
    final separatorIndex = cleaned.indexOf(RegExp(r'[:\-–]'));
    String numberStr;
    String title;
    if (separatorIndex > 0) {
      numberStr = cleaned.substring(0, separatorIndex).trim();
      title = cleaned.substring(separatorIndex + 1).trim();
    } else {
      numberStr = cleaned.trim();
      title = '';
    }
    final number = double.tryParse(numberStr) ?? 0;
    return MangaChapter(id: id, number: number, name: title, url: url, rawName: rawName);
  }

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id']?.toString() ?? '',
      number: (json['number'] is String
              ? double.tryParse(json['number']) ?? 0
              : json['number'] ?? 0)
          .toDouble(),
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      rawName: json['raw_name'] ?? json['rawName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'url': url,
      'raw_name': rawName,
    };
  }
}

class MangaService {
  static const String _likedKey = 'liked_manga';

  Future<List<Manga>> getManga({int page = 1, String? tag, bool allowAdult = false}) async {
    try {
      final decoded = await mangaCatalog({
        'action': 'browse',
        'page': page,
        'tag': ?tag,
        'allow_adult': allowAdult,
      });
      return ((decoded['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Manga.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[MangaService] Error fetching manga: $e');
      return [];
    }
  }

  Future<List<Manga>> searchManga(String query, {int page = 1, bool allowAdult = false}) async {
    try {
      final decoded = await mangaCatalog({
        'action': 'search',
        'query': query,
        'page': page,
        'allow_adult': allowAdult,
      });
      return ((decoded['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Manga.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[MangaService] Error searching manga: $e');
      return [];
    }
  }

  Future<Manga> getSeriesDetail(String seriesId) async {
    final decoded = await mangaCatalog({
      'action': 'details',
      'series_id': seriesId,
    });
    final details = decoded['details'];
    if (details is! Map) {
      throw Exception('missing details');
    }
    return Manga.fromJson(details.cast<String, dynamic>());
  }

  Future<List<MangaChapter>> getChapters(String seriesId) async {
    try {
      final decoded = await mangaCatalog({
        'action': 'chapters',
        'series_id': seriesId,
      });
      final list = ((decoded['chapters'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MangaChapter.fromJson(e.cast<String, dynamic>()))
          .toList();
      debugPrint('[MangaService] Found ${list.length} chapters');
      return list;
    } catch (e) {
      debugPrint('[MangaService] Error fetching chapters: $e');
      return [];
    }
  }

  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      final decoded = await mangaCatalog({
        'action': 'chapter_images',
        'chapter_id': chapterId,
      });
      final images = ((decoded['images'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      debugPrint('[MangaService] Found ${images.length} chapter images');
      return images;
    } catch (e) {
      debugPrint('[MangaService] Error fetching chapter images: $e');
      return [];
    }
  }

  Future<void> toggleLike(Manga manga) async {
    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getStringList(_likedKey) ?? [];

    final index = likedJson.indexWhere((j) {
      final m = jsonDecode(j) as Map<String, dynamic>;
      return m['id'] == manga.id;
    });

    if (index != -1) {
      likedJson.removeAt(index);
    } else {
      likedJson.add(jsonEncode(manga.toJson()));
    }

    await prefs.setStringList(_likedKey, likedJson);
  }

  Future<bool> isLiked(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getStringList(_likedKey) ?? [];
    return likedJson.any((j) {
      final m = jsonDecode(j) as Map<String, dynamic>;
      return m['id'] == id;
    });
  }

  Future<List<Manga>> getLikedManga() async {
    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getStringList(_likedKey) ?? [];
    return likedJson.map((j) => Manga.fromJson(jsonDecode(j))).toList();
  }

  static const List<String> availableTags = [
    'Action',
    'Adventure',
    'Comedy',
    'Cooking',
    'Doujinshi',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Gender Bender',
    'Harem',
    'Historical',
    'Horror',
    'Isekai',
    'Josei',
    'Lolicon',
    'Martial Arts',
    'Mature',
    'Mecha',
    'Medical',
    'Music',
    'Mystery',
    'One Shot',
    'Psychological',
    'Romance',
    'School Life',
    'Sci-Fi',
    'Seinen',
    'Shotacon',
    'Shoujo',
    'Shoujo Ai',
    'Shounen',
    'Shounen Ai',
    'Slice of Life',
    'Smut',
    'Sports',
    'Supernatural',
    'Tragedy',
    'Yaoi',
    'Yuri',
  ];
}
