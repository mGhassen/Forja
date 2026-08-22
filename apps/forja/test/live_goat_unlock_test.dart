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
