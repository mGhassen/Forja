import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('isPlausibleSubtitleBytes', () {
    test('accepts SRT timing', () {
      const srt = '1\n00:00:01,000 --> 00:00:04,000\nHello\n';
      expect(isPlausibleSubtitleBytes(srt.codeUnits), isTrue);
    });

    test('accepts WEBVTT', () {
      const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:04.000\nHello\n';
      expect(isPlausibleSubtitleBytes(vtt.codeUnits), isTrue);
      expect(externalSubtitleFileExtension(vtt.codeUnits), 'vtt');
    });

    test('keeps timed SRT as srt', () {
      const srt = '1\n00:00:01,000 --> 00:00:04,000\nHello\n';
      expect(externalSubtitleFileExtension(srt.codeUnits), 'srt');
    });

    test('rejects OpenSubtitles HTML error page', () {
      const html =
          'Sorry. We have problem with network connection to database server, '
          'try reload page.<!-- Not connected to database server pcie\n'
          'CANNOT CONNECT TO DB:';
      expect(isPlausibleSubtitleBytes(html.codeUnits), isFalse);
    });

    test('rejects generic HTML', () {
      const html = '<html><body>404</body></html>';
      expect(isPlausibleSubtitleBytes(html.codeUnits), isFalse);
    });
  });

  group('isSideloadedExternalSubtitleTrack', () {
    test('detects SubtitleTrack.uri sideloads', () {
      expect(
        isSideloadedExternalSubtitleTrack(
          SubtitleTrack.uri(
            'file:///tmp/forja_sub_123_en.srt',
            title: 'English 1 - levrx',
            language: 'en',
          ),
        ),
        isTrue,
      );
    });

    test('detects forja cache paths', () {
      expect(
        isSideloadedExternalSubtitleTrack(
          SubtitleTrack(
            'file:///tmp/forja_sub_123_en.srt',
            'Forja Sub 123 En.srt',
            'en',
          ),
        ),
        isTrue,
      );
    });

    test('keeps muxed HLS subtitle ids', () {
      expect(
        isSideloadedExternalSubtitleTrack(
          const SubtitleTrack('2', 'English', 'en'),
        ),
        isFalse,
      );
    });
  });

  group('pickPlaylistSubtitleRendition', () {
    test('English playlist rendition wins over a later track', () {
      final pick = pickPlaylistSubtitleRendition<Map<String, String>>(
        preferredLang: 'English',
        renditions: const [
          {'language': 'es', 'name': 'Spanish', 'uri': 'es.vtt'},
          {'language': 'en', 'name': 'English', 'uri': 'en.vtt'},
        ],
        languageOf: (r) => r['language'] ?? '',
        titleOf: (r) => r['name'] ?? '',
      );
      expect(pick?['uri'], 'en.vtt');
    });

    test('falls back to English when the preferred language is absent', () {
      final pick = pickPlaylistSubtitleRendition<Map<String, String>>(
        preferredLang: 'French',
        renditions: const [
          {'language': 'en', 'name': 'English', 'uri': 'en.vtt'},
        ],
        languageOf: (r) => r['language'] ?? '',
        titleOf: (r) => r['name'] ?? '',
      );
      expect(pick?['uri'], 'en.vtt');
    });

    test('returns null when nothing matches', () {
      final pick = pickPlaylistSubtitleRendition<Map<String, String>>(
        preferredLang: 'French',
        renditions: const [
          {'language': 'th', 'name': 'Thai', 'uri': 'th.vtt'},
        ],
        languageOf: (r) => r['language'] ?? '',
        titleOf: (r) => r['name'] ?? '',
      );
      expect(pick, isNull);
    });
  });

  group('externalSubtitleAutoCandidates', () {
    test('orders by rank and dedupes', () {
      final subs = [
        {
          'url': 'https://a/levrx-1',
          'language': 'en',
          'display': 'English 2 - levrx',
          'translated': true,
        },
        {
          'url': 'https://a/levrx-2',
          'language': 'en',
          'display': 'English 1 - levrx',
        },
      ];
      final picks = externalSubtitleAutoCandidates(
        preferredLang: 'English',
        subs: subs,
      );
      expect(picks.map((s) => s['url']), [
        'https://a/levrx-2',
        'https://a/levrx-1',
      ]);
    });

    test('puts preferUrlFirst ahead of ranked list', () {
      final subs = [
        {'url': 'https://a/best', 'language': 'en', 'display': 'English 1'},
        {'url': 'https://a/stale', 'language': 'en', 'display': 'English 2'},
      ];
      final picks = externalSubtitleAutoCandidates(
        preferredLang: 'English',
        subs: subs,
        preferUrlFirst: 'https://a/stale',
      );
      expect(picks.first['url'], 'https://a/stale');
      expect(picks.length, 2);
    });
  });

  group('stripSubtitlePromoCues', () {
    const promo = "You're on the free plan. Unlock every source, AI "
        'translation & ad-free subs → store.wyzie.io';

    test('drops the Wyzie free-plan cue from SRT', () {
      final srt = '1\r\n00:00:00,000 --> 00:00:06,000\r\n$promo\r\n\r\n'
          '2\r\n00:00:25,876 --> 00:00:29,156\r\n[BABIES crying]\r\n';
      final out = utf8.decode(stripSubtitlePromoCues(utf8.encode(srt)));
      expect(out, isNot(contains('wyzie')));
      expect(out, contains('[BABIES crying]'));
      expect(isPlausibleSubtitleBytes(utf8.encode(out)), isTrue);
    });

    test('drops the cue from WEBVTT and keeps the header', () {
      final vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:06.000\n$promo\n\n'
          '00:00:25.876 --> 00:00:29.156\nHello\n';
      final out = utf8.decode(stripSubtitlePromoCues(utf8.encode(vtt)));
      expect(out, startsWith('WEBVTT'));
      expect(out, isNot(contains('wyzie')));
      expect(out, contains('Hello'));
    });

    test('leaves clean files untouched', () {
      final bytes = utf8.encode('1\n00:00:01,000 --> 00:00:04,000\nHi\n');
      expect(identical(stripSubtitlePromoCues(bytes), bytes), isTrue);
    });
  });
}
