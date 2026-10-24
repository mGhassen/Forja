import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/sync/api/sync_service.dart';
import 'package:forja/shared/sync/auth/account_vault.dart';
import 'package:forja/shared/sync/auth/session_gateway.dart';
import 'package:forja/shared/sync/bridge/sync_domain_bridge.dart';
import 'package:forja/shared/sync/models/account_features.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AccountSwitchResult {
  switched,
  alreadyActive,

  /// Pending cloud pushes for the leaving profile could not be flushed;
  /// nothing changed.
  pushFailed,

  /// The target could not be refreshed because Forja is unreachable.
  offline,

  /// The target's refresh token was rejected; it needs a fresh sign-in.
  needsSignIn,

  /// Switched, but the target has MFA enrolled and the session is AAL1.
  mfaRequired,
  failed,
}

enum AccountRemoveResult {
  /// Active account: signed out through the regular sign-out path.
  signedOut,

  /// Inactive account: revoked on the server and dropped locally.
  removed,

  /// Inactive account: server revoke failed (offline / rejected token);
  /// dropped locally only.
  removedLocally,
  notFound,
}

/// Switches between accounts remembered in [AccountVault] without a sign-out
/// in between (RFC-124). Every step that could emit `signedOut` on the main
/// client runs on a throwaway probe instead.
class AccountSwitcher {
  AccountSwitcher({
    required SessionGateway gateway,
    required AccountVault vault,
    required Future<void> Function() prepareProfileSwitch,
    required void Function() cancelPendingPushes,
    required void Function() clearAccountFeatures,
    required void Function() notifyIdentityChanged,
    bool Function(Object error)? isRetryableNetworkError,
  }) : _gateway = gateway,
       _vault = vault,
       _prepareProfileSwitch = prepareProfileSwitch,
       _cancelPendingPushes = cancelPendingPushes,
       _clearAccountFeatures = clearAccountFeatures,
       _notifyIdentityChanged = notifyIdentityChanged,
       _isRetryable = isRetryableNetworkError ?? _defaultRetryable;

  static AccountSwitcher? _instance;

  /// Production wiring over the shared Supabase client.
  static AccountSwitcher get instance => _instance ??= AccountSwitcher(
    gateway: GoTrueSessionGateway(
      awaitAppRefreshIdle: SyncService.instance.awaitRefreshIdle,
      mfaRequired: SyncService.instance.requiresMfaChallenge,
    ),
    vault: AccountVault.instance,
    prepareProfileSwitch: SyncDomainBridge.instance.prepareProfileSwitch,
    cancelPendingPushes: SyncDomainBridge.instance.cancelPendingPushes,
    clearAccountFeatures: AccountFeatures.instance.clear,
    notifyIdentityChanged: SyncService.instance.notifyIdentityResolved,
  );

  @visibleForTesting
  static set instance(AccountSwitcher? value) => _instance = value;

  final SessionGateway _gateway;
  final AccountVault _vault;
  final Future<void> Function() _prepareProfileSwitch;
  final void Function() _cancelPendingPushes;
  final void Function() _clearAccountFeatures;
  final void Function() _notifyIdentityChanged;
  final bool Function(Object error) _isRetryable;

  bool _busy = false;
  bool _addInProgress = false;

  bool get isBusy => _busy;
  bool get isAddInProgress => _addInProgress;

  String? get currentUserId => _gateway.currentSession?.user.id;

  static bool _defaultRetryable(Object error) =>
      SyncService.isRetryableAuthNetworkError(error);

  /// Makes [targetUserId] the active account.
  ///
  /// Order: flush pending pushes → stop auto-refresh → wait for an in-flight
  /// refresh → snapshot the leaving account → probe the target on a throwaway
  /// client → persist the rotated tokens → apply on the main client with a
  /// fresh access token → restart auto-refresh → reset account-bound caches.
  Future<AccountSwitchResult> switchTo(String targetUserId) async {
    if (currentUserId == targetUserId) return AccountSwitchResult.alreadyActive;
    if (_busy) return AccountSwitchResult.failed;
    _busy = true;
    try {
      return await _switchTo(targetUserId);
    } finally {
      _busy = false;
    }
  }

  Future<AccountSwitchResult> _switchTo(String targetUserId) async {
    await _vault.load();
    final entry = _vault.entryFor(targetUserId);
    if (entry == null) return AccountSwitchResult.failed;
    if (!entry.canResume) return AccountSwitchResult.needsSignIn;

    try {
      await _prepareProfileSwitch();
    } catch (e) {
      debugPrint('[AccountSwitcher] prepareProfileSwitch failed: $e');
      return AccountSwitchResult.pushFailed;
    }

    _gateway.stopAutoRefresh();
    await _gateway.awaitRefreshIdle();
    final leaving = _gateway.currentSession;
    if (leaving != null) await _vault.upsertFromSession(leaving);

    final Session probed;
    try {
      probed = await _gateway.probeRefresh(entry.refreshToken);
    } catch (e) {
      _gateway.startAutoRefresh();
      if (_isRetryable(e)) {
        debugPrint('[AccountSwitcher] probe offline: $e');
        return AccountSwitchResult.offline;
      }
      if (e is AuthException) {
        debugPrint('[AccountSwitcher] probe rejected: ${e.message}');
        await _vault.markNeedsSignIn(targetUserId);
        return AccountSwitchResult.needsSignIn;
      }
      debugPrint('[AccountSwitcher] probe failed: $e');
      return AccountSwitchResult.failed;
    }
    // Rotated tokens must land in the vault before the main client is
    // touched — a crash in between must not strand the account.
    await _vault.upsertFromSession(probed);

    final applied = await _applyWithRetry(targetUserId, probed);
    if (!applied) {
      await _restore(leaving);
      _gateway.startAutoRefresh();
      return AccountSwitchResult.failed;
    }

    _gateway.startAutoRefresh();
    _clearAccountFeatures();
    _cancelPendingPushes();
    await _vault.touch(targetUserId);
    if (_gateway.requiresMfaChallenge()) {
      return AccountSwitchResult.mfaRequired;
    }
    _notifyIdentityChanged();
    return AccountSwitchResult.switched;
  }

  /// Applies [probed] on the main client. When gotrue rejects the access
  /// token, probes once more for a fresh pair; never falls back to an
  /// RT-only `setSession` on the main client.
  Future<bool> _applyWithRetry(String targetUserId, Session probed) async {
    final rt = probed.refreshToken ?? '';
    if (rt.isEmpty) return false;
    try {
      await _gateway.setSession(rt, accessToken: probed.accessToken);
      return true;
    } catch (e) {
      debugPrint('[AccountSwitcher] apply failed, re-probing once: $e');
    }
    try {
      final again = await _gateway.probeRefresh(rt);
      await _vault.upsertFromSession(again);
      final rt2 = again.refreshToken ?? '';
      if (rt2.isEmpty) return false;
      await _gateway.setSession(rt2, accessToken: again.accessToken);
      return true;
    } catch (e) {
      debugPrint('[AccountSwitcher] re-apply failed: $e');
      return false;
    }
  }

  /// Puts [leaving] back when the switch failed after the main client may
  /// have changed. A main `setSession` with a fresh access token either
  /// succeeds fully or throws before saving, so this is normally a no-op.
  Future<void> _restore(Session? leaving) async {
    if (leaving == null) return;
    if (_gateway.currentSession?.user.id == leaving.user.id) return;
    final rt = leaving.refreshToken ?? '';
    if (rt.isEmpty) return;
    try {
      final again = await _gateway.probeRefresh(rt);
      await _vault.upsertFromSession(again);
      await _gateway.setSession(
        again.refreshToken ?? rt,
        accessToken: again.accessToken,
      );
    } catch (e) {
      debugPrint('[AccountSwitcher] restore failed: $e');
    }
  }

  /// Prepares for a new sign-in while the current account stays signed in on
  /// the main client: stops auto-refresh, waits for an in-flight refresh and
  /// snapshots the current account so it can be resumed later.
  ///
  /// The vault listener records the new account on `signedIn`. Call
  /// [cancelAdd] when the user backs out, or [finishAdd] once a session is
  /// applied.
  Future<void> beginAdd() async {
    if (_addInProgress) return;
    _addInProgress = true;
    try {
      await _prepareProfileSwitch();
    } catch (e) {
      debugPrint('[AccountSwitcher] beginAdd prepareProfileSwitch: $e');
    }
    _gateway.stopAutoRefresh();
    await _gateway.awaitRefreshIdle();
    final current = _gateway.currentSession;
    if (current != null) await _vault.upsertFromSession(current);
  }

  void cancelAdd() {
    if (!_addInProgress) return;
    _addInProgress = false;
    _gateway.startAutoRefresh();
  }

  /// After a new session landed on the main client. Returns true when the
  /// signed-in user is a different account than [previousUserId].
  Future<bool> finishAdd({String? previousUserId}) async {
    _addInProgress = false;
    _gateway.startAutoRefresh();
    final userId = currentUserId;
    if (userId == null) return false;
    await _vault.touch(userId);
    final changed = userId != previousUserId;
    if (changed) {
      _clearAccountFeatures();
      _cancelPendingPushes();
    }
    return changed;
  }

  /// Removes [userId] from this device. The active account goes through the
  /// regular sign-out (vault entry dropped by the auth listener); an inactive
  /// one is revoked on a throwaway client and dropped locally.
  Future<AccountRemoveResult> remove(
    String userId, {
    required Future<void> Function() signOutActive,
  }) async {
    await _vault.load();
    final entry = _vault.entryFor(userId);
    if (entry == null) return AccountRemoveResult.notFound;
    if (userId == currentUserId) {
      await signOutActive();
      await _vault.remove(userId);
      return AccountRemoveResult.signedOut;
    }
    var revoked = false;
    if (entry.canResume) {
      try {
        final fresh = await _gateway.probeRefresh(entry.refreshToken);
        await _gateway.revoke(fresh.accessToken);
        revoked = true;
      } catch (e) {
        debugPrint('[AccountSwitcher] revoke failed (removing locally): $e');
      }
    }
    await _vault.remove(userId);
    return revoked
        ? AccountRemoveResult.removed
        : AccountRemoveResult.removedLocally;
  }
}
