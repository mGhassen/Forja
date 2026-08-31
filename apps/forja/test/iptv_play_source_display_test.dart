import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';

void main() {
  test('keeps full Xtream channel name (no callsign rewrite)', () {
    const src = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'T3 · Raiders vs. Texans @ Aug 20 20:00 :TSN+ 55',
      detail: 'Canada · Fubo Sports',
      logoUrl: 'http://portal.example/logo.png',
    );
    expect(src.tierBadge, 'T3');
    expect(src.tierBadgeColor, const Color(0xFFEAB308));
    expect(
      src.pickerTitle,
      'Raiders vs. Texans @ Aug 20 20:00 :TSN+ 55',
    );
    expect(src.pickerSubtitle, 'Canada · Fubo Sports');
  });

  test('strips only the tier prefix', () {
    const src = IptvPlaySource(
      url: 'http://x/1.m3u8',
      label: 'T4 · NFL Teams: FOX Raiders (KVVU) Las Vegas NV',
      detail: 'USA | NFL Teams',
    );
    expect(src.tierBadge, 'T4');
    expect(
      src.pickerTitle,
      'NFL Teams: FOX Raiders (KVVU) Las Vegas NV',
    );
    expect(src.pickerSubtitle, 'USA · NFL Teams');
  });

  test('plain labels stay intact', () {
    const src = IptvPlaySource(url: 'http://x/a.m3u8', label: 'Stream');
    expect(src.tierBadge, isNull);
    expect(src.pickerTitle, 'Stream');
    expect(src.pickerSubtitle, isNull);
  });
}
