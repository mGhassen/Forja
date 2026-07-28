import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:forja/shared/audio/audiobook_player_service.dart';
import 'package:forja/shared/audio/music_player_service.dart';
import 'package:forja/shared/player/player/utils.dart';

/// macOS bundles libmpv as [Mpv.framework] with ObjC classes (Application,
/// MpvVideoView, …). A second [Player] dlopens the same framework again and
/// trips duplicate-class warnings, then aborts in m_config_cache_from_shadow.
///
/// Only one media_kit [Player] may be alive at a time on macOS.
class MpvExclusiveSession {
  MpvExclusiveSession._();
  static final MpvExclusiveSession instance = MpvExclusiveSession._();

  static bool get required => Platform.isMacOS;

  final Set<Player> _trackedPlayers = <Player>{};
  Future<void>? _pendingVideoDispose;

  /// Register a live [Player] so app shutdown can stop mpv before Dart teardown.
  Player trackPlayer(Player player) {
    _trackedPlayers.add(player);
    return player;
  }

  void untrackPlayer(Player player) {
    _trackedPlayers.remove(player);
  }

  /// Wait for any in-flight video dispose, then release background audio
  /// players on macOS (exclusive [Player]).
  ///
  /// Pending dispose is tracked on **all** platforms: Android timed teardown
  /// (issue 128) can leave mpv half-alive; opening a new IPTV/Live MediaKit
  /// [Player] before that finishes yields black screen / format errors.
  Future<void> prepareForVideoPlayer() async {
    try {
      await _pendingVideoDispose?.timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (!required) return;
    await MusicPlayerService().releaseMpvForVideo();
    await AudiobookPlayerService().releaseMpvForVideo();
  }

  void trackVideoDispose(Future<void> disposeFuture) {
    _pendingVideoDispose = disposeFuture;
    unawaited(disposeFuture.whenComplete(() {
      if (identical(_pendingVideoDispose, disposeFuture)) {
        _pendingVideoDispose = null;
      }
    }));
  }

  /// Stop every tracked mpv instance before the VM shuts down.
  ///
  /// Uses timed teardown - unbounded [Player.stop]/[Player.dispose] hangs
  /// (stuck video-controller init) and freezes desktop quit while
  /// `setPreventClose(true)` keeps the window alive.
  ///
  /// mpv core threads can still fire FFI property callbacks after
  /// [Player.dispose] returns; without a grace period the Dart runtime hits
  /// "GetFfiCallbackMetadata called after shutdown".
  Future<void> shutdownAllPlayers() async {
    try {
      await _pendingVideoDispose?.timeout(const Duration(seconds: 2));
    } catch (_) {}
    _pendingVideoDispose = null;

    final players = _trackedPlayers.toList();
    _trackedPlayers.clear();

    for (final player in players) {
      try {
        await teardownMediaKitPlayer(player);
      } catch (_) {}
    }

    if (players.isNotEmpty) {
      // macOS: demux / msg_wakeup can still run briefly after dispose returns.
      await Future.delayed(
        Duration(milliseconds: required ? 400 : 200),
      );
    }
  }
}
