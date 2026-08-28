import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';
import 'package:forja/shared/supabase/forja_secure_local_storage.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Passkeys are @experimental on GoTrueClient.
// ignore_for_file: experimental_member_use

class SyncProfile {
  const SyncProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.avatarKey,
  });

  final String id;
  final String name;
  final String color;
  final String avatarKey;
}

/// Profile list / active-profile fetch failed (timeout, network, PostgREST).
/// Distinct from an empty list (no profiles yet).
class SyncProfileFetchException implements Exception {
  SyncProfileFetchException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncProfileFetchException: $message';
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Rebuilds profile/account chrome after sign-in, sign-out, or profile switch.
  final ValueNotifier<int> identityRevision = ValueNotifier<int>(0);

  bool get isSignedIn => session != null;
  String? get userEmail => session?.user.email;
  Session? get session => ForjaSupabase.clientOrNull?.auth.currentSession;
  static const _activeProfileKeyPrefix = 'forja_sync_active_profile_';
  static const _refreshDebounce = Duration(seconds: 30);
  static const _featuresPullMinInterval = Duration(seconds: 2);
  /// Desktop window left "resumed" never gets lifecycle resume - keep RT warm.
  static const _desktopKeepAliveInterval = Duration(minutes: 12);
  static const _profileFetchTimeout = Duration(seconds: 15);
  /// Cap gotrue `/token` so DNS blips cannot hang Settings / boot forever.
  static const _refreshTimeout = Duration(seconds: 12);
  /// Refresh access JWT when less than this remains before expiry.
  static const _accessTokenRefreshSkew = Duration(minutes: 5);
  /// PostgREST rejects a just-minted JWT when Auth `iat` is ahead of API now.
  static const _jwtIatSkewRetryDelay = Duration(milliseconds: 1200);
  DateTime? _lastRefreshAttempt;
  DateTime? _lastFeaturesPullAt;
  Future<Map<String, dynamic>>? _featuresPullInFlight;
  Timer? _desktopKeepAliveTimer;

  Stream<AuthState> get authChanges {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  void _notifyIdentityChanged() {
    identityRevision.value++;
  }

  /// Single in-flight refresh (Guepard desktop-boot pattern) so boot/resume/
  /// focus never rotate the same RT twice in parallel.
  Future<bool>? _refreshInFlight;

  /// Renews tokens so Auth's inactivity timeout (30d) stays reset while in use.
  ///
  /// Debounced unless [force] is true. Returns false when unsigned or refresh
  /// fails (GoTrue may then emit involuntary `signedOut`).
  ///
  /// Success means [auth.currentSession] is present and not expired - not merely
  /// that gotrue returned tokens. Concurrent `recoverSession` can bump the
  /// session version mid-refresh; gotrue then discards the apply while still
  /// returning a fresh [AuthResponse.session] (JWT-expired PostgREST race).
  Future<bool> refreshSession({bool force = false}) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null || client.auth.currentSession == null) return false;
    final now = DateTime.now();
    if (!force &&
        _lastRefreshAttempt != null &&
        now.difference(_lastRefreshAttempt!) < _refreshDebounce) {
      final current = client.auth.currentSession;
      // Only short-circuit when the AT is still usable; an expired session
      // inside the debounce window must still refresh.
      if (current != null && !current.isExpired) return true;
    }
    final inflight = _refreshInFlight;
    if (inflight != null) return inflight;

    late final Future<bool> run;
    run = () async {
      _lastRefreshAttempt = DateTime.now();
      try {
        final response = await client.auth
            .refreshSession()
            .timeout(_refreshTimeout);
        return await _ensureCurrentSessionApplied(client, response.session);
      } on TimeoutException catch (e) {
        debugPrint('[Sync] refreshSession timed out: $e');
        return false;
      } on AuthException catch (e) {
        debugPrint('[Sync] refreshSession failed: ${e.message}');
        return false;
      } catch (e) {
        debugPrint('[Sync] refreshSession failed: $e');
        return false;
      } finally {
        if (identical(_refreshInFlight, run)) {
          _refreshInFlight = null;
        }
      }
    }();
    _refreshInFlight = run;
    return run;
  }

  /// Applies [returned] when gotrue discarded a successful refresh apply.
  Future<bool> _ensureCurrentSessionApplied(
    SupabaseClient client,
    Session? returned,
  ) async {
    var current = client.auth.currentSession;
    final returnedAt = returned?.accessToken;
    // Trust current only when it is usable *and* matches what refresh returned
    // (or refresh already applied the same tokens). A non-expired current with
    // a *different* returned AT means gotrue discarded a newer apply.
    if (current != null &&
        !current.isExpired &&
        (returnedAt == null ||
            returnedAt.isEmpty ||
            returnedAt == current.accessToken)) {
      return true;
    }

    final rt = returned?.refreshToken;
    final at = returned?.accessToken;
    if (returned == null ||
        rt == null ||
        rt.isEmpty ||
        at == null ||
        at.isEmpty) {
      return current != null && !current.isExpired;
    }

    // Prefer RT-only when the returned AT is already past local expiry - forces
    // a `/token` round-trip instead of setSession(getUser) on a dead JWT.
    final applyAccess = returned.isExpired ? null : at;

    debugPrint(
      '[Sync] refresh returned tokens but currentSession still stale - '
      're-applying (gotrue discard race)',
    );
    try {
      if (applyAccess == null) {
        await client.auth.setSession(rt);
      } else {
        await client.auth.setSession(rt, accessToken: applyAccess);
      }
    } on AuthException catch (e) {
      debugPrint('[Sync] setSession after discard race failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Sync] setSession after discard race failed: $e');
      return false;
    }
    current = client.auth.currentSession;
    return current != null && !current.isExpired;
  }

  static String _jwtErrorBlob(Object? error) {
    if (error == null) return '';
    if (error is SyncProfileFetchException) return _jwtErrorBlob(error.cause);
    if (error is PostgrestException) {
      return '${error.code} ${error.message} ${error.details}';
    }
    return error.toString();
  }

  /// PostgREST `PGRST303` / `JWT issued at future` — Auth clock is ahead of API.
  /// Force-refresh makes this worse (newer `iat`). Retry the same token instead.
  static bool isJwtIssuedAtFutureError(Object? error) {
    return _jwtErrorBlob(error).toLowerCase().contains('issued at future');
  }

  /// PostgREST / gotrue rejected the access JWT as expired (PGRST303).
  /// Does not include [isJwtIssuedAtFutureError] — that is the opposite skew.
  static bool isJwtExpiredError(Object? error) {
    if (error == null) return false;
    if (isJwtIssuedAtFutureError(error)) return false;
    if (error is PostgrestException) {
      final code = error.code?.toUpperCase() ?? '';
      if (code == 'PGRST303') return true;
      final msg = error.message.toLowerCase();
      return msg.contains('jwt expired') || msg.contains('pgrst303');
    }
    if (error is SyncProfileFetchException) {
      return isJwtExpiredError(error.cause);
    }
    final s = error.toString().toLowerCase();
    return s.contains('jwt expired') || s.contains('pgrst303');
  }

  /// One retry of [run] after Auth/API `iat` skew. Does not mint a new JWT.
  static Future<T> retryAfterJwtIatSkew<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      if (!isJwtIssuedAtFutureError(e)) rethrow;
      debugPrint('[Sync] JWT iat in the future — retry same token');
      await Future<void>.delayed(_jwtIatSkewRetryDelay);
      return run();
    }
  }

  /// Starts a desktop timer that refreshes the session while the app stays open
  /// without lifecycle `resumed` (common on macOS). Safe to call repeatedly.
  void startDesktopSessionKeepAlive() {
    _desktopKeepAliveTimer?.cancel();
    _desktopKeepAliveTimer = Timer.periodic(_desktopKeepAliveInterval, (_) {
      if (!isSignedIn) return;
      unawaited(refreshSession());
    });
  }

  void stopDesktopSessionKeepAlive() {
    _desktopKeepAliveTimer?.cancel();
    _desktopKeepAliveTimer = null;
  }

  /// Refresh when the access JWT is missing expiry, already expired, or nearly
  /// expired. Does **not** refresh a seemingly-valid AT (use [refreshSession]
  /// with `force: true` on cold start, or retry after [isJwtExpiredError]).
  Future<void> ensureFreshAccessToken() async {
    if (!isSignedIn) return;
    final current = session;
    if (current == null) return;
    if (current.isExpired) {
      await refreshSession(force: true);
      return;
    }
    final expiresAt = current.expiresAt;
    if (expiresAt == null) {
      await refreshSession(force: true);
      return;
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
      isUtc: true,
    );
    if (expires.difference(DateTime.now().toUtc()) <= _accessTokenRefreshSkew) {
      await refreshSession(force: true);
    }
  }

  /// True when MFA is enrolled but this session is still AAL1.
  bool requiresMfaChallenge() {
    final client = ForjaSupabase.clientOrNull;
    if (client == null || client.auth.currentSession == null) return false;
    final level = client.auth.mfa.getAuthenticatorAssuranceLevel();
    return level.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        level.currentLevel != AuthenticatorAssuranceLevels.aal2;
  }

  /// Verified TOTP factors from the current user JWT (no refresh - avoids RT race).
  List<Factor> listTotpFactors() {
    final client = ForjaSupabase.clientOrNull;
    final factors = client?.auth.currentUser?.factors ?? const <Factor>[];
    return factors
        .where(
          (f) =>
              f.factorType == FactorType.totp &&
              f.status == FactorStatus.verified,
        )
        .toList();
  }

  Future<AuthResponse> verifyMfaTotp({
    required String factorId,
    required String code,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    await client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
    _notifyIdentityChanged();
    return AuthResponse(
      session: client.auth.currentSession,
      user: client.auth.currentUser,
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
    _notifyIdentityChanged();
    return response;
  }

  Future<AuthResponse> signInWithPasskey({String? captchaToken}) async {
    if (!ForjaPasskeys.supported) {
      throw const AuthException(
        'Passkeys are only available on macOS and Windows.',
      );
    }
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.signInWithPasskey(
      ForjaPasskeys.authenticator,
      captchaToken: captchaToken,
    );
    _notifyIdentityChanged();
    return response;
  }

  Future<Passkey> registerPasskey() async {
    if (!ForjaPasskeys.supported) {
      throw const AuthException(
        'Passkeys are only available on macOS and Windows.',
      );
    }
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    return client.auth.registerPasskey(ForjaPasskeys.authenticator);
  }

  Future<List<Passkey>> listPasskeys() async {
    if (!ForjaPasskeys.supported) return const [];
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null || client.auth.currentSession == null) {
      return const [];
    }
    return client.auth.passkey.list();
  }

  Future<void> deletePasskey(String passkeyId) async {
    if (!ForjaPasskeys.supported) {
      throw const AuthException(
        'Passkeys are only available on macOS and Windows.',
      );
    }
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    await client.auth.passkey.delete(passkeyId: passkeyId);
  }

  Future<AuthResponse> createAccount({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.signUp(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
    if (response.session != null) _notifyIdentityChanged();
    return response;
  }

  Future<bool> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      debugPrint('[Sync] signIn failed: Supabase not configured');
      return false;
    }
    try {
      final res = await signInWithPassword(
        email: email,
        password: password,
        captchaToken: captchaToken,
      );
      return res.session != null;
    } catch (e) {
      debugPrint('[Sync] signIn error: $e');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return false;
    try {
      final res = await createAccount(
        email: email,
        password: password,
        captchaToken: captchaToken,
      );
      return res.session != null || res.user != null;
    } catch (e) {
      debugPrint('[Sync] signUp error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return;
    // Gate listens for signedOut and wipes account-bound local state (IPTV…).
    // gotrue clears local session first, then may throw on remote revoke when
    // DNS/TLS is down — never leave Settings stuck on signed-in error chrome.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[Sync] signOut remote revoke failed (local cleared): $e');
    }
    AccountFeatures.instance.clear();
    _notifyIdentityChanged();
  }

  /// Drop cloud feature flags and refresh chrome after session end.
  void clearIdentityAfterSignOut() {
    AccountFeatures.instance.clear();
    _notifyIdentityChanged();
  }

  /// Applies tokens from [DesktopBrowserAuth] (web portal → localhost callback).
  ///
  /// Portal mints a *new* session for the app (edge) and keeps its own browser
  /// session. Prefer access+refresh so gotrue skips `/token` when the JWT is
  /// still valid. Fall back to refresh when access is expired or `getUser`
  /// rejects the JWT (`session_not_found`).
  Future<AuthResponse> signInWithBrowserTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const AuthException('Web login did not return usable tokens.');
    }

    AuthResponse response;
    try {
      response = await client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
    } on AuthException catch (e) {
      if (!_canFallbackBrowserTokenRefresh(e)) rethrow;
      debugPrint(
        '[Sync] setSession(access) failed (${e.code ?? e.message}); '
        'falling back to refresh-only',
      );
      response = await client.auth.setSession(refreshToken);
    }

    if (response.session == null) {
      throw const AuthException('Web login did not return a usable session.');
    }
    // Android TV: EncryptedSharedPreferences alone can drop the session;
    // ForjaPlatformSecureStore dual-writes a prefs vault. Verify after apply.
    try {
      final host = Uri.tryParse(ForjaSupabase.url)?.host ?? 'forja';
      final ls = ForjaSecureLocalStorage(
        persistSessionKey: 'sb-$host-auth-token',
      );
      final persisted = await ls.hasAccessToken();
      debugPrint(
        '[Sync] browser tokens applied signedIn=true persisted=$persisted',
      );
      if (!persisted) {
        debugPrint(
          '[Sync] WARNING: session not durable after setSession - '
          'cold start may return to sign-in',
        );
      }
    } catch (e) {
      debugPrint('[Sync] persist check failed: $e');
    }
    _notifyIdentityChanged();
    return response;
  }

  static bool _canFallbackBrowserTokenRefresh(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    if (code == 'session_not_found' || code == 'session_missing') return true;
    final msg = e.message.toLowerCase();
    return msg.contains('session_not_found') ||
        msg.contains('session from session_id') ||
        msg.contains('session is missing');
  }

  /// Opens the web portal login in the system browser and waits for a session.
  ///
  /// Complete [cancel] to abort the wait (e.g. user tapped Cancel on the
  /// account entry screen).
  Future<AuthResponse> signInWithBrowser({Future<void>? cancel}) async {
    AuthResponse? applied;
    final result = await DesktopBrowserAuth.signIn(
      cancel: cancel,
      onTokens: (accessToken, refreshToken) async {
        applied = await signInWithBrowserTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      },
    );
    // Session may already be applied inside the callback (preferred). If the
    // wait ended as "cancelled" but tokens still landed, prefer the session.
    if (applied != null) return applied!;
    if (!result.isSuccess) {
      throw AuthException(result.error ?? 'Web login failed.');
    }
    return signInWithBrowserTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken!,
    );
  }

  Future<List<SyncProfile>> listProfiles() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];

    Future<List<SyncProfile>> fetchOnce({required bool forceRefresh}) async {
      if (forceRefresh) {
        await refreshSession(force: true);
      } else {
        await ensureFreshAccessToken();
      }
      // Expired AT + failed refresh: PostgREST will block on another gotrue
      // refresh — fail here so Settings can show Sign out instead of spinning.
      final session = client.auth.currentSession;
      if (session == null || session.isExpired) {
        throw SyncProfileFetchException(
          'Session expired and could not refresh. Sign out and sign in again.',
        );
      }
      final rows = await retryAfterJwtIatSkew(
        () => client
            .from('profiles')
            .select('id, name, color, avatar_key, created_at')
            .eq('account_id', userId)
            .order('created_at'),
      );
      return [
        for (final raw in rows as List)
          SyncProfile(
            id: (raw as Map)['id'] as String,
            name: raw['name'] as String? ?? 'Profile',
            color: raw['color'] as String? ?? '#1ce783',
            avatarKey: raw['avatar_key'] as String? ?? 'forge',
          ),
      ];
    }

    try {
      return await fetchOnce(forceRefresh: false).timeout(_profileFetchTimeout);
    } on TimeoutException catch (e) {
      debugPrint('[Sync] listProfiles timeout: $e');
      throw SyncProfileFetchException(
        'Timed out loading profiles. Check your connection and retry.',
        cause: e,
      );
    } catch (e) {
      if (e is SyncProfileFetchException) rethrow;
      if (isJwtExpiredError(e)) {
        debugPrint(
          '[Sync] listProfiles JWT expired - force refresh and retry',
        );
        try {
          return await fetchOnce(forceRefresh: true)
              .timeout(_profileFetchTimeout);
        } on TimeoutException catch (e2) {
          debugPrint('[Sync] listProfiles timeout after JWT retry: $e2');
          throw SyncProfileFetchException(
            'Timed out loading profiles. Check your connection and retry.',
            cause: e2,
          );
        } catch (e2) {
          if (e2 is SyncProfileFetchException) rethrow;
          debugPrint('[Sync] listProfiles error after JWT retry: $e2');
          throw SyncProfileFetchException(
            'Could not load profiles. Check your connection and retry.',
            cause: e2,
          );
        }
      }
      debugPrint('[Sync] listProfiles error: $e');
      throw SyncProfileFetchException(
        'Could not load profiles. Check your connection and retry.',
        cause: e,
      );
    }
  }

  Future<SyncProfile?> activeProfile({List<SyncProfile>? profiles}) async {
    final userId = session?.user.id;
    if (userId == null) return null;
    final list = profiles ?? await listProfiles();
    if (list.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_activeProfileKeyPrefix$userId');
    SyncProfile? selected;
    for (final profile in list) {
      if (profile.id == saved) {
        selected = profile;
        break;
      }
    }
    final active = selected ?? list.first;
    if (saved != active.id) {
      await prefs.setString('$_activeProfileKeyPrefix$userId', active.id);
    }
    return active;
  }

  Future<bool> selectProfile(String profileId) async {
    final userId = session?.user.id;
    if (userId == null) return false;
    final profiles = await listProfiles();
    if (!profiles.any((profile) => profile.id == profileId)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_activeProfileKeyPrefix$userId', profileId);
    _notifyIdentityChanged();
    return true;
  }

  /// Matches `profiles_enforce_max` in Supabase.
  static const maxProfilesPerAccount = 5;

  static const _profileColors = [
    '#1ce783',
    '#ff4d1c',
    '#5aa9ff',
    '#c084fc',
    '#facc15',
    '#fb7185',
  ];

  Future<SyncProfile> createProfile({
    required String name,
    required String avatarKey,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to create a profile.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AuthException('Enter a profile name.');
    }
    final existing = await listProfiles();
    if (existing.length >= maxProfilesPerAccount) {
      throw const AuthException('Maximum of 5 profiles per account.');
    }
    final color = _profileColors[existing.length % _profileColors.length];
    try {
      final row = await client
          .from('profiles')
          .insert({
            'account_id': userId,
            'name': cleanName,
            'color': color,
            'avatar_key': avatarKey,
          })
          .select('id, name, color, avatar_key')
          .single();
      final profile = SyncProfile(
        id: row['id'] as String,
        name: row['name'] as String? ?? cleanName,
        color: row['color'] as String? ?? color,
        avatarKey: row['avatar_key'] as String? ?? avatarKey,
      );
      await client.from('profile_settings').upsert({
        'profile_id': profile.id,
        'account_id': userId,
        'payload': <String, dynamic>{},
      });
      await selectProfile(profile.id);
      return profile;
    } catch (e) {
      debugPrint('[Sync] createProfile error: $e');
      throw const AuthException('Could not create profile.');
    }
  }

  Future<void> updateProfile({
    required String profileId,
    required String name,
    required String avatarKey,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to edit a profile.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AuthException('Enter a profile name.');
    }
    try {
      await client
          .from('profiles')
          .update({
            'name': cleanName,
            'avatar_key': avatarKey,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', profileId)
          .eq('account_id', userId);
      _notifyIdentityChanged();
    } catch (e) {
      debugPrint('[Sync] updateProfile error: $e');
      throw const AuthException('Could not save profile.');
    }
  }

  Future<void> deleteProfile(String profileId) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to delete a profile.');
    }
    final profiles = await listProfiles();
    if (profiles.length <= 1) {
      throw const AuthException('Every account needs one profile.');
    }
    final wasActive = (await activeProfile())?.id == profileId;
    try {
      await client
          .from('profiles')
          .delete()
          .eq('id', profileId)
          .eq('account_id', userId);
      if (wasActive) {
        final next = profiles.firstWhere((p) => p.id != profileId);
        await selectProfile(next.id);
      } else {
        _notifyIdentityChanged();
      }
    } catch (e) {
      debugPrint('[Sync] deleteProfile error: $e');
      throw const AuthException('Could not delete profile.');
    }
  }

  /// Upsert domain payloads. Domain allowlist is deferred (RFC-006 R06-A09).
  @Deprecated('Use pushProfileSettings for lean single-row sync')
  Future<void> pushSettings(Map<String, dynamic> domains) async {
    // Compose legacy domain map into one lean profile_settings payload.
    final merged = <String, dynamic>{};
    final connected = <String, dynamic>{};
    for (final e in domains.entries) {
      switch (e.key) {
        case 'preferences':
          merged['playback'] = e.value;
        case 'providers':
          connected['providers'] = e.value;
        case 'stremio':
          connected['stremio'] = e.value;
        case 'nuvio':
          connected['nuvio'] = e.value;
        case 'forja':
          connected['forja'] = e.value;
        case 'navigation':
          merged['navigation'] = e.value;
        case 'iptv':
          // Ignored - portals use user_iptv_portals; M3U is device-local.
          break;
      }
    }
    if (connected.isNotEmpty) merged['connectedServices'] = connected;
    await pushProfileSettings(merged);
  }

  Future<void> pushDomain(String domain, Map<String, dynamic> payload) async {
    await pushSettings({domain: payload});
  }

  Future<void> pushProfileSettings(Map<String, dynamic> payload) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final profile = await activeProfile();
    if (profile == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await client.from('profile_settings').upsert({
        'profile_id': profile.id,
        'account_id': userId,
        'payload': payload,
        'updated_at': now,
        'updated_by': userId,
      });
    } catch (e) {
      debugPrint('[Sync] pushProfileSettings error: $e');
    }
  }

  /// Lean `profile_settings.payload` for the active profile.
  ///
  /// - `null` — no row yet (caller may seed defaults).
  /// - empty / non-empty map — existing row.
  /// Throws on network / auth / PostgREST errors so callers never treat a
  /// failed pull as "missing" and seed+push platform defaults over cloud
  /// (issue 126).
  Future<Map<String, dynamic>?> pullProfileSettings() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    final profile = await activeProfile();
    if (profile == null) return null;

    try {
      final row = await retryAfterJwtIatSkew(
        () => client
            .from('profile_settings')
            .select('payload, updated_at')
            .eq('account_id', userId)
            .eq('profile_id', profile.id)
            .maybeSingle(),
      );
      if (row == null) return null;
      final payload = row['payload'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('[Sync] pullProfileSettings error: $e');
      rethrow;
    }
  }

  /// Lean `accounts.features` - empty map means all flags off.
  ///
  /// Coalesces concurrent calls; skips network if a pull finished within
  /// [_featuresPullMinInterval] unless [force] (e.g. after Deal).
  Future<Map<String, dynamic>> pullAccountFeatures({bool force = false}) async {
    if (!force && _featuresPullInFlight != null) {
      return _featuresPullInFlight!;
    }
    if (!force &&
        _lastFeaturesPullAt != null &&
        DateTime.now().difference(_lastFeaturesPullAt!) <
            _featuresPullMinInterval) {
      return const {};
    }

    final future = _pullAccountFeaturesBody();
    _featuresPullInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_featuresPullInFlight, future)) {
        _featuresPullInFlight = null;
      }
    }
  }

  Future<Map<String, dynamic>> _pullAccountFeaturesBody() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      AccountFeatures.instance.clear();
      return const {};
    }

    Future<Map<String, dynamic>> pullOnce({required bool forceRefresh}) async {
      if (forceRefresh) {
        await refreshSession(force: true);
      } else {
        await ensureFreshAccessToken();
      }
      var isAdmin = false;
      try {
        final rpc = await client.rpc('is_admin');
        isAdmin = rpc == true;
      } catch (e) {
        if (isJwtIssuedAtFutureError(e) || isJwtExpiredError(e)) rethrow;
        // Fall through to accounts.is_admin column.
      }

      Map<String, dynamic>? row;
      try {
        row = await client
            .from('accounts')
            .select('features, iptv_credits, is_admin, member_number')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        if (isJwtIssuedAtFutureError(e) || isJwtExpiredError(e)) rethrow;
        try {
          row = await client
              .from('accounts')
              .select('features, iptv_credits, is_admin')
              .eq('id', userId)
              .maybeSingle();
        } catch (e2) {
          if (isJwtIssuedAtFutureError(e2) || isJwtExpiredError(e2)) rethrow;
          try {
            row = await client
                .from('accounts')
                .select('features, iptv_credits')
                .eq('id', userId)
                .maybeSingle();
          } catch (e3) {
            if (isJwtIssuedAtFutureError(e3) || isJwtExpiredError(e3)) rethrow;
            // Column missing until RFC-040 migration is applied.
            row = await client
                .from('accounts')
                .select('features')
                .eq('id', userId)
                .maybeSingle();
          }
        }
      }
      if (!isAdmin) {
        isAdmin = row?['is_admin'] == true;
      }
      final raw = row?['features'];
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final credits = switch (row?['iptv_credits']) {
        int n => n,
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      };
      final memberNumber = switch (row?['member_number']) {
        int n => n,
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      };
      AccountFeatures.instance.applyRemote(
        map,
        iptvCredits: credits,
        isAdmin: isAdmin,
        memberNumber: memberNumber,
      );
      _lastFeaturesPullAt = DateTime.now();
      return map;
    }

    try {
      return await retryAfterJwtIatSkew(() => pullOnce(forceRefresh: false));
    } catch (e) {
      if (isJwtExpiredError(e)) {
        debugPrint(
          '[Sync] pullAccountFeatures JWT expired - force refresh and retry',
        );
        try {
          return await pullOnce(forceRefresh: true);
        } catch (e2) {
          debugPrint('[Sync] pullAccountFeatures error after JWT retry: $e2');
          AccountFeatures.instance.clear();
          return const {};
        }
      }
      debugPrint('[Sync] pullAccountFeatures error: $e');
      AccountFeatures.instance.clear();
      return const {};
    }
  }

  @Deprecated('Use pullProfileSettings')
  Future<Map<String, dynamic>?> pullSettings() async {
    final payload = await pullProfileSettings();
    if (payload == null) return null;
    // Adapt to legacy domain wrapper shape for any leftover callers.
    final out = <String, dynamic>{};
    if (payload['playback'] is Map) {
      out['preferences'] = {
        'payload': payload['playback'],
        'updated_at': null,
      };
    }
    final connected = payload['connectedServices'];
    if (connected is Map) {
      if (connected['providers'] is Map) {
        out['providers'] = {
          'payload': connected['providers'],
          'updated_at': null,
        };
      }
      if (connected['stremio'] is Map) {
        out['stremio'] = {
          'payload': connected['stremio'],
          'updated_at': null,
        };
      }
      if (connected['nuvio'] is Map) {
        out['nuvio'] = {
          'payload': connected['nuvio'],
          'updated_at': null,
        };
      }
      if (connected['forja'] is Map) {
        out['forja'] = {
          'payload': connected['forja'],
          'updated_at': null,
        };
      }
    }
    // Legacy payload.iptv is ignored (M3U device-local; portals in tables).
    return out;
  }

  /// Deal portals from the catalog pool (burns 1 credit). Returns portal UUIDs.
  Future<List<String>> dealIptvPortals({
    required String profileId,
    String region = 'ANY',
    int count = 5,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw StateError('Not signed in');
    }
    final rows = await client.rpc(
      'deal_iptv_portals',
      params: {
        'p_profile_id': profileId,
        'p_region': region,
        'p_count': count,
      },
    );
    if (rows is! List) return const [];
    return [
      for (final id in rows)
        if (id != null) id.toString(),
    ];
  }

  Future<String?> upsertIptvPortal({
    required String url,
    required String username,
    required String password,
    String? source,
    String? expiry,
    String? maxConnections,
    String platform = 'xtream',
  }) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return null;
    try {
      final id = await client.rpc(
        'upsert_iptv_portal',
        params: {
          'p_url': url,
          'p_username': username,
          'p_password': password,
          'p_source': source,
          'p_expiry': expiry,
          'p_max_connections': maxConnections,
          'p_platform': platform,
        },
      );
      return id as String?;
    } catch (e) {
      debugPrint('[Sync] upsertIptvPortal error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getIptvPortals(List<String> ids) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null || ids.isEmpty) return const [];
    final rows = await client.rpc(
      'get_iptv_portals',
      params: {'p_ids': ids},
    );
    if (rows is! List) return const [];
    return [
      for (final raw in rows) Map<String, dynamic>.from(raw as Map),
    ];
  }

  /// Assignment row count for the active profile (no credential decrypt).
  ///
  /// Used to refuse catastrophic `replace_user_iptv_portals` shrinks when the
  /// local cache is a thin subset of cloud.
  ///
  /// Returns `-1` when auth/profile/count is unavailable — **never** `0` on
  /// "not ready" (that fail-open let a thin local cache replace hundreds).
  Future<int> countUserIptvPortals() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return -1;
    final profile = await activeProfile();
    if (profile == null) return -1;
    try {
      // Exact head count — do not rely on `.select().length` (row cap / race).
      return await client
          .from('user_iptv_portals')
          .count(CountOption.exact)
          .eq('account_id', userId)
          .eq('profile_id', profile.id);
    } catch (e) {
      debugPrint('[Sync] countUserIptvPortals error: $e');
      // Fail closed for shrink checks - caller should not replace.
      return -1;
    }
  }

  /// Load this profile's portal assignments (`user_iptv_portals` + credentials).
  ///
  /// Throws when assignments exist but credentials cannot be loaded - callers
  /// must not treat that as an empty inventory (would wipe local store).
  Future<List<Map<String, dynamic>>> pullUserIptvPortals() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    final profile = await activeProfile();
    if (profile == null) return const [];

    final rows = await client
        .from('user_iptv_portals')
        .select()
        .eq('account_id', userId)
        .eq('profile_id', profile.id)
        .order('created_at');
    if (rows.isEmpty) return const [];
    final assignments = [
      for (final raw in rows) Map<String, dynamic>.from(raw as Map),
    ];
    final ids = <String>[
      for (final a in assignments)
        if ((a['portal_id'] as String?)?.isNotEmpty == true)
          a['portal_id'] as String,
    ];
    final globals = await getIptvPortals(ids);
    if (ids.isNotEmpty && globals.isEmpty) {
      throw StateError(
        'Failed to load portal credentials for ${ids.length} assignment(s)',
      );
    }
    final byId = {
      for (final g in globals) (g['id'] as String? ?? ''): g,
    };
    final out = <Map<String, dynamic>>[];
    for (final a in assignments) {
      final id = a['portal_id'] as String? ?? '';
      final g = byId[id];
      if (g == null) continue;
      out.add({
        ...a,
        'portal': g,
      });
    }
    if (out.isEmpty && ids.isNotEmpty) {
      throw StateError(
        'Portal credentials missing for ${ids.length} assignment(s)',
      );
    }
    return out;
  }

  /// Replace this profile's `user_iptv_portals` rows.
  /// [portalName] is the per-profile label.
  ///
  /// Callers must not pass `[]` unless the user intentionally cleared every
  /// portal - empty local cache must never reach here (see SyncDomainBridge).
  ///
  /// [allowShrink] must be true only for intentional delete / clear-all.
  /// Server refuses shrink when false (issue 118).
  ///
  /// Uses `replace_user_iptv_portals` RPC (grandfather over-limit + atomic).
  Future<void> replaceUserIptvPortals(
    List<
      ({
        String portalId,
        String portalName,
        bool favorite,
      })
    >
    assignments, {
    bool allowShrink = false,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final profile = await activeProfile();
    if (profile == null) return;

    try {
      await client.rpc(
        'replace_user_iptv_portals',
        params: {
          'p_profile_id': profile.id,
          'p_assignments': [
            for (final a in assignments)
              {
                'portal_id': a.portalId,
                'portal_name': a.portalName,
                'favorite': a.favorite,
              },
          ],
          'p_allow_shrink': allowShrink,
        },
      );
    } catch (e) {
      debugPrint('[Sync] replaceUserIptvPortals error: $e');
    }
  }
}
