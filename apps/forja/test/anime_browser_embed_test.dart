import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_browser_embed.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';

void main() {
  group('animeBrowserEmbedFor', () {
    test('megaplay keeps https stream URL', () {
      final emb = AnimeEmbed(
        label: 'Megaplay',
        server: 'megaplay',
        category: 'sub',
        url: 'https://megaplay.buzz/stream/ani/154587/1/sub',
      );
      final b = animeBrowserEmbedFor(emb);
      expect(b, isNotNull);
      expect(b!.url, contains('megaplay.buzz/stream/ani/154587/1/sub'));
      expect(b.origin, contains('megaplay.buzz'));
    });

    test('vidnest animepahe builds public embed page', () {
      final emb = AnimeEmbed(
        label: 'VidNest AnimePahe',
        server: 'vidnest',
        category: 'sub',
        url: 'vidnest://anilist/154587/1/sub/animepahe',
      );
      final b = animeBrowserEmbedFor(emb);
      expect(b, isNotNull);
      expect(b!.url, 'https://vidnest.fun/animepahe/154587/1/sub');
    });

    test('vidnest hianime builds /anime/ page', () {
      final emb = AnimeEmbed(
        label: 'VidNest HiAnime',
        server: 'vidnest',
        category: 'dub',
        url: 'vidnest://anilist/21/3/dub/hianime',
      );
      final b = animeBrowserEmbedFor(emb);
      expect(b!.url, 'https://vidnest.fun/anime/21/3/dub');
    });

    test('miruro has no browser page', () {
      final emb = AnimeEmbed(
        label: 'Miruro',
        server: 'miruro',
        category: 'sub',
        url: 'miruro://anilist/1/1/sub/zoro',
      );
      expect(animeBrowserEmbedFor(emb), isNull);
    });
  });
}
