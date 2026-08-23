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

    test('echo uses streamed.pk catalog referer', () {
      final h = LiveGoatUnlock.playbackHeadersForSlot({
        'origin': 'https://embed.st',
        'source': 'echo',
        'path': 'echo/match-id/1',
      });
      expect(h['Referer'], 'https://streamed.pk/');
      expect(h['Origin'], 'https://streamed.pk');
    });
  });

  group('LiveGoatUnlock.sportsEmbed', () {
    test('delta sportsembed maps to embed.st slot', () {
      final mapped = LiveGoatUnlock.embedStUrlFromSportsEmbed(
        'https://sportsembed.su/embed/761748/live_mls_austin-philadelphia-live-streaming-538781760/delta/1',
      );
      expect(
        mapped,
        'https://embed.st/embed/delta/live_mls_austin-philadelphia-live-streaming-538781760/1',
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

    test('admin rtmp master stays on hls-proxy', () {
      expect(
        LiveGoatUnlock.preferDirectEnginePlayback(
          'https://lb1.strmd.st/secure/tok/rtmp/stream/id/1/playlist.m3u8',
        ),
        isFalse,
      );
    });
  });
}
