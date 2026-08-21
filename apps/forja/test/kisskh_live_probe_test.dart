// Live probe: KissKh scraper against The First Frost (id=8316).
// Run: KISSKH_LIVE=1 flutter test test/kisskh_live_probe_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/extractors/providers/kisskh/kisskh_kkey.dart';
import 'package:http/http.dart' as http;

const _dramaId = 8316;
const _origin = 'https://kisskh.co';
const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';

bool get _live =>
    const bool.fromEnvironment('KISSKH_LIVE', defaultValue: false) ||
    Platform.environment['KISSKH_LIVE'] == '1';

Map<String, String> get _headers => {
      'User-Agent': _ua,
      'Accept': 'application/json',
      'Referer': '$_origin/',
    };

/// Undo Flutter test's HttpClient stub so live probes can hit the network.
class _LiveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => HttpClient();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _LiveHttpOverrides();

  test('KissKh live: The First Frost (8316) API + scraper', () async {
    if (!_live) {
      // ignore: avoid_print
      print('SKIP — set KISSKH_LIVE=1 to run');
      return;
    }

    final dramaRes = await http.get(
      Uri.parse('$_origin/api/DramaList/Drama/$_dramaId?isq=false'),
      headers: _headers,
    );
    // ignore: avoid_print
    print('Drama HTTP ${dramaRes.statusCode}');
    expect(dramaRes.statusCode, 200, reason: dramaRes.body);
    final drama = jsonDecode(dramaRes.body) as Map<String, dynamic>;
    final title = drama['title']?.toString() ?? '';
    final eps = (drama['episodes'] as List?) ?? const [];
    // ignore: avoid_print
    print('title=$title id=${drama['id']} episodes=${eps.length}');
    expect(title.toLowerCase(), contains('frost'));
    expect(eps, isNotEmpty);

    final sorted = [...eps.cast<Map<String, dynamic>>()]
      ..sort(
        (a, b) =>
            ((a['number'] as num?) ?? 0).compareTo((b['number'] as num?) ?? 0),
      );
    final ep1 = sorted.first;
    final epId = (ep1['id'] as num).toInt();
    final epNum = (ep1['number'] as num).toDouble();
    // ignore: avoid_print
    print('ep1 number=$epNum id=$epId');

    final noKey = await http.get(
      Uri.parse(
        '$_origin/api/DramaList/Episode/$epId.png?err=false&ts=&time=',
      ),
      headers: _headers,
    );
    // ignore: avoid_print
    print('episode no-kkey HTTP ${noKey.statusCode} len=${noKey.body.length}');

    final kkey = KissKhKkey.generate(epId);
    final withKey = await http.get(
      Uri.parse(
        '$_origin/api/DramaList/Episode/$epId.png?err=false&ts=&time='
        '&kkey=${Uri.encodeComponent(kkey)}',
      ),
      headers: _headers,
    );
    // ignore: avoid_print
    print(
      'episode with-kkey HTTP ${withKey.statusCode} len=${withKey.body.length}',
    );

    String? videoUrl;
    if (withKey.statusCode == 200 && withKey.body.isNotEmpty) {
      final api = jsonDecode(withKey.body) as Map<String, dynamic>;
      final video =
          api['Video'] ?? api['video'] ?? api['VideoUrl'] ?? api['videoUrl'];
      final third = api['ThirdParty'] ?? api['thirdParty'];
      videoUrl = video?.toString();
      // ignore: avoid_print
      print(
        'Video=${videoUrl == null ? null : (videoUrl.length > 140 ? '${videoUrl.substring(0, 140)}…' : videoUrl)}',
      );
      // ignore: avoid_print
      print('ThirdParty count=${third is List ? third.length : 0}');
      expect(
        video != null || (third is List && third.isNotEmpty),
        isTrue,
        reason: 'episode payload should have Video or ThirdParty',
      );
    } else if (noKey.statusCode == 200 && noKey.body.isNotEmpty) {
      final api = jsonDecode(noKey.body) as Map<String, dynamic>;
      videoUrl =
          (api['Video'] ?? api['video'] ?? api['VideoUrl'] ?? api['videoUrl'])
              ?.toString();
      // ignore: avoid_print
      print('Video (no-kkey)=$videoUrl');
    }

    // Actual Forja kisskh.js — same path Sources uses with drama/episode ids
    final code = await rootBundle.loadString('assets/providers/kisskh.js');
    final rt = EngineRuntime.instance;
    await rt.loadPlugin(pluginId: 'kisskh-live', code: code);

    final byEpisodeId = await rt.extract(
      pluginId: 'kisskh-live',
      tmdbId: '0',
      type: 'drama',
      title: title,
      episode: epNum.toInt(),
      config: {
        'origin': _origin,
        'episodeId': epId,
      },
      timeout: const Duration(seconds: 60),
      allowHostFallback: false,
    );
    // ignore: avoid_print
    print('scraper(episodeId=$epId) streams=${byEpisodeId.length}');
    for (final s in byEpisodeId.take(5)) {
      // ignore: avoid_print
      print('  → ${s['name']} ${s['url']}');
    }

    final byDramaId = await rt.extract(
      pluginId: 'kisskh-live',
      tmdbId: '0',
      type: 'drama',
      title: title,
      episode: 1,
      config: {
        'origin': _origin,
        'dramaId': _dramaId,
      },
      timeout: const Duration(seconds: 60),
      allowHostFallback: false,
    );
    // ignore: avoid_print
    print('scraper(dramaId=$_dramaId) streams=${byDramaId.length}');
    for (final s in byDramaId.take(5)) {
      // ignore: avoid_print
      print('  → ${s['name']} ${s['url']}');
    }

    final byTitle = await rt.extract(
      pluginId: 'kisskh-live',
      tmdbId: '0',
      type: 'drama',
      title: 'The First Frost',
      episode: 1,
      config: {'origin': _origin},
      timeout: const Duration(seconds: 60),
      allowHostFallback: false,
    );
    // ignore: avoid_print
    print('scraper(title only) streams=${byTitle.length}');
    for (final s in byTitle.take(5)) {
      // ignore: avoid_print
      print('  → ${s['name']} ${s['url']}');
    }

    final any =
        byEpisodeId.isNotEmpty || byDramaId.isNotEmpty || byTitle.isNotEmpty;
    expect(
      any || videoUrl != null,
      isTrue,
      reason:
          'expected streams from kisskh.js OR a direct Video URL from Episode API',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
