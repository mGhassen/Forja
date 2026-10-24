import 'package:flutter/material.dart';
import 'package:forja/features/account/mfa_challenge_view.dart';
import 'package:forja/features/account/profile_switch_splash.dart';
import 'package:forja/shared/sync/sync.dart';

enum AccountSwitchFlowOutcome {
  /// The target account is active (MFA done when it was required).
  switched,

  /// User backed out of MFA; the previous account was restored when there
  /// was one.
  cancelled,
  failed,
}

/// Result of [AccountSwitchFlow.switchTo] with user-facing [message] copy.
@immutable
class AccountSwitchFlowResult {
  const AccountSwitchFlowResult(this.outcome, {this.message});

  final AccountSwitchFlowOutcome outcome;
  final String? message;

  bool get switched => outcome == AccountSwitchFlowOutcome.switched;
}

/// Account switching UI glue shared by Who's watching, the cold-start gate
/// and Settings: run [AccountSwitcher], show the authenticator step when the
/// target needs it, and resolve where to land afterwards.
class AccountSwitchFlow {
  AccountSwitchFlow._();

  static const String offlineMessage =
      'Could not reach Forja. Check the connection and try again.';
  static const String needsSignInMessage = 'Sign in again to use this account.';
  static const String pushFailedMessage =
      'Could not save the current profile. Check the connection and try again.';
  static const String failedMessage = 'Could not switch accounts. Try again.';
  static const String alreadyOnDeviceMessage = 'Already on this device';

  static String switchingMessage(String label) => 'Switching to $label…';

  /// Switches to [target] and runs the MFA step when required.
  static Future<AccountSwitchFlowResult> switchTo(
    BuildContext context,
    AccountVaultEntry target, {
    AccountSwitcher? switcher,
  }) async {
    final sw = switcher ?? AccountSwitcher.instance;
    final previous = sw.currentUserId;
    final result = await sw.switchTo(target.userId);
    switch (result) {
      case AccountSwitchResult.switched:
        return const AccountSwitchFlowResult(AccountSwitchFlowOutcome.switched);
      case AccountSwitchResult.alreadyActive:
        // Cold gate after a cancelled MFA step: the session is in place but
        // still AAL1 — offer the challenge again instead of a dead chip.
        if (!SyncService.instance.requiresMfaChallenge()) {
          return const AccountSwitchFlowResult(
            AccountSwitchFlowOutcome.switched,
          );
        }
      case AccountSwitchResult.mfaRequired:
        break;
      case AccountSwitchResult.offline:
        return const AccountSwitchFlowResult(
          AccountSwitchFlowOutcome.failed,
          message: offlineMessage,
        );
      case AccountSwitchResult.needsSignIn:
        return const AccountSwitchFlowResult(
          AccountSwitchFlowOutcome.failed,
          message: needsSignInMessage,
        );
      case AccountSwitchResult.pushFailed:
        return const AccountSwitchFlowResult(
          AccountSwitchFlowOutcome.failed,
          message: pushFailedMessage,
        );
      case AccountSwitchResult.failed:
        return const AccountSwitchFlowResult(
          AccountSwitchFlowOutcome.failed,
          message: failedMessage,
        );
    }

    if (!context.mounted) {
      return const AccountSwitchFlowResult(AccountSwitchFlowOutcome.failed);
    }
    final verified = await MfaChallengeView.present(context);
    if (verified) {
      SyncService.instance.notifyIdentityResolved();
      return const AccountSwitchFlowResult(AccountSwitchFlowOutcome.switched);
    }
    if (previous != null && previous != target.userId) {
      await sw.switchTo(previous);
    }
    return const AccountSwitchFlowResult(AccountSwitchFlowOutcome.cancelled);
  }

  /// Profile this device last used for the active account, or null when the
  /// account never picked one here (→ Who's watching).
  static Future<SyncProfile?> rememberedProfile(String userId) async {
    final id = await SyncService.instance.lastProfileIdFor(userId);
    if (id == null) return null;
    final card = await SyncService.instance.lastKnownActiveProfile();
    if (card == null || card.id != id) return null;
    return card;
  }

  /// Mid-session landing: avatar splash for a remembered profile. Returns
  /// true when the splash finished, false when there is no remembered
  /// profile (caller opens Who's watching) or the splash failed.
  static Future<bool> pushRememberedProfileSplash(
    BuildContext context,
    String userId,
  ) async {
    final profile = await rememberedProfile(userId);
    if (profile == null || !context.mounted) return false;
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProfileSwitchSplash(profile: profile, prepareCurrent: false),
      ),
    );
    return ok == true;
  }
}
