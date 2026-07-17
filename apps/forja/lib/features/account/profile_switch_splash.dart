import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:rust/rust.dart';

/// Dedicated splash while a profile's settings are prepared and merged.
/// Distinct from the boot [SplashScreen] — used after Who's watching.
class ProfileSwitchSplash extends StatefulWidget {
  const ProfileSwitchSplash({
    super.key,
    required this.profile,
    this.prepareCurrent = true,
  });

  final SyncProfile profile;

  /// When true (mid-session switch), push the current profile before loading.
  final bool prepareCurrent;

  @override
  State<ProfileSwitchSplash> createState() => _ProfileSwitchSplashState();
}

class _ProfileSwitchSplashState extends State<ProfileSwitchSplash> {
  String _status = 'Loading profile…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
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
      if (widget.prepareCurrent) {
        _prepareShellForIncomingProfile();
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return SplashOverlayContent(statusLabel: _status);
  }
}
