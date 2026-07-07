import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

class SubtitleApi {
  // Legacy method for backward compatibility if needed
  static Future<List<Map<String, dynamic>>> fetchSubtitles({
    required int tmdbId,
    String? imdbId,
    int? season,
    int? episode,
    String? title,
    int? year,
  }) async {
    final stream = fetchSubtitlesStream(
      tmdbId: tmdbId,
      imdbId: imdbId,
      season: season,
      episode: episode,
      title: title,
      year: year,
    );
    
    List<Map<String, dynamic>> finalSubs = [];
    await for (final subs in stream) {
      finalSubs = subs;
    }
    return finalSubs;
  }

  // New Stream-based method for real-time updates
  static Stream<List<Map<String, dynamic>>> fetchSubtitlesStream({
    required int tmdbId,
    String? imdbId,
    int? season,
    int? episode,
    String? title,
    int? year,
  }) async* {
    final List<Map<String, dynamic>> allSubs = [];
    final stremio = StremioService();

    final List<Future<List<Map<String, dynamic>>>> tasks = [];

    // Wyzie
    tasks.add(_fetchWyzie(tmdbId, season, episode));

    // Levrx
    tasks.add(_fetchLevrx(tmdbId, season, episode));

    // SubtitleCat (scraping + on-demand Google translation)
    if (title != null && title.trim().isNotEmpty) {
      tasks.add(_fetchSubtitleCat(
        title: title,
        year: year,
        season: season,
        episode: episode,
      ));
      tasks.add(_fetchMysubs(
        title: title,
        year: year,
        season: season,
        episode: episode,
      ));
    }

    // Stremio addon subtitles
    if (imdbId != null) {
      final subAddons = await SettingsService().getStremioAddons();
      final relevantAddons = subAddons.where((a) {
        final resources = a['manifest']['resources'] as List;
        return resources.any((r) => 
          (r is String && r == 'subtitles') || 
          (r is Map && r['name'] == 'subtitles')
        );
      }).toList();

      if (relevantAddons.isNotEmpty) {
        final String resourceId = (season != null && episode != null) 
            ? '$imdbId:$season:$episode' 
            : imdbId;
        final String type = (season != null && episode != null) ? 'series' : 'movie';

        for (var addon in relevantAddons) {
          tasks.add(stremio.getSubtitles(
            baseUrl: addon['baseUrl'], 
            type: type, 
            id: resourceId,
            addonName: addon['name'],
          ));
        }
      }
    }

    // Emit updated list as each source completes
    final int totalTasks = tasks.length;
    int completedTasks = 0;
    
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    for (var task in tasks) {
      task.then((subs) {
        allSubs.addAll(subs);
        
        // English first, then alphabetical by display
        allSubs.sort((a, b) {
          final aLang = (a['language'] ?? '').toString().toLowerCase();
          final bLang = (b['language'] ?? '').toString().toLowerCase();
          final aIsEn = aLang == 'en' || aLang == 'eng' || aLang.contains('english');
          final bIsEn = bLang == 'en' || bLang == 'eng' || bLang.contains('english');
          if (aIsEn && !bIsEn) return -1;
          if (!aIsEn && bIsEn) return 1;
          return (a['display'] ?? '').compareTo(b['display'] ?? '');
        });

        controller.add(List.from(allSubs));
        completedTasks++;
        if (completedTasks == totalTasks) controller.close();
      }).catchError((e) {
        debugPrint('Subtitle task error: $e');
        completedTasks++;
        if (completedTasks == totalTasks) controller.close();
      });
    }

    yield* controller.stream;
  }

  static Future<List<Map<String, dynamic>>> _fetchWyzie(int tmdbId, int? season, int? episode) async {
    try {
      return await subtitleEntries({
        'action': 'wyzie_fetch',
        'tmdb_id': tmdbId,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
      });
    } catch (e) {
      debugPrint('Wyzie error: $e');
      return [];
    }
  }

  // ── Levrx ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _fetchLevrx(int tmdbId, int? season, int? episode) async {
    try {
      return await subtitleEntries({
        'action': 'levrx_fetch',
        'tmdb_id': tmdbId,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
      });
    } catch (e) {
      debugPrint('Levrx error: $e');
      return [];
    }
  }

  // ── SubtitleCat ────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _fetchMysubs({
    required String title,
    int? year,
    int? season,
    int? episode,
  }) async {
    try {
      return await MysubsService.instance.fetchAll(
        title: title,
        year: year,
        season: season,
        episode: episode,
      );
    } catch (e) {
      debugPrint('mysubs fetch error: $e');
      return [];
    }
  }
  static Future<List<Map<String, dynamic>>> _fetchSubtitleCat({
    required String title,
    int? year,
    int? season,
    int? episode,
  }) async {
    try {
      // Translation entries route through the local proxy server so the
      // player can fetch a translated SRT on demand.
      final localPort = LocalServerService().port;
      final translateBase =
          localPort > 0 ? 'http://localhost:$localPort' : null;

      return await SubtitleCatService.instance.fetchAll(
        title: title,
        year: year,
        season: season,
        episode: episode,
        translateBaseUrl: translateBase,
      );
    } catch (e) {
      debugPrint('SubtitleCat error: $e');
      return [];
    }
  }
}

