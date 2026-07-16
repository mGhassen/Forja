import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
  });

  final String id;
  final String title;
  final String body;
  final String severity;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
    );
  }
}

class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  static const _dismissedKey = 'announcement_dismissed_ids';

  Future<List<Announcement>> fetchActive({bool excludeDismissed = true}) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('announcements')
          .select('id, title, body, severity')
          .order('created_at', ascending: false);
      var list = (rows as List)
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (excludeDismissed) {
        final dismissed = await _dismissedIds();
        list = list.where((a) => !dismissed.contains(a.id)).toList();
      }
      return list;
    } catch (e) {
      debugPrint('[Announcements] fetch error: $e');
      return const [];
    }
  }

  Future<void> dismiss(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_dismissedKey) ?? <String>[];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList(_dismissedKey, ids);
    }
  }

  Future<Set<String>> _dismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissedKey) ?? const <String>[]).toSet();
  }
}
