import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/live/live_goat_unlock.dart';

void main() {
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

  group('LiveGoatUnlock sniff host gates', () {
    test('isEmbedIndiaUrl recognizes embedindia host', () {
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

    test('epiembeds is distinct from embedindia', () {
      const epi = 'https://epiembeds.online/embed/foo';
      expect(LiveGoatUnlock.isEpiEmbedsUrl(epi), isTrue);
      expect(LiveGoatUnlock.isEmbedIndiaUrl(epi), isFalse);
    });
  });
}
