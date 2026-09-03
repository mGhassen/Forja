import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';

void main() {
  group('LiveGoatUnlock.playbackHeadersForSlot', () {
    test('admin keeps embed origin root', () {
      final h = LiveGoatUnlock.playbackHeadersForSlot({
        'origin': 'https://embed.st',
        'source': 'admin',
        'path': 'admin/ppv-a-vs-b/1',
      });
      expect(h['Referer'], 'https://embed.st/');
      expect(h['Origin'], 'https://embed.st');
    });

    test('delta uses embed page referer', () {
      final h = LiveGoatUnlock.playbackHeadersForSlot({
        'origin': 'https://embed.st',
        'source': 'delta',
        'path': 'delta/live_mlb_foo/1',
      });
      expect(
        h['Referer'],
        'https://embed.st/embed/delta/live_mlb_foo/1',
      );
      expect(h['Origin'], 'https://embed.st');
    });

    test('echo uses embed page referer like delta', () {
      final h = LiveGoatUnlock.playbackHeadersForSlot({
        'origin': 'https://embed.st',
        'source': 'echo',
        'path': 'echo/match-id/1',
      });
      expect(h['Referer'], 'https://embed.st/embed/echo/match-id/1');
      expect(h['Origin'], 'https://embed.st');
    });
  });

  group('LiveGoatUnlock.sportsEmbed', () {
    test('sports embed playback uses player page referer', () {
      final headers = LiveGoatUnlock.playbackHeadersForSportsEmbed({
        'origin': 'https://sportsembed.su',
        'path': '401816669/atlanta-braves-los-angeles-dodgers/regular/2',
      });
      expect(
        headers['Referer'],
        'https://sportsembed.su/embed/401816669/atlanta-braves-los-angeles-dodgers/regular/2',
      );
      expect(headers['Origin'], 'https://sportsembed.su');
    });

    test('wfty playlist reconstructs sportsembed player referer', () {
      expect(
        LiveGoatUnlock.sportsEmbedRefererFromWftyPlaylist(
          'https://lb6.wfty.st/secure/tok/sigma/slask-wroclaw-pogon/2/4805436/1788483833/playlist.m3u8',
        ),
        'https://sportsembed.su/embed/4805436/slask-wroclaw-pogon/sigma/2',
      );
      expect(
        LiveGoatUnlock.withWftyPlaybackReferer(
          'https://lb6.wfty.st/secure/tok/sigma/slask-wroclaw-pogon/2/4805436/1788483833/playlist.m3u8',
          {'Referer': 'https://sportsembed.su/', 'User-Agent': 'x'},
        )['Referer'],
        'https://sportsembed.su/embed/4805436/slask-wroclaw-pogon/sigma/2',
      );
    });

    test('delta sportsembed maps to embed.st slot', () {
      final mapped = LiveGoatUnlock.embedStUrlFromSportsEmbed(
        'https://sportsembed.su/embed/761748/live_mls_austin-philadelphia-live-streaming-538781760/delta/1',
      );
      expect(
        mapped,
        'https://embed.st/embed/delta/live_mls_austin-philadelphia-live-streaming-538781760/1',
      );
    });

    test('sigma sportsembed does not map to embed.st GOAT', () {
      // WatchFooty often ships sigma/pro rows — GOAT-only unlock leaves streams=0.
      expect(
        LiveGoatUnlock.embedStUrlFromSportsEmbed(
          'https://sportsembed.su/embed/401900374/al-fayha-al-kholood/sigma/1',
        ),
        isNull,
      );
      expect(
        LiveGoatUnlock.embedStAdminCandidatesFromSportsEmbed(
          'https://sportsembed.su/embed/401900374/al-fayha-al-kholood/sigma/1',
        ),
        isEmpty,
      );
    });

    test('hd sportsembed builds admin ppv candidates', () {
      final candidates = LiveGoatUnlock.embedStAdminCandidatesFromSportsEmbed(
        'https://sportsembed.su/embed/761748/austin-fc-philadelphia-union/hd/1',
      ).toList();
      expect(
        candidates,
        contains(
          'https://embed.st/embed/admin/ppv-austin-fc-vs-philadelphia-union/1',
        ),
      );
    });

    test('isSportsEmbedUrl recognizes sportsembed host', () {
      expect(
        LiveGoatUnlock.isSportsEmbedUrl(
          'https://sportsembed.su/embed/1/foo/delta/1',
        ),
        isTrue,
      );
      expect(
        LiveGoatUnlock.isSportsEmbedUrl('https://embed.st/embed/delta/x/1'),
        isFalse,
      );
    });

    test('parseSportsEmbedSlot reads match/slug/category/stream', () {
      final slot = LiveGoatUnlock.parseSportsEmbedSlot(
        'https://sportsembed.su/embed/401816669/atlanta-braves-los-angeles-dodgers/regular/2',
      );
      expect(slot, isNotNull);
      expect(slot!['matchId'], '401816669');
      expect(slot['slug'], 'atlanta-braves-los-angeles-dodgers');
      expect(slot['category'], 'regular');
      expect(slot['stream'], '2');
      expect(
        slot['path'],
        '401816669/atlanta-braves-los-angeles-dodgers/regular/2',
      );
      expect(slot['origin'], 'https://sportsembed.su');
    });

    test('parseSportsEmbedSlot rejects non-sportsembed', () {
      expect(
        LiveGoatUnlock.parseSportsEmbedSlot(
          'https://embed.st/embed/delta/foo/1',
        ),
        isNull,
      );
    });
  });

  group('LiveGoatUnlock.preferDirectEnginePlayback', () {
    test('delta and echo media playlists open direct', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb1.strmd.st/secure/tok/delta/stream/foo/1/playlist.m3u8',
        ),
        isTrue,
      );
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb1.strmd.st/secure/tok/echo/stream/bar/1/playlist.m3u8',
        ),
        isTrue,
      );
    });

    test('watchfooty wfty.st playlists use hls-proxy', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb5.wfty.st/secure/tok/delta/live_foo/1/465/playlist.m3u8',
        ),
        isFalse,
      );
    });

    test('ppv indianservers playlists open direct', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb3.indianservers.st/secure/tok/fiba-africa/index.m3u8',
        ),
        isTrue,
      );
    });

    test('streamfree strmd and streamfree.top live open direct', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb14.strmd.st/secure/tok/streamfree/stream/foo/1/playlist.m3u8',
        ),
        isTrue,
      );
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://streamfree.top/live/match1080p/index.m3u8?_e=1&_n=x&_t=y',
        ),
        isTrue,
      );
    });

    test('admin rtmp master stays on hls-proxy', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb1.strmd.st/secure/tok/rtmp/stream/id/1/playlist.m3u8',
        ),
        isFalse,
      );
    });
  });

  group('LiveGoatUnlock.isEmbedIndiaUrl', () {
    test('recognizes embedindia host', () {
      expect(
        LiveGoatUnlock.isEmbedIndiaUrl(
          'https://embedindia.st/embed/mlb/2025-08-23/foo?gid=9',
        ),
        isTrue,
      );
      expect(
        LiveGoatUnlock.isEmbedIndiaUrl('https://embed.st/embed/admin/x/1'),
        isFalse,
      );
    });

    test('epiembeds is not embedindia (PPV must not sniff)', () {
      const epi = 'https://epiembeds.online/embed/foo';
      expect(LiveGoatUnlock.isEpiEmbedsUrl(epi), isTrue);
      expect(LiveGoatUnlock.isEmbedIndiaUrl(epi), isFalse);
    });
  });

  group('LiveGoatUnlock.playbackHeadersForEmbedIndia', () {
    test('strips gid from Referer (CDN 403s with query)', () {
      final slot = LiveGoatUnlock.parseEmbedIndiaSlot(
        'https://embedindia.st/embed/nfl/2025-08-23/chiefs-vs-bills?gid=42',
      )!;
      final h = LiveGoatUnlock.playbackHeadersForEmbedIndia(
        slot,
        embedUrl:
            'https://embedindia.st/embed/nfl/2025-08-23/chiefs-vs-bills?gid=42',
      );
      expect(
        h['Referer'],
        'https://embedindia.st/embed/nfl/2025-08-23/chiefs-vs-bills',
      );
      expect(h['Origin'], 'https://embedindia.st');
    });

    test('path-only when embedUrl omitted', () {
      final slot = LiveGoatUnlock.parseEmbedIndiaSlot(
        'https://embedindia.st/embed/mlb/2025-08-23/foo?gid=9',
      )!;
      final h = LiveGoatUnlock.playbackHeadersForEmbedIndia(slot);
      expect(h['Referer'], 'https://embedindia.st/embed/mlb/2025-08-23/foo');
    });
  });

  group('LiveGoatUnlock.parseEmbedIndiaSlot', () {
    test('parses league/date/slug/gid path', () {
      final slot = LiveGoatUnlock.parseEmbedIndiaSlot(
        'https://embedindia.st/embed/nfl/2025-08-23/chiefs-vs-bills?gid=42',
      );
      expect(slot, isNotNull);
      expect(slot!['league'], 'nfl');
      expect(slot['date'], '2025-08-23');
      expect(slot['slug'], 'chiefs-vs-bills');
      expect(slot['gid'], '42');
      expect(slot['path'], 'nfl/2025-08-23/chiefs-vs-bills');
      expect(slot['origin'], 'https://embedindia.st');
    });

    test('rejects embed.st slots', () {
      expect(
        LiveGoatUnlock.parseEmbedIndiaSlot(
          'https://embed.st/embed/admin/ppv-a-vs-b/1',
        ),
        isNull,
      );
    });

    test('rejects embed-noads short paths', () {
      expect(
        LiveGoatUnlock.parseEmbedIndiaSlot(
          'https://embedindia.st/embed-noads/rally-tv',
        ),
        isNull,
      );
    });

    test('parses event slug-only embed paths', () {
      final slot = LiveGoatUnlock.parseEmbedIndiaSlot(
        'https://embedindia.st/embed/ufc-fight-night-hernandez-vs-rodrigues',
      );
      expect(slot, isNotNull);
      expect(slot!['path'], 'ufc-fight-night-hernandez-vs-rodrigues');
      expect(slot['slug'], 'ufc-fight-night-hernandez-vs-rodrigues');
      expect(slot['league'], '');
      expect(slot['date'], '');
    });

    test('parses event slug/variant embed paths', () {
      final slot = LiveGoatUnlock.parseEmbedIndiaSlot(
        'https://embedindia.st/embed/ufc-fight-night-hernandez-vs-rodrigues/paramount-es',
      );
      expect(slot, isNotNull);
      expect(
        slot!['path'],
        'ufc-fight-night-hernandez-vs-rodrigues/paramount-es',
      );
      expect(slot['slug'], 'paramount-es');
    });
  });
}
