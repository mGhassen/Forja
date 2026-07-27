import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/app/boot_catalog.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/profile_engine_warm.dart';
import 'package:forja/features/account/profile_chooser_metrics.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:rust/rust.dart';

/// Profile-switch splash: avatar flies from its Who's watching tile to center
/// while scaling up. Boot work matches [SplashScreen] intro: warm under the
/// motion floor, dismiss when the floor elapses even if catalog is still
/// loading, torrent starts after dismiss.
class ProfileSwitchSplash extends StatefulWidget {
  const ProfileSwitchSplash({
    super.key,
    required this.profile,
    this.originRect,
    this.prepareCurrent = true,
  });

  final SyncProfile profile;

  /// Bounds of the tapped avatar in the navigator overlay's local coords.
  final Rect? originRect;

  /// When true (mid-session switch), push the current profile before loading.
  final bool prepareCurrent;

  @override
  State<ProfileSwitchSplash> createState() => _ProfileSwitchSplashState();
}

class _ProfileSwitchSplashState extends State<ProfileSwitchSplash>
    with SingleTickerProviderStateMixin {
  /// Same role as intro [_SplashScreenState._minSplashDuration]: motion floor
  /// and hard cap — dismiss even if warm/TMDB is still running.
  static const Duration _splashDuration = Duration(seconds: 5);

  late final AnimationController _motionController;
  late final Animation<double> _motion;
  late final Animation<double> _copyOpacity;

  late final DateTime _startedAt;
  String _status = 'Loading profile…';
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _motionController = AnimationController(
      vsync: this,
      duration: _splashDuration,
    );
    _motion = CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInOutCubic,
    );
    _copyOpacity = CurvedAnimation(
      parent: _motionController,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );
    _motionController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  /// Mid-session switch: leave the previous screen and open this profile's
  /// saved default tab once navbar config reloads.
  void _prepareShellForIncomingProfile() {
    popShellOverlayUntilRoot();
    ShellBus.clearHideGlobalNav();
    ShellBus.selectDefaultTabOnNextNavLoad = true;
    // Merge may no-op when navigation payloads match; force a shell reload.
    SettingsService.navbarChangeNotifier.value++;
  }

  Future<void> _run() async {
    try {
      if (widget.prepareCurrent) {
        _setStatus('Saving current profile…');
        await SyncDomainBridge.instance.prepareProfileSwitch();
      }
      _setStatus('Loading ${widget.profile.name}…');
      final selected = await SyncService.instance.selectProfile(
        widget.profile.id,
      );
      if (!selected) {
        throw StateError('Profile unavailable');
      }
      _setStatus('Syncing settings…');
      await SyncDomainBridge.instance.pullAndMergeAll();
      if (!mounted) return;

      BootCache.clear();
      final needs = await BootNeeds.resolve();

      // Same as intro splash: warm under the floor; torrent after dismiss.
      final bootFuture = _warmLikeIntro(needs);
      if (widget.prepareCurrent) {
        _prepareShellForIncomingProfile();
      }
      await _dismissWhenReady(bootFuture, needs);
    } catch (_) {
      if (!mounted || _finished) return;
      await _waitOutSplash();
      _finish(false);
    }
  }

  /// Intro-equivalent warm: LocalServer/WebStreamr/Nuvio + TMDB; no torrent.
  Future<void> _warmLikeIntro(BootNeeds needs) async {
    await ProfileEngineWarm.warm(
      needs,
      startTorrent: false,
      reason: 'profile-splash',
      onStatus: _setStatus,
    );
    if (!mounted) return;
    if (needs.tmdb) {
      _setStatus('Loading your home feed…');
      await BootCatalog.prefetchTmdb(onStatus: _setStatus);
    }
  }

  /// Mirror [SplashScreen._dismissWhenReady]: dismiss at the motion floor even
  /// when warm/TMDB is still running; keep that future alive in the background.
  Future<void> _dismissWhenReady(Future<void> bootFuture, BootNeeds needs) async {
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = elapsed >= _splashDuration
        ? Duration.zero
        : _splashDuration - elapsed;
    final minSplashFuture = Future<void>.delayed(remaining);

    final bootFinishedFirst = await Future.any<bool>([
      bootFuture.then((_) => true),
      minSplashFuture.then((_) => false),
    ]);

    if (!mounted || _finished) return;

    if (bootFinishedFirst) {
      await minSplashFuture;
      if (!mounted || _finished) return;
      _finish(true);
      unawaited(_startTorrentPostSplash(needs));
      return;
    }

    debugPrint(
      '[ProfileSplash] Motion floor elapsed — dismissing; warm continues '
      'in background',
    );
    // Keep boot alive after this State may dispose.
    unawaited(
      bootFuture.then((_) {
        debugPrint('[ProfileSplash] Background warm complete');
      }).catchError((Object e) {
        debugPrint('[ProfileSplash] Background warm error: $e');
      }),
    );
    _finish(true);
    unawaited(_startTorrentPostSplash(needs));
  }

  Future<void> _startTorrentPostSplash(BootNeeds needs) async {
    if (!needs.torrent) return;
    if (!PlatformPlayback.capabilities.localTorrentEngine) return;
    debugPrint('[Init] TorrentStream start (post-profile-splash)');
    final ok = await TorrentStreamService()
        .start()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[Init] TorrentStream timed out after 10s');
            return false;
          },
        )
        .catchError((Object e, StackTrace st) {
          debugPrint('[Init] TorrentStream error: $e');
          debugPrint('[Init] Stack trace: $st');
          return false;
        });
    debugPrint('[Init] TorrentStream ${ok ? "ready" : "failed"}');
  }

  void _finish(bool ok) {
    if (!mounted || _finished) return;
    _finished = true;
    Navigator.of(context).pop(ok);
  }

  /// Keep the splash on screen for the full motion even if sync fails early.
  Future<void> _waitOutSplash() async {
    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed < _splashDuration) {
      await Future<void>.delayed(_splashDuration - elapsed);
    }
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status.trim();
    final metrics = ProfileChooserMetrics.of(context);
    return ColoredBox(
      color: AppTheme.bgDark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final maxSide = math.min(screenW, screenH);
          final endSize = metrics.splashEndAvatarSize(maxSide);

          // One vertical composition: avatar → name → status (not a huge
          // centered avatar with copy stuck to the screen edges).
          final nameGap = metrics.splashNameGap;
          final statusGap = metrics.splashStatusGap;
          final nameLine = metrics.splashNameFontSize * 1.25;
          final statusLine = metrics.splashStatusFontSize * 1.35 * 2;
          final copyBlockH = nameGap + nameLine + statusGap + statusLine;
          final compositionH = endSize + copyBlockH;
          final compositionTop =
              math.max(24.0, (screenH - compositionH) / 2);
          final endCenter = Offset(
            screenW / 2,
            compositionTop + endSize / 2,
          );
          final endRect = Rect.fromCenter(
            center: endCenter,
            width: endSize,
            height: endSize,
          );

          final fallbackOrigin = Rect.fromCenter(
            center: endCenter,
            width: metrics.avatarSize,
            height: metrics.avatarSize,
          );
          final startRect = widget.originRect ?? fallbackOrigin;

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _motionController,
                builder: (context, child) {
                  final t = _motion.value;
                  final left =
                      startRect.left + (endRect.left - startRect.left) * t;
                  final top =
                      startRect.top + (endRect.top - startRect.top) * t;
                  final size =
                      startRect.width + (endSize - startRect.width) * t;
                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        width: size,
                        height: size,
                        child: ForjaProfileAvatar(
                          avatarKey: widget.profile.avatarKey,
                          name: widget.profile.name,
                          size: size,
                          selected: true,
                          showBorder: false,
                        ),
                      ),
                      Positioned(
                        left: 48,
                        right: 48,
                        top: endRect.bottom + nameGap,
                        child: Opacity(
                          opacity: _copyOpacity.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ForjaShellColors.textPrimary,
                                  fontSize: metrics.splashNameFontSize,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (status.isNotEmpty) ...[
                                SizedBox(height: statusGap),
                                Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ForjaShellColors.textSecondary
                                        .withValues(alpha: 0.85),
                                    fontSize: metrics.splashStatusFontSize,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
