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

  test('iptvLiveEnginePlayUrlReady distinguishes embed vs handoff', () {
    expect(
      iptvLiveEnginePlayUrlReady('https://streamed.pk/embed/abc'),
      isFalse,
    );
    expect(
      iptvLiveEnginePlayUrlReady('https://cdn.example/live/index.m3u8'),
      isTrue,
    );
    expect(
      iptvLiveEnginePlayUrlReady('http://127.0.0.1:1234/hls-proxy?url=x'),
      isTrue,
    );
  });

  test('iptvLiveSourceProbeUrl skips embed catalog pages', () {
    const embed = IptvPlaySource(
      url: 'https://streamed.pk/embed/abc',
      label: 'English',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineEmbedUrl: 'https://streamed.pk/embed/abc',
    );
    expect(iptvLiveSourceProbeUrl(embed), isNull);
    expect(iptvLiveSourceProbeSkipped(embed), isTrue);

    const handoff = IptvPlaySource(
      url: 'https://cdn.example/live/index.m3u8',
      label: 'English',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineEmbedUrl: 'https://streamed.pk/embed/abc',
    );
    expect(
      iptvLiveSourceProbeUrl(handoff),
      'https://cdn.example/live/index.m3u8',
    );

    const signed = IptvPlaySource(
      url:
          'https://lb5.wfty.st/secure/tok/delta/live_foo/1/465/playlist.m3u8',
      label: 'WatchFooty delta',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      liveEngineEmbedUrl:
          'https://lb5.wfty.st/secure/tok/delta/live_foo/1/465/playlist.m3u8',
    );
    expect(iptvLiveSourceProbeUrl(signed), isNull);
    expect(iptvLiveSourceProbeSkipped(signed), isTrue);

    // Providers tiles clear liveEngineEmbedUrl on directPlayback.
    const streamedDirect = IptvPlaySource(
      url:
          'https://lb12.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
      label: 'HD Admin',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      headers: {'Referer': 'https://embed.st/'},
    );
    expect(iptvLiveSourceProbeUrl(streamedDirect), isNull);
    expect(iptvLiveSourceProbeSkipped(streamedDirect), isTrue);

    const watchfootyDirect = IptvPlaySource(
      url:
          'https://lb5.wfty.st/secure/tok/sigma/live_foo/1/465/playlist.m3u8',
      label: 'WatchFooty sigma',
      liveSourceKind: IptvLiveSourceKind.liveEngine,
      headers: {'Referer': 'https://sportsembed.su/'},
    );
    expect(iptvLiveSourceProbeUrl(watchfootyDirect), isNull);
    expect(iptvLiveSourceProbeSkipped(watchfootyDirect), isTrue);

    const stremioFlixnest = IptvPlaySource(
      url:
          'https://free.flixnest.app/dlstreams/stream/dlstreams%3Achannel%3A365.m3u8?t=eyJhbGciOiJIUzI1NiJ9.sig',
      label: 'DL Streams',
      liveSourceKind: IptvLiveSourceKind.stremio,
    );
    expect(iptvLiveSourceProbeUrl(stremioFlixnest), isNull);
    expect(iptvLiveSourceProbeSkipped(stremioFlixnest), isTrue);

    const portal = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'Golf',
      liveSourceKind: IptvLiveSourceKind.iptvXtream,
    );
    expect(iptvLiveSourceProbeUrl(portal), isNull);
    expect(iptvLiveSourceProbeSkipped(portal), isTrue);

    const legacy = IptvPlaySource(
      url: 'http://portal.example/live/u/p/1.m3u8',
      label: 'Golf',
    );
    expect(
      iptvLiveSourceProbeUrl(legacy),
      'http://portal.example/live/u/p/1.m3u8',
    );
  });
}
