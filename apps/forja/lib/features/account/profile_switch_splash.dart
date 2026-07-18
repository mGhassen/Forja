import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/app/boot_catalog.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/profile_engine_warm.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:rust/rust.dart';

/// Profile-switch splash: avatar flies from its Who's watching tile to center
/// while scaling up (~5s). Not the boot intro splash.
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
  static const double _chooserAvatarSize = 112;
  static const Duration _splashDuration = Duration(seconds: 5);

  late final AnimationController _motionController;
  late final Animation<double> _motion;
  late final Animation<double> _nameOpacity;

  late final DateTime _startedAt;
  String _status = 'Loading profile…';

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
    _nameOpacity = CurvedAnimation(
      parent: _motionController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
    _motionController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
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

      await ProfileEngineWarm.warm(
        needs,
        startTorrent: true,
        reason: 'profile-splash',
        onStatus: _setStatus,
      );
      if (!mounted) return;

      if (needs.tmdb) {
        _setStatus('Loading your home feed…');
        await BootCatalog.prefetchTmdb(onStatus: _setStatus);
        if (!mounted) return;
      }

      if (widget.prepareCurrent) {
        _prepareShellForIncomingProfile();
      }
      await _waitOutSplash();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      await _waitOutSplash();
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  /// Keep the splash on screen for the full motion even if sync finishes early.
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
    return ColoredBox(
      color: AppTheme.bgDark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final maxSide = math.min(screenW, screenH);
          final endSize = math.max(
            _chooserAvatarSize,
            math.min(maxSide * 0.72, 420.0),
          );
          final endCenter = Offset(screenW / 2, screenH / 2);
          final endRect = Rect.fromCenter(
            center: endCenter,
            width: endSize,
            height: endSize,
          );

          final fallbackOrigin = Rect.fromCenter(
            center: endCenter,
            width: _chooserAvatarSize,
            height: _chooserAvatarSize,
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
                        left: 24,
                        right: 24,
                        top: endRect.bottom + 20,
                        child: Opacity(
                          opacity: _nameOpacity.value,
                          child: Text(
                            widget.profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ForjaShellColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (status.isNotEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.85,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
