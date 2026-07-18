import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';

void main() {
  group('Megaplay AniList embeds', () {
    final service = AnimeService();

    test('without Anikoto uses /stream/ani/{anilist}/{ep}/{lang}', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
      );
      final mega = embeds.where((e) => e.server == 'megaplay').toList();
      expect(mega, isNotEmpty);
      expect(
        mega.every(
          (e) => e.url.contains('/stream/ani/5114/1/'),
        ),
        isTrue,
      );
      expect(
        AnimeService.savedSourceNeedsAnikoto('megaplay'),
        isFalse,
      );
    });

    test('with Anikoto embed id prefers /stream/s-2/', () {
      final embeds = service.buildAllEmbeds(
        anilistId: 5114,
        episode: 1,
        series: const AnikotoSeries(
          id: 1,
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
      expect(
        mega.every((e) => e.url.contains('/stream/s-2/136197/')),
        isTrue,
      );
    });
  });
}
