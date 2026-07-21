import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:rust/rust.dart';

void main() {
  tearDown(() {
    SettingsService.animeTitleLanguageNotifier.value = 'romaji';
  });

  AnimeCard card() => const AnimeCard(
        id: 1905,
        titleEnglish: 'In a Distant Time: Character Endings',
        titleRomaji: 'Harukanaru Toki no Naka de: Hachiyou Shou Specials',
        titleNative: '遙かなる時空の中で〜八葉抄〜',
        synonyms: [
          'Harukanaru Toki no Naka de: Character Endings',
          'In a Distant Time: Character Endings',
        ],
        format: 'SPECIAL',
        episodes: 8,
      );

  test('displayTitle defaults to romaji', () {
    SettingsService.animeTitleLanguageNotifier.value = 'romaji';
    expect(
      card().displayTitle,
      'Harukanaru Toki no Naka de: Hachiyou Shou Specials',
    );
  });

  test('displayTitle respects english preference', () {
    SettingsService.animeTitleLanguageNotifier.value = 'english';
    expect(card().displayTitle, 'In a Distant Time: Character Endings');
  });

  test('resolveTitleCandidates is romaji-first with synonyms deduped', () {
    final titles = card().resolveTitleCandidates();
    expect(titles.first, 'Harukanaru Toki no Naka de: Hachiyou Shou Specials');
    expect(titles, contains('In a Distant Time: Character Endings'));
    expect(titles, contains('Harukanaru Toki no Naka de: Character Endings'));
    expect(
      titles.where((t) => t == 'In a Distant Time: Character Endings').length,
      1,
    );
  });
}
