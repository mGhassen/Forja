import 'dart:async';
import 'dart:io';

import 'package:forja/shared/audio/audiobook_player_service.dart';
import 'package:forja/shared/audio/music_player_service.dart';

/// macOS bundles libmpv as [Mpv.framework] with ObjC classes (Application,
/// MpvVideoView, …). A second [Player] dlopens the same framework again and
/// trips duplicate-class warnings, then aborts in m_config_cache_from_shadow.
///
/// Only one media_kit [Player] may be alive at a time on macOS.
class MpvExclusiveSession {
  MpvExclusiveSession._();
  static final MpvExclusiveSession instance = MpvExclusiveSession._();

  static bool get required => Platform.isMacOS;

  Future<void>? _pendingVideoDispose;

  /// Release background audio players and wait for any in-flight video dispose.
  Future<void> prepareForVideoPlayer() async {
    if (!required) return;
    await _pendingVideoDispose;
    await MusicPlayerService().releaseMpvForVideo();
    await AudiobookPlayerService().releaseMpvForVideo();
  }

  void trackVideoDispose(Future<void> disposeFuture) {
    if (!required) return;
    _pendingVideoDispose = disposeFuture;
    unawaited(disposeFuture.whenComplete(() {
      if (identical(_pendingVideoDispose, disposeFuture)) {
        _pendingVideoDispose = null;
      }
    }));
  }
}
