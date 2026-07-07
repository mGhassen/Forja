import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/book_result.dart';

class BookProgress {
  final BookResult book;
  final int chapter;
  final double scrollFraction;
  final String filePath;
  final int lastReadTimestamp;

  const BookProgress({
    required this.book,
    required this.chapter,
    required this.scrollFraction,
    required this.filePath,
    required this.lastReadTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'book': book.toJson(),
        'chapter': chapter,
        'scrollFraction': scrollFraction,
        'filePath': filePath,
        'lastReadTimestamp': lastReadTimestamp,
      };

  factory BookProgress.fromJson(Map<String, dynamic> json) => BookProgress(
        book: BookResult.fromJson(json['book'] as Map<String, dynamic>),
        chapter: json['chapter'] ?? 0,
        scrollFraction: (json['scrollFraction'] ?? 0.0).toDouble(),
        filePath: json['filePath'] ?? '',
        lastReadTimestamp: json['lastReadTimestamp'] ?? 0,
      );
}

class BookProgressService {
  BookProgressService._();
  static final BookProgressService instance = BookProgressService._();

  static const _prefsKey = 'book_progress_v1';

  Future<Directory> get booksDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}Forja_Books');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> bookFilePath(String editionId) async {
    final dir = await booksDir;
    return '${dir.path}${Platform.pathSeparator}book_$editionId.epub';
  }

  Future<List<BookProgress>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BookProgress.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastReadTimestamp.compareTo(a.lastReadTimestamp));
    } catch (e) {
      debugPrint('[BookProgress] loadAll error: $e');
      return [];
    }
  }

  Future<void> _saveAll(List<BookProgress> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveProgress({
    required BookResult book,
    required int chapter,
    required double scrollFraction,
    required String filePath,
  }) async {
    final entries = await loadAll();
    entries.removeWhere((e) => e.book.editionId == book.editionId);
    entries.insert(
      0,
      BookProgress(
        book: book,
        chapter: chapter,
        scrollFraction: scrollFraction,
        filePath: filePath,
        lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _saveAll(entries);
  }

  Future<BookProgress?> getProgress(String editionId) async {
    final entries = await loadAll();
    try {
      return entries.firstWhere((e) => e.book.editionId == editionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String editionId) async {
    final entries = await loadAll();
    final match = entries.where((e) => e.book.editionId == editionId);
    for (final entry in match) {
      try {
        final f = File(entry.filePath);
        if (f.existsSync()) f.deleteSync();
        final dir = Directory(
          '${f.parent.path}${Platform.pathSeparator}epub_book_$editionId',
        );
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (e) {
        debugPrint('[BookProgress] delete file error: $e');
      }
    }
    entries.removeWhere((e) => e.book.editionId == editionId);
    await _saveAll(entries);
  }
}
