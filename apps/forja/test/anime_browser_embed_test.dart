import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_browser_embed.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';

void main() {
  group('animeBrowserEmbedFor', () {
    test('megaplay s-2 keeps https stream URL', () {
      final emb = AnimeEmbed(
        label: 'Megaplay',
        server: 'megaplay',
        category: 'sub',
        url: 'https://megaplay.buzz/stream/s-2/128368/sub',
      );
      final b = animeBrowserEmbedFor(emb);
      expect(b, isNotNull);
      expect(b!.url, contains('megaplay.buzz/stream/s-2/128368/sub'));
      expect(b.origin, contains('megaplay.buzz'));
    });

    test('megaplay /stream/ani/ skipped (dead HTML shell)', () {
      final emb = AnimeEmbed(
        label: 'Megaplay',
        server: 'megaplay',
        category: 'sub',
        url: 'https://megaplay.buzz/stream/ani/154587/1/sub',
      );
      expect(animeBrowserEmbedFor(emb), isNull);
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

    test('anikoto slug only when no VidNest/Megaplay embeds', () {
      final list = animeBrowserEmbedFallbacks(
        embeds: const [],
        category: 'sub',
        anikotoSlug: 'mushoku-tensei-jobless-reincarnation-season-3',
        episode: 1,
      );
      expect(list, isNotEmpty);
      expect(
        list.first.url,
        'https://anikoto.cz/watch/mushoku-tensei-jobless-reincarnation-season-3/ep-1',
      );
      expect(list.first.loadInMainFrame, isTrue);
    });

    test('VidNest site player before Megaplay and Anikoto', () {
      final embeds = [
        AnimeEmbed(
          label: 'Megaplay',
          server: 'megaplay',
          category: 'sub',
          url: 'https://megaplay.buzz/stream/s-2/1/sub',
        ),
        AnimeEmbed(
          label: 'VidNest HiAnime',
          server: 'vidnest',
          category: 'sub',
          url: 'vidnest://anilist/21/2/sub/hianime',
        ),
        AnimeEmbed(
          label: 'VidNest AnimePahe',
          server: 'vidnest',
          category: 'sub',
          url: 'vidnest://anilist/21/2/sub/animepahe',
        ),
      ];
      final list = animeBrowserEmbedFallbacks(
        embeds: embeds,
        category: 'sub',
        anikotoSlug: 'foo-bar',
        episode: 2,
      );
      expect(list[0].url, 'https://vidnest.fun/anime/21/2/sub');
      expect(list[1].url, 'https://vidnest.fun/animepahe/21/2/sub');
      expect(list[2].url, contains('megaplay'));
      expect(list[3].url, 'https://anikoto.cz/watch/foo-bar/ep-2');
      expect(list[3].loadInMainFrame, isTrue);
    });

    test('megaplay before anikoto when no VidNest embeds', () {
      final megaplay = AnimeEmbed(
        label: 'Megaplay',
        server: 'megaplay',
        category: 'sub',
        url: 'https://megaplay.buzz/stream/s-2/1/sub',
      );
      final list = animeBrowserEmbedFallbacks(
        embeds: [megaplay],
        category: 'sub',
        anikotoSlug: 'foo-bar',
        episode: 2,
      );
      expect(list.first.url, contains('megaplay'));
      expect(list[1].url, 'https://anikoto.cz/watch/foo-bar/ep-2');
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
