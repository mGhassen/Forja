import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';

void main() {
  test('splits Xtream dump into title, subtitle, tier badge', () {
    const src = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'T4 · NFL Teams: FOX Raiders (KVVU) Las Vegas NV',
      detail: 'USA | NFL Teams',
      logoUrl: 'http://portal.example/logo.png',
    );
    expect(src.tierBadge, 'T4');
    expect(src.pickerTitle, 'FOX Raiders (KVVU) Las Vegas NV');
    expect(src.pickerSubtitle, 'USA · NFL Teams');
    expect(src.logoUrl, 'http://portal.example/logo.png');
  });

  test('uses text after colon as title when pipes wrap the dump', () {
    const src = IptvPlaySource(
      url: 'http://x/1.m3u8',
      label: 'T3 · AU | NRL 03(x): Sharks v Raiders | Sat 15th Aug 6:00AM UK',
      detail: 'Australia | AFL NRL',
    );
    expect(src.tierBadge, 'T3');
    expect(src.pickerTitle, 'Sharks v Raiders');
    expect(src.pickerSubtitle, 'Australia · AFL NRL');
  });

  test('plain labels stay intact', () {
    const src = IptvPlaySource(url: 'http://x/a.m3u8', label: 'Stream');
    expect(src.tierBadge, isNull);
    expect(src.pickerTitle, 'Stream');
    expect(src.pickerSubtitle, isNull);
  });
}
