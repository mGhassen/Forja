import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';

void main() {
  test('detailsEpisodeFocusRowCount covers range + seasons + episodes', () {
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: false,
        seasonCount: 0,
        showRange: false,
      ),
      0,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 1,
        showRange: false,
      ),
      1,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 3,
        showRange: false,
      ),
      2,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 3,
        showRange: true,
      ),
      3,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 1,
        showRange: true,
      ),
      2,
    );
  });

  test('episodeViewIsChips only matches chips', () {
    expect(episodeViewIsChips(null), isFalse);
    expect(episodeViewIsChips('cards'), isFalse);
    expect(episodeViewIsChips('Chips'), isTrue);
    expect(episodeViewIsChips(kEpisodeViewChips), isTrue);
  });
}
