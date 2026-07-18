import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/account/account_entry_screen.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/shell/main_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/theme/app_theme.dart';
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

enum _StartupStage { update, account, profiles, splash, app }

/// Cold-start gate: update check first, then optional account entry, then splash.
///
/// Guest and unconfigured builds skip account but still run the update gate
/// before splash. Restored sessions skip account and go update → splash.
/// Fresh sign-in → profile splash → [MainScreen] (no logo intro splash).
/// Sign-out returns to account without re-running the update check.
class DesktopStartupGate extends StatefulWidget {
  const DesktopStartupGate({super.key, required this.splash});

  final Widget splash;

  @override
  State<DesktopStartupGate> createState() => _DesktopStartupGateState();
}

class _DesktopStartupGateState extends State<DesktopStartupGate> {
  _StartupStage _stage = _StartupStage.update;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = SyncService.instance.authChanges.listen(_onAuthState);
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
      final updateInfo = await AppUpdaterService().checkForUpdates();
      if (!mounted) return;
      if (updateInfo != null) {
        await UpdateDialog.show(context, updateInfo);
      }
    } catch (e) {
      debugPrint('[DesktopStartupGate] Update check failed: $e');
    }
    if (!mounted) return;
    _enterPostUpdateDestination();
  }

  Future<void> _enterPostUpdateDestination() async {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final hasSession = SyncService.instance.isSignedIn;
    // Restored sessions skip profile chooser, which is otherwise the only
    // place that pulls accounts.features — without this, iptvScrape stays off.
    if (hasSession) {
      await SyncService.instance.pullAccountFeatures();
    }
    if (!mounted) return;
    final destination = resolveDesktopStartupDestination(
      isDesktop: isDesktop,
      supabaseConfigured: ForjaSupabase.isConfigured,
      hasSession: hasSession,
    );
    setState(() {
      _stage = destination == DesktopStartupDestination.account
          ? _StartupStage.account
          : _StartupStage.splash;
    });
  }

  void _onAuthState(AuthState state) {
    if (!mounted) return;
    if (state.event != AuthChangeEvent.signedOut) return;
    _returnToAccountAfterSignOut();
  }

  void _returnToAccountAfterSignOut() {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isDesktop || !ForjaSupabase.isConfigured) return;
    if (_stage == _StartupStage.account) return;

    SyncDomainBridge.instance.cancelPendingPushes();
    // Fresh splash/main tree on next entry — do not keep prior dismiss flag.
    ShellBus.splashDismissed.value = false;
    ShellBus.hideGlobalNav.value = false;
    ShellBus.requestTab.value = null;
    ShellBus.selectDefaultTabOnNextNavLoad = false;

    setState(() => _stage = _StartupStage.account);
  }

  void _enterAppAfterProfileSplash() {
    // Profile splash already warmed engines / catalog — skip logo intro.
    ShellBus.splashDismissed.value = true;
    setState(() => _stage = _StartupStage.app);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _StartupStage.update => const ColoredBox(
        color: AppTheme.appBackground,
        child: SizedBox.expand(),
      ),
      _StartupStage.account => AccountEntryScreen(
        onAuthenticated: () => setState(() => _stage = _StartupStage.profiles),
        onContinueAsGuest: () => setState(() => _stage = _StartupStage.splash),
      ),
      _StartupStage.profiles => ProfileChooserScreen(
        prepareCurrentOnSwitch: false,
        onProfileSelected: _enterAppAfterProfileSplash,
        onSignOut: () => setState(() => _stage = _StartupStage.account),
      ),
      _StartupStage.splash => widget.splash,
      _StartupStage.app => const MainScreen(),
    };
  }
}
