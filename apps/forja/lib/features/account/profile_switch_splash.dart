import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/profile_engine_warm.dart';
import 'package:forja/features/account/profile_chooser_metrics.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:rust/rust.dart';

/// Profile-switch splash: avatar flies from its Who's watching tile to center
/// while scaling up. Boot work matches [SplashScreen] intro: warm under the
/// motion floor, dismiss when the floor elapses even if catalog is still
/// loading, torrent starts after dismiss.
class ProfileSwitchSplash extends ConsumerStatefulWidget {
  const ProfileSwitchSplash({
    super.key,
    required this.profile,
    this.originRect,
    this.prepareCurrent = true,
    this.onCompleted,
  });

  final SyncProfile profile;

  /// Bounds of the tapped avatar in the navigator overlay's local coords.
  final Rect? originRect;

  /// When true (mid-session switch), push the current profile before loading.
  final bool prepareCurrent;

  /// When set (gate-owned splash), called instead of [Navigator.pop].
  final void Function(bool ok)? onCompleted;

  @override
  ConsumerState<ProfileSwitchSplash> createState() =>
      _ProfileSwitchSplashState();
}

class _ProfileSwitchSplashState extends ConsumerState<ProfileSwitchSplash>
    with SingleTickerProviderStateMixin {
  /// Same role as intro [_SplashScreenState._minSplashDuration]: motion floor
  /// and hard cap — dismiss even if warm/TMDB is still running.
  static const Duration _splashDuration = Duration(seconds: 5);
  static const Duration _continueOfferAfter = Duration(seconds: 12);
  static const Duration _stuckStepAfter = Duration(seconds: 10);
  static const Duration _settingsSyncTimeout = Duration(seconds: 30);

  late final AnimationController _motionController;
  late final Animation<double> _motion;
  late final Animation<double> _copyOpacity;

  late final DateTime _startedAt;
  String _status = 'Loading profile…';
  bool _finished = false;
  bool _offerContinue = false;

  Completer<void>? _earlyContinue;
  Completer<void>? _earlySyncContinue;
  Timer? _continueOfferTimer;
  Timer? _syncContinueTimer;
  Timer? _stuckStepTimer;
  int? _lastCompletedSteps;
  bool _packListenersArmed = false;

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
    _disarmPackContinueListeners();
    _continueOfferTimer?.cancel();
    _syncContinueTimer?.cancel();
    _stuckStepTimer?.cancel();
    _motionController.dispose();
    super.dispose();
  }

  /// Mid-session switch: leave the previous screen and open this profile's
  /// saved default tab once navbar config reloads.
  void _prepareShellForIncomingProfile() {
    popShellOverlayUntilRoot();
    ShellBus.clearHideGlobalNav();
    ShellBus.settingsHubCategoryId.value = 'profile';
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
      await _syncProfileSettings();
      if (!mounted) return;

      final needs = await BootNeeds.resolve();

      // Same as intro splash: engines under the floor; play sources after dismiss.
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

  /// Cloud pull for the incoming profile — rotate status like intro splash,
  /// timeout soft-fails lean settings only. IPTV inventory is wiped at the
  /// start of the pull (issue 217) so a stall cannot show another profile's
  /// portals; background sync still fills this profile's assignments.
  Future<void> _syncProfileSettings() async {
    const steps = <String>[
      'Syncing settings…',
      'Pulling your tabs and sources…',
      'Applying playback preferences…',
      'Almost ready…',
    ];
    _setStatus(steps.first);

    final earlySync = Completer<void>();
    _earlySyncContinue = earlySync;
    _syncContinueTimer?.cancel();
    _syncContinueTimer = Timer(_continueOfferAfter, () {
      if (mounted && !_finished) setState(() => _offerContinue = true);
    });

    final syncFuture = ref
        .read(profileSettingsSyncProvider.notifier)
        .pullAndMergeForProfileSwitch();

    try {
      await _awaitWithRotatingStatus(
        Future.any<void>([
          syncFuture,
          earlySync.future,
        ]).timeout(
          _settingsSyncTimeout,
          onTimeout: () {
            debugPrint(
              '[ProfileSplash] Settings sync timed out after '
              '${_settingsSyncTimeout.inSeconds}s — opening; IPTV stays '
              'empty until this profile\'s portal pull finishes',
            );
          },
        ),
        steps,
      );
    } finally {
      _syncContinueTimer?.cancel();
      _syncContinueTimer = null;
      _earlySyncContinue = null;
      if (mounted && !_finished) {
        setState(() => _offerContinue = false);
      }
    }
  }

  /// Rotate [steps] while [work] runs — same cadence as intro splash hold lines.
  Future<void> _awaitWithRotatingStatus(
    Future<void> work,
    List<String> steps,
  ) async {
    if (steps.isEmpty) {
      await work;
      return;
    }
    var index = 0;
    _setStatus(steps[index]);

    while (mounted && !_finished) {
      final finished = await Future.any<bool>([
        work.then((_) => true),
        Future<void>.delayed(const Duration(milliseconds: 1800))
            .then((_) => false),
      ]);
      if (finished) return;
      index = (index + 1) % steps.length;
      _setStatus(steps[index]);
    }
  }

  /// Intro-equivalent warm: packs + hub prefetch; play-source engines post-dismiss.
  Future<void> _warmLikeIntro(BootNeeds needs) async {
    await ProfileEngineWarm.warm(
      needs,
      startTorrent: false,
      startPlaySources: false,
      awaitOfficialPacks: true,
      prefetchDefaultHub: needs.catalogTab,
      reason: 'profile-splash',
      onStatus: _setStatus,
    );
  }

  /// Wait for packs/prefetch, then honor motion floor. User can bail early
  /// via continue-in-background if install is slow/stuck.
  Future<void> _dismissWhenReady(Future<void> bootFuture, BootNeeds needs) async {
    final started = _startedAt;
    final minEnd = started.add(_splashDuration);
    final early = Completer<void>();
    _earlyContinue = early;
    _armPackContinueListeners();

    var continuedEarly = false;
    try {
      final outcome = await Future.any<String>([
        bootFuture.then((_) => 'boot').timeout(
          const Duration(seconds: 30),
          onTimeout: () => 'timeout',
        ),
        early.future.then((_) => 'early'),
      ]);
      continuedEarly = outcome == 'early';
      if (outcome == 'timeout') {
        debugPrint('[ProfileSplash] Pack/hub warm timed out after 30s');
        PluginInstallCoordinator.instance.suppressBanner.value = false;
      }
    } catch (e) {
      debugPrint('[ProfileSplash] Pack/hub warm error/timeout: $e');
      PluginInstallCoordinator.instance.suppressBanner.value = false;
    }

    if (!mounted || _finished) return;
    if (continuedEarly) {
      unawaited(_startPlaySourcesPostSplash(needs));
      return;
    }

    final remaining = minEnd.difference(DateTime.now());
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted || _finished) return;

    _finish(true);
    unawaited(_startPlaySourcesPostSplash(needs));
  }

  void _armPackContinueListeners() {
    if (_packListenersArmed) return;
    _packListenersArmed = true;
    PluginInstallCoordinator.instance.progress.addListener(_onPackProgress);
    PluginRegistry.officialInstallError.addListener(_onPackInstallError);
    _onPackProgress();
    _onPackInstallError();
  }

  void _disarmPackContinueListeners() {
    if (!_packListenersArmed) return;
    _packListenersArmed = false;
    PluginInstallCoordinator.instance.progress.removeListener(_onPackProgress);
    PluginRegistry.officialInstallError.removeListener(_onPackInstallError);
  }

  void _onPackInstallError() {
    if (!mounted || _finished) return;
    if (PluginRegistry.officialInstallError.value != null) {
      setState(() => _offerContinue = true);
    }
  }

  void _onPackProgress() {
    if (!mounted || _finished) return;
    final pack = PluginInstallCoordinator.instance.progress.value;
    if (pack == null) {
      _continueOfferTimer?.cancel();
      _continueOfferTimer = null;
      _stuckStepTimer?.cancel();
      _stuckStepTimer = null;
      _lastCompletedSteps = null;
      return;
    }

    _continueOfferTimer ??= Timer(_continueOfferAfter, () {
      if (mounted && !_finished) setState(() => _offerContinue = true);
    });

    if (_lastCompletedSteps != pack.completedSteps) {
      _lastCompletedSteps = pack.completedSteps;
      _stuckStepTimer?.cancel();
      _stuckStepTimer = Timer(_stuckStepAfter, () {
        if (!mounted || _finished) return;
        if (PluginInstallCoordinator.instance.progress.value != null) {
          setState(() => _offerContinue = true);
        }
      });
    }
  }

  void _continueInBackground() {
    if (!mounted || _finished) return;

    final earlySync = _earlySyncContinue;
    if (earlySync != null && !earlySync.isCompleted) {
      earlySync.complete();
      _syncContinueTimer?.cancel();
      _syncContinueTimer = null;
      if (mounted) setState(() => _offerContinue = false);
      ForjaToast.info(
        'Opening while settings finish syncing. IPTV portals load when ready.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    PluginInstallCoordinator.instance.suppressBanner.value = false;
    final early = _earlyContinue;
    if (early != null && !early.isCompleted) {
      early.complete();
    }
    _finish(true);
    ForjaToast.info(
      'Plugins keep downloading in the background.',
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _startPlaySourcesPostSplash(BootNeeds needs) async {
    await ProfileEngineWarm.warm(
      needs,
      startTorrent: true,
      startPlaySources: true,
      awaitOfficialPacks: false,
      reason: 'post-profile-splash',
    );
  }

  void _finish(bool ok) {
    if (!mounted || _finished) return;
    _finished = true;
    _disarmPackContinueListeners();
    _continueOfferTimer?.cancel();
    _stuckStepTimer?.cancel();
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted(ok);
      return;
    }
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
    final packProgress = PluginInstallCoordinator.instance.progress;
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
                                const SizedBox(height: 10),
                                SplashLoadingDots(
                                  color: ForjaShellColors.textSecondary
                                      .withValues(alpha: 0.65),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: packProgress,
                                  builder: (context, pack, _) {
                                    if (pack == null || pack.totalSteps <= 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Center(
                                        child: SizedBox(
                                          width: math.min(200, screenW - 96),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: pack.fraction,
                                              minHeight: 3,
                                              backgroundColor:
                                                  ForjaShellColors.brandGreen
                                                      .withValues(alpha: 0.15),
                                              valueColor:
                                                  AlwaysStoppedAnimation<
                                                      Color>(
                                                ForjaShellColors.brandGreen
                                                    .withValues(alpha: 0.75),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (_offerContinue) ...[
                                  const SizedBox(height: 14),
                                  SplashContinueInBackgroundButton(
                                    onPressed: _continueInBackground,
                                  ),
                                ],
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
