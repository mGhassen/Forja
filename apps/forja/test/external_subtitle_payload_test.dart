import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/track_auto_select.dart';

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
}
