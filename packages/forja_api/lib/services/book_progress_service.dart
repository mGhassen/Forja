import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forja_api/api/books_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reading progress entry
// ─────────────────────────────────────────────────────────────────────────────

class BookProgress {
  final BookResult book;
  final int chapter;
  final double scrollFraction; // 0.0 – 1.0
  final String filePath;       // where the .epub lives on disk
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

// ─────────────────────────────────────────────────────────────────────────────
// Singleton service
// ─────────────────────────────────────────────────────────────────────────────

class BookProgressService {
  BookProgressService._();
  static final BookProgressService instance = BookProgressService._();

  static const _prefsKey = 'book_progress_v1';

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Persistent directory for downloaded books (survives app restarts).
  /// - Android: getApplicationDocumentsDirectory() → /data/.../app_flutter/
  /// - Windows: getApplicationDocumentsDirectory() → %APPDATA%\...\Documents\
  Future<Directory> get booksDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}Forja_Books');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Return the canonical file path for a given edition.
  Future<String> bookFilePath(String editionId) async {
    final dir = await booksDir;
    return '${dir.path}${Platform.pathSeparator}book_$editionId.epub';
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

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

  /// Update or insert progress for a book.
  Future<void> saveProgress({
    required BookResult book,
    required int chapter,
    required double scrollFraction,
    required String filePath,
  }) async {
    final entries = await loadAll();
    entries.removeWhere((e) => e.book.editionId == book.editionId);
    entries.insert(0, BookProgress(
      book: book,
      chapter: chapter,
      scrollFraction: scrollFraction,
      filePath: filePath,
      lastReadTimestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    await _saveAll(entries);
  }

  /// Get saved progress for a specific edition.
  Future<BookProgress?> getProgress(String editionId) async {
    final entries = await loadAll();
    try {
      return entries.firstWhere((e) => e.book.editionId == editionId);
    } catch (_) {
      return null;
    }
  }

  /// Delete progress + file for a book.
  Future<void> delete(String editionId) async {
    final entries = await loadAll();
    final match = entries.where((e) => e.book.editionId == editionId);
    for (final entry in match) {
      try {
        final f = File(entry.filePath);
        if (f.existsSync()) f.deleteSync();
        // also remove extracted folder if present
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
