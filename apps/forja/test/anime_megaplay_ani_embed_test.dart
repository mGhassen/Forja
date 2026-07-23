import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/anime/catalog/anime_stream_providers.dart';

void main() {
  group('Megaplay AniList embeds', () {
    final service = AnimeService();

    test('uses /stream/ani/{anilist}/{ep}/{lang} — never Anikoto s-2', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
        series: const AnikotoSeries(
          id: 1,
          slug: 'should-not-affect-megaplay',
          aniId: 999,
          episodes: [
            AnikotoEpisode(
              id: 1,
              number: 1,
              title: 'Ep 1',
              embedId: '136197',
            ),
          ],
        ),
      );
      final mega = embeds.where((e) => e.server == 'megaplay').toList();
      expect(mega, isNotEmpty);
      expect(
        mega.every((e) => e.url.contains('/stream/ani/5114/1/')),
        isTrue,
      );
      expect(mega.any((e) => e.url.contains('/stream/s-2/')), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto('megaplay'), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto(null), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto(''), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto('auto'), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto('anikoto'), isTrue);
      expect(AnimeService.savedSourceNeedsAnikoto('vidnest:hianime'), isFalse);
      expect(AnimeService.savedSourceNeedsAnikoto('allanime:Yt-mp4'), isFalse);
    });

    test('Megaplay also emits /stream/mal when malId set', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 171018,
        episode: 1,
        malId: 57334,
      );
      final mega = embeds.where((e) => e.server == 'megaplay').toList();
      expect(
        mega.any((e) => e.url.contains('/stream/ani/171018/1/')),
        isTrue,
      );
      expect(
        mega.any((e) => e.url.contains('/stream/mal/57334/1/')),
        isTrue,
      );
    });

    test('VidNest always uses card AniList id — never Anikoto ani_id', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 171018,
        episode: 1,
        series: const AnikotoSeries(
          id: 4,
          aniId: 132029,
          episodes: [
            AnikotoEpisode(
              id: 1,
              number: 1,
              title: 'Ep 1',
              embedId: '128368',
            ),
          ],
        ),
      );
      final nest = embeds.where((e) => e.server == 'vidnest').toList();
      expect(nest, isNotEmpty);
      expect(
        nest.every((e) => e.url.contains('vidnest://anilist/171018/')),
        isTrue,
      );
      expect(
        nest.any((e) => e.url.contains('vidnest://anilist/132029/')),
        isFalse,
      );
    });

    test('never emits retired Vidwish alias', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
      );
      expect(embeds.where((e) => e.server == 'vidwish'), isEmpty);
      expect(AnimeStreamProviders.defaultOrder, isNot(contains('vidwish')));
      expect(AnimeStreamProviders.catalog.containsKey('vidwish'), isFalse);
    });

    test('with Anikoto slug emits anikoto://watch embeds', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 171018,
        episode: 1,
        series: const AnikotoSeries(
          id: 4,
          slug: 'dandadan-lzcmw',
          aniId: 132029,
          episodes: [
            AnikotoEpisode(
              id: 1,
              number: 1,
              title: 'Ep 1',
              embedId: '128368',
            ),
          ],
        ),
      );
      final site = embeds.where((e) => e.server == 'anikoto').toList();
      expect(site.length, 2);
      expect(
        site.every((e) => e.url.contains('anikoto://watch/dandadan-lzcmw/1/')),
        isTrue,
      );
      expect(site.first.sourceKey, 'anikoto');
    });

    test('emits Miruro AnimeDao / AllManga / AnimePahe / AniKoto', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 171018,
        episode: 1,
      );
      final miruro = embeds.where((e) => e.server == 'miruro').toList();
      final keys = miruro.map((e) => e.sourceKey).toSet();
      expect(
        keys,
        containsAll([
          'miruro:bee',
          'miruro:kiwi',
          'miruro:ally',
          'miruro:bonk',
          'miruro:zoro',
          'miruro:hop',
        ]),
      );
      expect(keys.length, AnimeStreamProviders.miruroRaceProviders.length);
      expect(
        miruro.map((e) => e.label).toSet(),
        containsAll(['AniKoto', 'AnimePahe', 'AllManga', 'AnimeDao', 'HiAnime']),
      );
      expect(
        AnimeStreamProviders.defaultOrder,
        contains('vidlink'),
      );
    });

    test('VidLink uses MAL id when present', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 3,
        malId: 20,
      );
      final vl = embeds.where((e) => e.server == 'vidlink').toList();
      expect(vl.length, 2);
      expect(
        vl.every(
          (e) => e.url ==
              'https://vidlink.pro/anime/20/3/${e.category}?fallback=true',
        ),
        isTrue,
      );
      expect(vl.map((e) => e.sourceKey).toSet(), {'vidlink'});
      expect(AnimeStreamProviders.catalog['vidlink'], 'VidLink');
    });

    test('VidLink omitted when MAL id missing', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
      );
      expect(embeds.where((e) => e.server == 'vidlink'), isEmpty);
    });
  });
}
