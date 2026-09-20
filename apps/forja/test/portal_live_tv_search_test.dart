import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/store/portal_live_tv_search.dart';

void main() {
  test('channelMatchesGame — broadcast name', () {
    expect(
      PortalLiveTvSearch.channelMatchesGameForTest(
        'beIN Sports 1 HD',
        {
          'homeTeam': 'Real Madrid',
          'awayTeam': 'Barcelona',
          'broadcastChannels': ['beIN Sports 1'],
        },
      ),
      isTrue,
    );
  });

  test('channelMatchesGame — both teams in name', () {
    expect(
      PortalLiveTvSearch.channelMatchesGameForTest(
        'Real Madrid vs Barcelona',
        {'homeTeam': 'Real Madrid', 'awayTeam': 'Barcelona'},
      ),
      isTrue,
    );
  });

  test('channelMatchesGame — rejects unrelated', () {
    expect(
      PortalLiveTvSearch.channelMatchesGameForTest(
        'Sky News',
        {
          'homeTeam': 'Real Madrid',
          'awayTeam': 'Barcelona',
          'broadcastChannels': ['beIN Sports 1'],
        },
      ),
      isFalse,
    );
  });
}
