import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/store/portal_live_tv_search.dart';
import 'package:forja/shared/engine/unlock/live_broadcast_hints.dart';

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

  test('portal rail uses a real name, otherwise the site', () {
    expect(
      PortalLiveTvSearch.portalRailLabelForTest(
        url: 'http://tstv.example:80',
        username: 'LOGINID',
        label: 'LOGINID',
      ),
      'tstv.example',
    );
    expect(
      PortalLiveTvSearch.portalRailLabelForTest(
        url: 'http://tstv.example:80',
        username: 'LOGINID',
        label: 'My Sports',
      ),
      'My Sports',
    );
  });

  test('provider row labels become channel hints', () {
    final polsat = LiveBroadcastHints.channelNamesFromLabel(
      'Source · Polski | Polsat Sport 1 · SD',
    );
    expect(polsat, contains('Polsat Sport 1'));
    expect(polsat, isNot(contains('Polski')));
    expect(
      LiveBroadcastHints.channelNamesFromLabel(
        'Português | Sport TV1 · HD',
      ),
      ['Sport TV1'],
    );
    LiveBroadcastHints.remember(
      title: 'Zhang Z. - Gea A.',
      home: 'Zhang Z.',
      away: 'Gea A.',
      labels: const ['Polski | Polsat Sport 1 · HD'],
    );
    expect(
      LiveBroadcastHints.lookup(
        title: 'Zhang Z. - Gea A.',
        home: 'Zhang Z.',
        away: 'Gea A.',
      ),
      contains('Polsat Sport 1'),
    );
  });

  test('fixtureKey — stable team pair (order independent)', () {
    final a = PortalLiveTvSearch.fixtureKeyForTest({
      'homeTeam': 'Barcelona',
      'awayTeam': 'Real Madrid',
      'title': 'ignored',
    });
    final b = PortalLiveTvSearch.fixtureKeyForTest({
      'homeTeam': 'Real Madrid',
      'awayTeam': 'Barcelona',
    });
    expect(a.startsWith('t:'), isTrue);
    expect(a, b);
  });
}
