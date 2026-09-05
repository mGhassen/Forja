import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/account/account_entry_screen.dart';
import 'package:forja/features/account/packs_onboarding_screen.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/features/account/profile_switch_splash.dart';
import 'package:forja/features/account/tv_account_link_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/services/app_update_auto_check.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
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

/// Email/password/passkey/Web login ([AccountEntryScreen]). Hidden — desktop
/// cold start uses [TvAccountLinkScreen] (code/QR) like Android TV.
const bool kShowDesktopEmailAuth = false;

/// Cold-start account gate for desktop and Android TV (device link).
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

enum _StartupStage { account, profiles, packs, profileSplash, splash }

/// Cold-start gate: paint account or splash **immediately** from the cached
/// session, then run update check + cloud pull in the background.
///
/// Restored sessions skip Who's watching and land on the logo [SplashScreen]
/// with last-active profile settings from local cache — unless packs onboarding
/// is still pending (`!onboarded`). Fresh sign-in → Who's watching → packs
/// (when needed) → avatar [ProfileSwitchSplash] → app (no second logo intro).
/// Guest → packs (when needed, device-local flag) → logo splash → app.
/// Sign-out returns to account without re-running the update check.
class DesktopStartupGate extends ConsumerStatefulWidget {
  const DesktopStartupGate({super.key, required this.splash});

  final Widget splash;

  @override
  ConsumerState<DesktopStartupGate> createState() => _DesktopStartupGateState();
}

class _DesktopStartupGateState extends ConsumerState<DesktopStartupGate> {
  late _StartupStage _stage;
  StreamSubscription<AuthState>? _authSub;
  SyncProfile? _splashProfile;
  /// Restored-session or guest packs path: packs done → shell (no profile splash).
  bool _packsSkipProfileSplash = false;

  bool get _isDesktopOs =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  bool get _needsAccountGate => _isDesktopOs || PlatformInfo.isAndroidTv;

  bool get _isAndroidTv => PlatformInfo.isAndroidTv;

  @override
  void initState() {
    super.initState();
    // First frame = splash or account. Never a blank "update" stage.
    _stage = _stageFromCachedSession();
    _authSub = SyncService.instance.authChanges.listen(
      _onAuthState,
      onError: (Object e, StackTrace st) {
        debugPrint('[DesktopStartupGate] auth stream error: $e');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runBackgroundStartup());
    });
  }

  @override
  void dispose() {
    final sub = _authSub;
    _authSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  _StartupStage _stageFromCachedSession() {
    final destination = resolveAuthStartupDestination(
      needsAccountGate: _needsAccountGate,
      supabaseConfigured: ForjaSupabase.isConfigured,
      hasSession: SyncService.instance.isSignedIn,
    );
    return destination == DesktopStartupDestination.account
        ? _StartupStage.account
        : _StartupStage.splash;
  }

  /// Update dialog + session refresh + profile pull — never blocks first paint.
  Future<void> _runBackgroundStartup() async {
    await _runUpdateCheck();
    if (!mounted) return;
    await _syncRestoredSessionInBackground();
  }

  Future<void> _runUpdateCheck() async {
    try {
      final result = await AppUpdaterService().checkForUpdates();
      await AppUpdateAutoCheck.recordCheckCompleted();
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
  }

  Future<void> _syncRestoredSessionInBackground() async {
    var hasSession = SyncService.instance.isSignedIn;
    if (ForjaSupabase.isConfigured) {
      try {
        await SyncService.instance.refreshSession(force: true);
      } catch (e) {
        debugPrint('[DesktopStartupGate] refreshSession: $e');
      }
      hasSession = SyncService.instance.isSignedIn;
    }

    if (!hasSession) {
      await SyncService.instance.useGuestPluginDiskScope();
      if (!mounted) return;
      // Painted splash from a stale cache; session gone → account gate.
      if (_needsAccountGate &&
          ForjaSupabase.isConfigured &&
          _stage == _StartupStage.splash) {
        debugPrint(
          '[DesktopStartupGate] background: no session → account',
        );
        setState(() => _stage = _StartupStage.account);
      }
      return;
    }

    try {
      await SyncService.instance.activeProfile();
      // Restored session skips Who's watching / ProfileSwitchSplash, so this
      // is the cold-start pull of nav, Stremio, IPTV, playback prefs into
      // local cache. Soft-fail keeps local (incl. IPTV connection resets).
      await ref.read(profileSettingsSyncProvider.notifier).pullAndMergeAll();
    } on SyncProfileFetchException catch (e) {
      debugPrint('[DesktopStartupGate] activeProfile: $e');
    } catch (e) {
      debugPrint('[DesktopStartupGate] background sync: $e');
    }

    if (!mounted) return;
    debugPrint(
      '[DesktopStartupGate] background sync done hasSession='
      '${SyncService.instance.isSignedIn} stage=$_stage',
    );

    // Upgrade / empty-onboarded cohort: interrupt splash → packs once.
    if (_stage == _StartupStage.splash &&
        SyncService.instance.isSignedIn &&
        await PacksOnboardingStore.shouldShow()) {
      final auto = await PacksOnboardingStore.autoCompleteIfHasPacks();
      if (!mounted) return;
      if (!auto) {
        debugPrint('[DesktopStartupGate] restored session → packs onboarding');
        _packsSkipProfileSplash = true;
        setState(() => _stage = _StartupStage.packs);
      }
    }
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

    await SyncDomainBridge.instance.clearAccountBoundLocalState();
    SyncService.instance.clearIdentityAfterSignOut();
    if (!mounted) return;

    ShellBus.splashDismissed.value = false;
    ShellBus.hideGlobalNav.value = false;
    ShellBus.requestTab.value = null;
    ShellBus.requestSettingsCategory.value = null;
    ShellBus.settingsHubCategoryId.value = 'profile';
    ShellBus.selectDefaultTabOnNextNavLoad = false;
    _splashProfile = null;
    _packsSkipProfileSplash = false;

    setState(() => _stage = _StartupStage.account);
  }

  /// After [ProfileSwitchSplash] (avatar fly + intro-style warm) — open the shell
  /// without a second logo intro splash.
  void _enterShellAfterProfileSplash() {
    ShellBus.splashDismissed.value = true;
    _splashProfile = null;
    setState(() => _stage = _StartupStage.splash);
  }

  Future<void> _afterProfileReady() async {
    if (!mounted) return;
    if (await PacksOnboardingStore.shouldShow()) {
      final auto = await PacksOnboardingStore.autoCompleteIfHasPacks();
      if (!mounted) return;
      if (!auto) {
        _packsSkipProfileSplash = false;
        setState(() => _stage = _StartupStage.packs);
        return;
      }
    }
    await _goToProfileSplash();
  }

  Future<void> _goToProfileSplash() async {
    final profile = await SyncService.instance.activeProfile();
    if (!mounted) return;
    if (profile == null) {
      _enterShellAfterProfileSplash();
      return;
    }
    setState(() {
      _splashProfile = profile;
      _stage = _StartupStage.profileSplash;
    });
  }

  Future<void> _continueAsGuest() async {
    await SyncService.instance.useGuestPluginDiskScope();
    if (!mounted) return;
    if (await PacksOnboardingStore.shouldShow()) {
      final auto = await PacksOnboardingStore.autoCompleteIfHasPacks();
      if (!mounted) return;
      if (!auto) {
        _packsSkipProfileSplash = true;
        setState(() => _stage = _StartupStage.packs);
        return;
      }
    }
    setState(() => _stage = _StartupStage.splash);
  }

  Future<void> _onPacksFinished() async {
    if (!mounted) return;
    if (_packsSkipProfileSplash || !SyncService.instance.isSignedIn) {
      _packsSkipProfileSplash = false;
      _enterShellAfterProfileSplash();
      return;
    }
    await _goToProfileSplash();
  }

  @override
  Widget build(BuildContext context) {
    // Splash → MainScreen owns its own caption. Pre-shell stages need chrome
    // here - title bar is hidden app-wide, and WindowCaption only lives in
    // DesktopWindowChrome.wrapShell.
    final child = switch (_stage) {
      _StartupStage.account =>
        (_isAndroidTv || !kShowDesktopEmailAuth)
            ? TvAccountLinkScreen(
                onAuthenticated: () =>
                    setState(() => _stage = _StartupStage.profiles),
                onContinueAsGuest: () => unawaited(_continueAsGuest()),
              )
            : AccountEntryScreen(
                onAuthenticated: () =>
                    setState(() => _stage = _StartupStage.profiles),
                onContinueAsGuest: () => unawaited(_continueAsGuest()),
              ),
      _StartupStage.profiles => ProfileChooserScreen(
        prepareCurrentOnSwitch: false,
        // Defer ProfileSwitchSplash until after packs onboarding.
        useLogoIntroSplash: true,
        onProfileSelected: () => unawaited(_afterProfileReady()),
        onSignOut: () => setState(() => _stage = _StartupStage.account),
      ),
      _StartupStage.packs => PacksOnboardingScreen(
        onFinished: () => unawaited(_onPacksFinished()),
      ),
      _StartupStage.profileSplash => _splashProfile == null
          ? const SizedBox.shrink()
          : ProfileSwitchSplash(
              profile: _splashProfile!,
              prepareCurrent: false,
              onCompleted: (ok) {
                if (ok) {
                  _enterShellAfterProfileSplash();
                } else if (mounted) {
                  setState(() => _stage = _StartupStage.profiles);
                }
              },
            ),
      _StartupStage.splash => widget.splash,
    };
    if (_stage == _StartupStage.splash) return child;
    if (_isAndroidTv) return child;
    return DesktopWindowChrome.wrapShell(child: child);
  }
}
