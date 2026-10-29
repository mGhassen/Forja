import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/player_phone_tokens.dart';

/// Phone player system chrome.
///
/// While a phone player is mounted it owns landscape + immersive. When the
/// last one leaves, the app gets portrait and the normal edge-to-edge system
/// bars back (status bar visible), then the portrait lock is released so the
/// app follows the system rotation setting again.
///
/// Episode hand-off (`pushReplacement`) mounts the next player before the old
/// one disposes, so the live count never hits zero and nothing flickers.
abstract final class PhonePlayerSystemUi {
  static int _live = 0;
  static int _gen = 0;

  static bool get playerAlive => _live > 0;

  /// Call from the phone player's `initState`.
  static void attach() {
    _live++;
    _gen++;
  }

  /// Call from the phone player's `dispose`. When [restore] is true (the
  /// player left without [restoreForExit], e.g. a forced pop) and no other
  /// phone player is mounted, restore after the route teardown frame.
  static void detach({required bool restore}) {
    if (_live > 0) _live--;
    if (!restore) return;
    final gen = ++_gen;
    // Orientation changes during media surface teardown cause buffer-queue
    // errors — wait one settle period first.
    unawaited(
      Future<void>.delayed(PlayerPhoneTokens.exitRotationSettle, () async {
        if (gen != _gen || playerAlive) return;
        await restoreForExit();
        scheduleOrientationRelease();
      }),
    );
  }

  /// Exit path, before popping the player route: portrait, settle, then the
  /// edge-to-edge system bars.
  static Future<void> restoreForExit() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await Future<void>.delayed(PlayerPhoneTokens.exitRotationSettle);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// After the pop: drop the portrait lock unless another player took over.
  static void scheduleOrientationRelease() {
    final gen = _gen;
    unawaited(
      Future<void>.delayed(PlayerPhoneTokens.exitOrientationRelease, () async {
        if (gen != _gen || playerAlive) return;
        await SystemChrome.setPreferredOrientations(const []);
      }),
    );
  }

  @visibleForTesting
  static void debugReset() {
    _live = 0;
    _gen = 0;
  }
}
