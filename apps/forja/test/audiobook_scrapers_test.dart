import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/audiobooks/catalog/audiobook_scrapers.dart';

void main() {
  group('parseZaudiobooksTracksFromHtml', () {
    test('extracts chapters and skips welcome track', () {
      const html = '''
        <script>
        tracks = [
          { name: "welcome", chapter_link_dropbox: "skip.mp3" },
          { name: "Chapter 1", chapter_link_dropbox: "book/ch1.mp3" },
          { name: "Chapter 2", chapter_link_dropbox: "book/ch2.mp3" },
        ],
        </script>
      ''';

      final chapters = parseZaudiobooksTracksFromHtml(html);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Chapter 001');
      expect(chapters[0].url, '${zaudiobooksAudioBase}book/ch1.mp3');
      expect(chapters[1].url, '${zaudiobooksAudioBase}book/ch2.mp3');
    });

    test('returns empty when tracks block missing', () {
      expect(parseZaudiobooksTracksFromHtml('<html></html>'), isEmpty);
    });
  });

  group('parseMpegSourcesFromHtml', () {
    test('extracts and strips query params from mp3 sources', () {
      const html = '''
        <div class="entry">
          <source type="audio/mpeg" src="https://cdn.example.com/ch1.mp3?_=1" />
          <source type="audio/mpeg" src="https://cdn.example.com/ch2.mp3" />
        </div>
      ''';

      final chapters = parseMpegSourcesFromHtml(html, '.entry source[type="audio/mpeg"]');
      expect(chapters.length, 2);
      expect(chapters[0].url, 'https://cdn.example.com/ch1.mp3');
      expect(chapters[1].title, 'Chapter 002');
    });
  });

  group('parseHdAudiobooksChaptersFromHtml', () {
    test('falls back to entry-box selector', () {
      const html = '''
        <div class="entry-box">
          <source type="audio/mpeg" src="https://cdn.example.com/hd1.mp3?_=2" />
        </div>
      ''';

      final chapters = parseHdAudiobooksChaptersFromHtml(html);
      expect(chapters.length, 1);
      expect(chapters[0].url, 'https://cdn.example.com/hd1.mp3');
    });
  });

  group('parseGoldenBrowseFromHtml', () {
    test('parses pt-cv-title homepage layout', () {
      const html = '''
        <div class="pt-cv-title"><a href="https://goldenaudiobooks.com/sample-audiobook/">Author - Sample Audiobook</a></div>
      ''';
      final hits = parseGoldenBrowseFromHtml(html);
      expect(hits.length, 1);
      expect(hits[0].pageUrl, contains('goldenaudiobooks.com'));
    });
  });

  group('parseBigSearchFromHtml', () {
    test('parses search result cards', () {
      const html = '''
        <article class="post">
          <h1 class="title-page"><a href="https://bigaudiobooks.net/sample-book/">Author - Sample Book Audiobook</a></h1>
          <img data-lazy-src="https://bigaudiobooks.net/cover-150x200.jpg" />
        </article>
      ''';

      final hits = parseBigSearchFromHtml(html);
      expect(hits.length, 1);
      expect(hits[0].pageUrl, 'https://bigaudiobooks.net/sample-book/');
      expect(hits[0].title, contains('Sample Book'));
      expect(hits[0].coverUrl, 'https://bigaudiobooks.net/cover.jpg');
    });
  });

  group('stripAudioQuery', () {
    test('removes query string', () {
      expect(stripAudioQuery('https://x.com/a.mp3?_=1'), 'https://x.com/a.mp3');
    });
  });
}
