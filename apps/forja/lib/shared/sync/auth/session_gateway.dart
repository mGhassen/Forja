import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth-session operations [AccountSwitcher] needs, abstracted so tests can
/// record calls and so the probe client never leaks into UI code.
///
/// Contract that keeps the running account safe (RFC-124):
/// - [probeRefresh] and [revoke] run on a throwaway client. They never touch
///   the main session and never emit on [events].
/// - [setSession] is only ever called with a non-expired access token, so
///   gotrue restores directly (`getUser` + save + `signedIn`) and cannot emit
///   `signedOut(sessionExpired)` for the account that is still active.
abstract class SessionGateway {
  Session? get currentSession;
  Stream<AuthState> get events;

  /// Applies [refreshToken] + [accessToken] on the main client.
  Future<Session> setSession(
    String refreshToken, {
    required String accessToken,
  });

  /// Rotates [refreshToken] on a throwaway client and returns the new session.
  /// Throws the gotrue [AuthException] (retryable or not) untouched.
  Future<Session> probeRefresh(String refreshToken);

  /// Revokes the session behind [accessToken] without signing out the main
  /// client (`/logout?scope=local` on a throwaway client).
  Future<void> revoke(String accessToken);

  void stopAutoRefresh();
  void startAutoRefresh();

  /// Resolves once any app-driven refresh in flight has settled.
  Future<void> awaitRefreshIdle();

  /// True when the main session is AAL1 but the user has a verified factor.
  bool requiresMfaChallenge();
}

/// [SessionGateway] over the shared Supabase client plus a short-lived
/// [GoTrueClient] per probe.
class GoTrueSessionGateway implements SessionGateway {
  GoTrueSessionGateway({
    SupabaseClient? Function()? client,
    GoTrueClient Function()? probeClientFactory,
    Future<void> Function()? awaitAppRefreshIdle,
    bool Function()? mfaRequired,
  }) : _client = client ?? (() => ForjaSupabase.clientOrNull),
       _probeFactory = probeClientFactory ?? _defaultProbeClient,
       _awaitAppRefreshIdle = awaitAppRefreshIdle,
       _mfaRequired = mfaRequired;

  final SupabaseClient? Function() _client;
  final GoTrueClient Function() _probeFactory;
  final Future<void> Function()? _awaitAppRefreshIdle;
  final bool Function()? _mfaRequired;

  /// Same headers `SupabaseClient` gives its own auth client — `apikey` plus a
  /// bearer anon key — so `/token`, `/user`, `/logout` are accepted.
  static GoTrueClient _defaultProbeClient() {
    return GoTrueClient(
      url: '${ForjaSupabase.url}/auth/v1',
      headers: {
        'apikey': ForjaSupabase.publishableKey,
        'Authorization': 'Bearer ${ForjaSupabase.publishableKey}',
      },
      autoRefreshToken: false,
    );
  }

  GoTrueClient get _auth {
    final client = _client();
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    return client.auth;
  }

  @override
  Session? get currentSession => _client()?.auth.currentSession;

  @override
  Stream<AuthState> get events =>
      _client()?.auth.onAuthStateChange ?? const Stream.empty();

  @override
  Future<Session> setSession(
    String refreshToken, {
    required String accessToken,
  }) async {
    final response = await _auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    final session = response.session ?? _auth.currentSession;
    if (session == null) {
      throw AuthSessionMissingException('setSession returned no session');
    }
    return session;
  }

  @override
  Future<Session> probeRefresh(String refreshToken) async {
    final probe = _probeFactory();
    try {
      final response = await probe.setSession(refreshToken);
      final session = response.session;
      if (session == null) {
        throw AuthSessionMissingException('Refresh returned no session');
      }
      return session;
    } finally {
      probe.dispose();
    }
  }

  @override
  Future<void> revoke(String accessToken) async {
    final probe = _probeFactory();
    try {
      await probe.admin.signOut(accessToken, scope: SignOutScope.local);
    } finally {
      probe.dispose();
    }
  }

  @override
  void stopAutoRefresh() {
    try {
      _client()?.auth.stopAutoRefresh();
    } catch (e) {
      debugPrint('[SessionGateway] stopAutoRefresh: $e');
    }
  }

  @override
  void startAutoRefresh() {
    try {
      _client()?.auth.startAutoRefresh();
    } catch (e) {
      debugPrint('[SessionGateway] startAutoRefresh: $e');
    }
  }

  @override
  Future<void> awaitRefreshIdle() async {
    final wait = _awaitAppRefreshIdle;
    if (wait != null) await wait();
  }

  @override
  bool requiresMfaChallenge() {
    final custom = _mfaRequired;
    if (custom != null) return custom();
    final client = _client();
    if (client == null || client.auth.currentSession == null) return false;
    final level = client.auth.mfa.getAuthenticatorAssuranceLevel();
    return level.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        level.currentLevel != AuthenticatorAssuranceLevels.aal2;
  }
}
