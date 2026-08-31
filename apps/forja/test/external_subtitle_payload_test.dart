import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/track_auto_select.dart';
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
}
