import 'package:flutter/widgets.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';

/// Host for in-Forja mini player (not OS/window [PipService] PiP).
///
/// Escape (when setting on) demotes the full player to a corner widget inside
/// the Forja window. Playback keeps running on enter; expand restores full
/// chrome and [ShellBus.enterPlayerSurface].
class InAppMiniPlayerController {
  InAppMiniPlayerController._();

  static final InAppMiniPlayerController instance =
      InAppMiniPlayerController._();

  static const Size defaultSize = Size(320, 180);
  static const double aspectRatio = 16 / 9;
  static const double minWidth = 240;
  static const double maxWidth = 720;

  /// True while a VOD or IPTV player is demoted to the in-app corner.
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Corner size (16:9). Drag the top-left grip to resize.
  final ValueNotifier<Size> size = ValueNotifier<Size>(defaultSize);

  /// Session callbacks bound by the living player screen.
  InAppMiniPlayerSession? _session;

  /// Resume full playback on expand unless the user paused while mini.
  bool _resumeOnExpand = true;

  bool get isActive => active.value;

  InAppMiniPlayerSession? get session => _session;

  /// Whether Settings → Playback → In-app mini player is enabled (default off).
  static bool get settingEnabled =>
      SettingsService.inAppMiniPlayerNotifier.value;

  static Future<bool> readSettingEnabled() =>
      SettingsService().getInAppMiniPlayer();

  /// Bind the living player. Call from player init / ready; clear on dispose.
  void attach(InAppMiniPlayerSession session) {
    _session = session;
  }

  void detach(InAppMiniPlayerSession session) {
    if (identical(_session, session)) {
      if (active.value) {
        active.value = false;
        ShellTvFocus.unregisterMini();
      }
      _session = null;
    }
  }

  /// Clamp width and lock 16:9.
  void setSizeWidth(double width) {
    final w = width.clamp(minWidth, maxWidth);
    size.value = Size(w, w / aspectRatio);
  }

  /// Demote without pausing. Caller must already be the full player and setting on.
  Future<void> enter() async {
    final session = _session;
    if (session == null || active.value) return;

    _resumeOnExpand = session.isPlaying;
    // Keep decode running — user pauses from mini chrome if wanted.
    if (!identical(_session, session)) return;

    active.value = true;
    ShellBus.leavePlayerSurface();
    ShellBus.clearMaskShellUnderPlayer();
    ShellTvFocus.registerMini(session.miniRootFocus);
    session.onEnteredMini();
  }

  /// Restore full player chrome + shell freeze.
  Future<void> expand() async {
    final session = _session;
    if (session == null || !active.value) return;

    active.value = false;
    ShellTvFocus.unregisterMini();
    ShellBus.enterPlayerSurface();
    session.onExpandedFromMini();
    if (_resumeOnExpand) {
      await session.playFromMini();
    }
  }

  Future<void> play() async {
    _resumeOnExpand = true;
    await _session?.playFromMini();
  }

  Future<void> pause() async {
    _resumeOnExpand = false;
    await _session?.pauseForMini();
  }

  Future<void> togglePlayPause() async {
    final session = _session;
    if (session == null) return;
    if (session.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stop playback and pop the player route.
  Future<void> close() async {
    final session = _session;
    if (session == null) return;
    if (active.value) {
      active.value = false;
      ShellTvFocus.unregisterMini();
      // Surface already left on enter; keep depth consistent if somehow still in.
    }
    await session.closeFromMini();
  }

  /// Tear down mini (or full) session before opening another title.
  Future<void> stopForNewPlay() async {
    final session = _session;
    if (session == null) return;
    if (active.value) {
      active.value = false;
      ShellTvFocus.unregisterMini();
    }
    await session.stopForNewPlay();
  }

  /// Leave mini focus and restore the chrome door that jumped in.
  void restoreChromeFocus() {
    ShellTvFocus.restoreFromMini();
  }

  bool focusMini() => ShellTvFocus.focusMini();
}

/// Bound by [DesktopPlayerScreen] / IPTV player while mounted.
abstract class InAppMiniPlayerSession {
  FocusNode get miniRootFocus;
  bool get isPlaying;
  Future<void> pauseForMini();
  Future<void> playFromMini();
  void onEnteredMini();
  void onExpandedFromMini();
  Future<void> closeFromMini();
  Future<void> stopForNewPlay();
}
