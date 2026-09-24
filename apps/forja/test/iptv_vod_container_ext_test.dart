import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart'
    show PortalLiveSourceKind;
import 'package:forja/shared/player/sources/resolve/pack_stream_play_hooks.dart';
import 'package:forja_foundation/protocol/protocol.dart';

void main() {
  group('MetaVideo.containerExt', () {
    test('parses top-level containerExt from pack details videos', () {
      final v = MetaVideo.fromJson({
        'id': '392967',
        'title': 'E1',
        'season': 1,
        'episode': 1,
        'containerExt': 'mkv',
      });
      expect(v.containerExt, 'mkv');
    });

    test('parses open.containerExt when top-level missing', () {
      final v = MetaVideo.fromJson({
        'id': '392967',
        'title': 'E1',
        'season': 1,
        'episode': 1,
        'open': {
          'surface': 'iptv',
          'containerExt': 'mkv',
        },
      });
      expect(v.containerExt, 'mkv');
    });

    test('round-trips containerExt through MetaItem JSON', () {
      final item = MetaItem.fromJson({
        'id': 'iptv:series:x:1',
        'type': 'tv',
        'name': 'Show',
        'open': {
          'surface': 'iptv',
          'kind': 'series',
          'containerExt': 'mp4',
        },
        'videos': [
          {
            'id': '392967',
            'title': 'E1',
            'season': 1,
            'episode': 1,
            'containerExt': 'mkv',
          },
        ],
      });
      expect(item.videos.single.containerExt, 'mkv');
      final again = MetaItem.fromJson(item.toJson());
      expect(again.videos.single.containerExt, 'mkv');
    });
  });

  group('PackStreamPlayHooks.playContainerExt', () {
    test('episode ext wins over series poster default mp4', () {
      expect(
        PackStreamPlayHooks.playContainerExt(
          episodeExt: 'mkv',
          seriesExt: 'mp4',
        ),
        'mkv',
      );
    });

    test('falls back to series then mp4', () {
      expect(
        PackStreamPlayHooks.playContainerExt(seriesExt: 'ts'),
        'ts',
      );
      expect(PackStreamPlayHooks.playContainerExt(), 'mp4');
    });
  });

  group('PackStreamPlayHooks.portalLiveSourceKind', () {
    test('portal Movies/Series are never Stremio', () {
      expect(
        PackStreamPlayHooks.portalLiveSourceKind('xtream'),
        PortalLiveSourceKind.iptvXtream,
      );
      expect(
        PackStreamPlayHooks.portalLiveSourceKind('stalker'),
        PortalLiveSourceKind.iptvStalker,
      );
      expect(
        PackStreamPlayHooks.portalLiveSourceKind(null),
        PortalLiveSourceKind.iptvXtream,
      );
    });
  });
}
