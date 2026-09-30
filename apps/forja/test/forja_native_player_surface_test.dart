import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/player/live/hooks/live_play.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart'
    show PortalLiveSourceKind;
import 'package:rust/rust.dart' show BuiltInPlayerContext;

void main() {
  test('xtream and stalker open the IPTV player even when context defaults to live', () {
    for (final kind in [
      PortalLiveSourceKind.iptvXtream,
      PortalLiveSourceKind.iptvStalker,
    ]) {
      expect(
        forjaNativePlayerIsSports(
          vodPlayback: false,
          engineContext: BuiltInPlayerContext.live,
          kind: kind,
        ),
        isFalse,
      );
      expect(
        forjaNativePlayerContext(
          vodPlayback: false,
          engineContext: BuiltInPlayerContext.live,
          kind: kind,
        ),
        BuiltInPlayerContext.iptv,
      );
    }
  });

  test('stremio and live-engine stay on the Live Sports player', () {
    for (final kind in [
      PortalLiveSourceKind.stremio,
      PortalLiveSourceKind.liveEngine,
    ]) {
      expect(
        forjaNativePlayerIsSports(
          vodPlayback: false,
          engineContext: BuiltInPlayerContext.live,
          kind: kind,
        ),
        isTrue,
      );
    }
  });

  test('portal movies stay on the VOD context', () {
    expect(
      forjaNativePlayerIsSports(
        vodPlayback: true,
        engineContext: BuiltInPlayerContext.vod,
        kind: PortalLiveSourceKind.iptvXtream,
      ),
      isFalse,
    );
    expect(
      forjaNativePlayerContext(
        vodPlayback: true,
        engineContext: BuiltInPlayerContext.vod,
        kind: PortalLiveSourceKind.iptvXtream,
      ),
      BuiltInPlayerContext.vod,
    );
  });
}
