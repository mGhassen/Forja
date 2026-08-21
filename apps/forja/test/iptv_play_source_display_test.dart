import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';

void main() {
  test('EPG dump uses callsign after last space-colon', () {
    const src = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'T3 · Raiders vs. Texans @ Aug 20 20:00 :TSN+ 55',
      detail: 'Canada · Fubo Sports',
      logoUrl: 'http://portal.example/logo.png',
    );
    expect(src.tierBadge, 'T3');
    expect(src.pickerTitle, 'TSN+ 55');
    expect(src.pickerSubtitle, 'Canada · Fubo Sports');
  });

  test('does not split on HH:MM time colons', () {
    const src = IptvPlaySource(
      url: 'http://x/1.m3u8',
      label: 'T4 · Game @ Aug 20 12:00 PM :Fubo Canada',
      detail: 'Canada · Fubo Sports',
    );
    expect(src.pickerTitle, 'Fubo Canada');
  });

  test('Group: Channel style still works', () {
    const src = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'T4 · NFL Teams: FOX Raiders (KVVU) Las Vegas NV',
      detail: 'USA | NFL Teams',
      logoUrl: 'http://portal.example/logo.png',
    );
    expect(src.tierBadge, 'T4');
    expect(src.pickerTitle, 'FOX Raiders (KVVU) Las Vegas NV');
    expect(src.pickerSubtitle, 'USA · NFL Teams');
  });

  test('plain labels stay intact', () {
    const src = IptvPlaySource(url: 'http://x/a.m3u8', label: 'Stream');
    expect(src.tierBadge, isNull);
    expect(src.pickerTitle, 'Stream');
    expect(src.pickerSubtitle, isNull);
  });
}
