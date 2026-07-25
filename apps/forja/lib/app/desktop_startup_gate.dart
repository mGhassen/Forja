import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/account/account_entry_screen.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/features/account/tv_account_link_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/update_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DesktopStartupDestination { account, splash }

DesktopStartupDestination resolveDesktopStartupDestination({
  required bool isDesktop,
  required bool supabaseConfigured,
  required bool hasSession,
}) {
  if (!isDesktop || !supabaseConfigured || hasSession) {
    return DesktopStartupDestination.splash;
  }
  return DesktopStartupDestination.account;
}

/// Cold-start account gate for desktop (email/Web login) and Android TV (device link).
DesktopStartupDestination resolveAuthStartupDestination({
  required bool needsAccountGate,
  required bool supabaseConfigured,
  required bool hasSession,
}) {
  if (!needsAccountGate || !supabaseConfigured || hasSession) {
    return DesktopStartupDestination.splash;
  }
  return DesktopStartupDestination.account;
}

/// Whether a [AuthChangeEvent.signedOut] should replace the running app with
/// [AccountEntryScreen] / [TvAccountLinkScreen].
///
/// Always yes - including involuntary [SignOutReason.sessionExpired] /
/// [SignOutReason.sessionMissing]. Keeping the shell left Guest chrome with
/// prior account IPTV portals still loaded (security leak).
bool shouldReturnToAccountOnSignOut({
  required SignOutReason? reason,
  required bool inActiveAppShell,
}) {
  return true;
}

enum _StartupStage { update, account, profiles, splash }

/// Cold-start gate: update check first, then optional account entry, then splash.
///
/// Desktop and Android TV: Guest and unconfigured builds skip account but still
/// run the update gate before splash. Restored sessions skip account and go
/// update → splash. Fresh sign-in → Who's watching → avatar
/// [ProfileSwitchSplash] → app (no second logo intro). Guest / restored cold
/// start still use the logo [SplashScreen]. Sign-out returns to account without
/// re-running the update check.
class DesktopStartupGate extends StatefulWidget {
  const DesktopStartupGate({super.key, required this.splash});

  final Widget splash;

  @override
  State<DesktopStartupGate> createState() => _DesktopStartupGateState();
}

class _DesktopStartupGateState extends State<DesktopStartupGate> {
  _StartupStage _stage = _StartupStage.update;
  StreamSubscription<AuthState>? _authSub;

  bool get _isDesktopOs =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  bool get _needsAccountGate => _isDesktopOs || PlatformInfo.isAndroidTv;

  bool get _isAndroidTv => PlatformInfo.isAndroidTv;

  @override
  void initState() {
    super.initState();
    _authSub = SyncService.instance.authChanges.listen(
      _onAuthState,
      onError: (Object e, StackTrace st) {
        debugPrint('[DesktopStartupGate] auth stream error: $e');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runUpdateGate());
    });
  }

  @override
  void dispose() {
    final sub = _authSub;
    _authSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _runUpdateGate() async {
    try {
      final result = await AppUpdaterService().checkForUpdates();
      if (!mounted) return;
      if (result.isAvailable && result.info != null) {
        await UpdateDialog.show(context, result.info!);
      } else if (result.isFailed) {
        debugPrint(
          '[DesktopStartupGate] Update check failed: ${result.failureMessage}',
        );
      }
    } catch (e) {
      debugPrint('[DesktopStartupGate] Update check failed: $e');
    }
    if (!mounted) return;
    _enterPostUpdateDestination();
  }

  Future<void> _enterPostUpdateDestination() async {
    // Restored sessions must skip the link screen and Who's watching - land
    // on splash with the last active profile (SharedPreferences).
    var hasSession = SyncService.instance.isSignedIn;
    if (ForjaSupabase.isConfigured) {
      // Always force-refresh when signed in (expired AT, clock skew, gotrue
      // discard). When unsigned, one refresh is a no-op until storage hydrates.
      try {
        await SyncService.instance.refreshSession(force: true);
      } catch (e) {
        debugPrint('[DesktopStartupGate] refreshSession: $e');
      }
      hasSession = SyncService.instance.isSignedIn;
    }
    if (hasSession) {
      try {
        await SyncService.instance.pullAccountFeatures();
        // Ensure active profile row is resolved before splash/shell paint.
        await SyncService.instance.activeProfile();
      } on SyncProfileFetchException catch (e) {
        // Do not crash the startup gate - splash/shell still open; Settings
        // Profile shows Retry. Session may still be valid after a soft fail.
        debugPrint('[DesktopStartupGate] activeProfile: $e');
      } catch (e) {
        debugPrint('[DesktopStartupGate] post-update sync: $e');
      }
      hasSession = SyncService.instance.isSignedIn;
    }
    if (!mounted) return;
    final destination = resolveAuthStartupDestination(
      needsAccountGate: _needsAccountGate,
      supabaseConfigured: ForjaSupabase.isConfigured,
      hasSession: hasSession,
    );
    debugPrint(
      '[DesktopStartupGate] post-update hasSession=$hasSession '
      '→ ${destination.name}',
    );
    setState(() {
      _stage = destination == DesktopStartupDestination.account
          ? _StartupStage.account
          : _StartupStage.splash;
    });
  }

  void _onAuthState(AuthState state) {
    if (!mounted) return;
    debugPrint(
      '[DesktopStartupGate] auth event=${state.event.name} '
      'reason=${state.signOutReason?.name ?? 'none'} '
      'stage=$_stage signedIn=${SyncService.instance.isSignedIn}',
    );
    if (state.event != AuthChangeEvent.signedOut) return;
    assert(
      shouldReturnToAccountOnSignOut(
        reason: state.signOutReason,
        inActiveAppShell: _stage == _StartupStage.splash,
      ),
    );
    unawaited(_returnToAccountAfterSignOut());
  }

  Future<void> _returnToAccountAfterSignOut() async {
    if (!_needsAccountGate || !ForjaSupabase.isConfigured) return;
    if (_stage == _StartupStage.account) return;

    // Wipe account-bound local state before showing login (portals, prefs).
    await SyncDomainBridge.instance.clearAccountBoundLocalState();
    SyncService.instance.clearIdentityAfterSignOut();
    if (!mounted) return;

    // Fresh splash/main tree on next entry - do not keep prior dismiss flag.
    ShellBus.splashDismissed.value = false;
    ShellBus.hideGlobalNav.value = false;
    ShellBus.requestTab.value = null;
    ShellBus.selectDefaultTabOnNextNavLoad = false;

    setState(() => _stage = _StartupStage.account);
  }

  /// After [ProfileSwitchSplash] (avatar fly + engine warm) - open the shell
  /// without a second logo intro splash.
  void _enterShellAfterProfileSplash() {
    ShellBus.splashDismissed.value = true;
    setState(() => _stage = _StartupStage.splash);
  }

  @override
  Widget build(BuildContext context) {
    // Splash → MainScreen owns its own caption. Pre-shell stages need chrome
    // here - title bar is hidden app-wide, and WindowCaption only lives in
    // DesktopWindowChrome.wrapShell.
    final child = switch (_stage) {
      _StartupStage.update => const ColoredBox(
        color: AppTheme.appBackground,
        child: SizedBox.expand(),
      ),
      _StartupStage.account => _isAndroidTv
          ? TvAccountLinkScreen(
              onAuthenticated: () =>
                  setState(() => _stage = _StartupStage.profiles),
              onContinueAsGuest: () =>
                  setState(() => _stage = _StartupStage.splash),
            )
          : AccountEntryScreen(
              onAuthenticated: () =>
                  setState(() => _stage = _StartupStage.profiles),
              onContinueAsGuest: () =>
                  setState(() => _stage = _StartupStage.splash),
            ),
      // Same as mid-session desktop: avatar profile splash warms the profile,
      // then the shell opens (no second logo intro).
      _StartupStage.profiles => ProfileChooserScreen(
        prepareCurrentOnSwitch: false,
        useLogoIntroSplash: false,
        onProfileSelected: _enterShellAfterProfileSplash,
        onSignOut: () => setState(() => _stage = _StartupStage.account),
      ),
      _StartupStage.splash => widget.splash,
    };
    if (_stage == _StartupStage.splash) return child;
    if (_isAndroidTv) return child;
    return DesktopWindowChrome.wrapShell(child: child);
  }
}
