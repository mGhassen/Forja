import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja/features/account/account_entry_screen.dart';
import 'package:forja/features/account/profile_chooser_screen.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';

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

enum _StartupStage { account, profiles, splash }

/// Optional account entry for desktop. Guest and unconfigured builds preserve
/// the existing splash-first startup; restored sessions skip this gate.
class DesktopStartupGate extends StatefulWidget {
  const DesktopStartupGate({super.key, required this.splash});

  final Widget splash;

  @override
  State<DesktopStartupGate> createState() => _DesktopStartupGateState();
}

class _DesktopStartupGateState extends State<DesktopStartupGate> {
  late _StartupStage _stage;

  @override
  void initState() {
    super.initState();
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final destination = resolveDesktopStartupDestination(
      isDesktop: isDesktop,
      supabaseConfigured: ForjaSupabase.isConfigured,
      hasSession: SyncService.instance.isSignedIn,
    );
    _stage = destination == DesktopStartupDestination.account
        ? _StartupStage.account
        : _StartupStage.splash;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _StartupStage.account => AccountEntryScreen(
        onAuthenticated: () => setState(() => _stage = _StartupStage.profiles),
        onContinueAsGuest: () => setState(() => _stage = _StartupStage.splash),
      ),
      _StartupStage.profiles => ProfileChooserScreen(
        onProfileSelected: () => setState(() => _stage = _StartupStage.splash),
        onSignOut: () => setState(() => _stage = _StartupStage.account),
      ),
      _StartupStage.splash => widget.splash,
    };
  }
}
