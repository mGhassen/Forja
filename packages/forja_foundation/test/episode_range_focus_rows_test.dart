import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/widgets/details/episode_range_bar.dart';

void main() {
  test('detailsEpisodeFocusRowCount: chrome + seasons? + episodes', () {
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: false,
        seasonCount: 0,
      ),
      0,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 1,
      ),
      2,
    );
    expect(
      detailsEpisodeFocusRowCount(
        hasEpisodes: true,
        seasonCount: 3,
      ),
      3,
    );
    // showRange is ignored — view chrome is always one row.
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
