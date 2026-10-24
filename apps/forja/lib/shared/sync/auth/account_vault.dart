import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AccountVaultRead = Future<String?> Function(String key);
typedef AccountVaultWrite = Future<void> Function(String key, String value);
typedef AccountVaultDelete = Future<void> Function(String key);

/// One Forja account remembered on this device (RFC-124).
@immutable
class AccountVaultEntry {
  const AccountVaultEntry({
    required this.userId,
    required this.email,
    required this.refreshToken,
    required this.lastUsedAt,
    this.displayName,
    this.accessToken,
    this.aal = 'aal1',
    this.needsSignIn = false,
  });

  final String userId;
  final String email;
  final String? displayName;

  /// Empty when [needsSignIn] — the account stays listed but cannot be
  /// resumed until the user signs in again.
  final String refreshToken;
  final String? accessToken;

  /// Authenticator assurance level claim of the last known access token.
  final String aal;
  final DateTime lastUsedAt;
  final bool needsSignIn;

  bool get canResume => !needsSignIn && refreshToken.isNotEmpty;

  String get label => email.isNotEmpty ? email : (displayName ?? userId);

  AccountVaultEntry copyWith({
    String? email,
    String? displayName,
    String? refreshToken,
    String? accessToken,
    bool clearAccessToken = false,
    String? aal,
    DateTime? lastUsedAt,
    bool? needsSignIn,
  }) {
    return AccountVaultEntry(
      userId: userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      aal: aal ?? this.aal,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      needsSignIn: needsSignIn ?? this.needsSignIn,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    if (displayName != null) 'displayName': displayName,
    'refreshToken': refreshToken,
    if (accessToken != null) 'accessToken': accessToken,
    'aal': aal,
    'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
    'needsSignIn': needsSignIn,
  };

  static AccountVaultEntry? fromJson(String userId, Object? raw) {
    if (raw is! Map) return null;
    String? str(Object? v) => v is String ? v : null;
    final lastUsed = DateTime.tryParse(str(raw['lastUsedAt']) ?? '');
    return AccountVaultEntry(
      userId: userId,
      email: str(raw['email']) ?? '',
      displayName: str(raw['displayName']),
      refreshToken: str(raw['refreshToken']) ?? '',
      accessToken: str(raw['accessToken']),
      aal: str(raw['aal']) ?? 'aal1',
      lastUsedAt:
          lastUsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      needsSignIn: raw['needsSignIn'] == true,
    );
  }

  /// Builds an entry from a live gotrue [session].
  static AccountVaultEntry fromSession(Session session, {DateTime? now}) {
    final user = session.user;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final display =
        (meta['display_name'] ?? meta['full_name'] ?? meta['name']) as String?;
    return AccountVaultEntry(
      userId: user.id,
      email: user.email ?? '',
      displayName: display,
      refreshToken: session.refreshToken ?? '',
      accessToken: session.accessToken,
      aal: jwtAalClaim(session.accessToken),
      lastUsedAt: (now ?? DateTime.now()).toUtc(),
      needsSignIn: (session.refreshToken ?? '').isEmpty,
    );
  }

  /// `aal` claim of a JWT access token; `aal1` when absent or unparsable.
  static String jwtAalClaim(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) return 'aal1';
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload);
      if (map is Map && map['aal'] is String) return map['aal'] as String;
    } catch (_) {}
    return 'aal1';
  }
}

/// Device-global list of Forja accounts that can be resumed without a new
/// sign-in (RFC-124). Stored under one secure key, never scoped per account
/// and never synced.
///
/// [bind] mirrors gotrue auth events: any event carrying a session upserts
/// that user; a user-initiated sign-out removes the entry; an involuntary
/// sign-out (`sessionExpired` / `sessionMissing`) keeps the entry but flags
/// it as needing a fresh sign-in.
class AccountVault {
  AccountVault({
    AccountVaultRead? read,
    AccountVaultWrite? write,
    AccountVaultDelete? delete,
    DateTime Function()? clock,
  }) : _read = read ?? ForjaPlatformSecureStore.read,
       _write = write ?? ForjaPlatformSecureStore.write,
       _delete = delete ?? ForjaPlatformSecureStore.delete,
       _clock = clock ?? DateTime.now;

  static final AccountVault instance = AccountVault();

  static const String storageKey = 'forja_account_vault_v1';
  static const int schemaVersion = 1;
  static const int maxAccounts = 5;

  final AccountVaultRead _read;
  final AccountVaultWrite _write;
  final AccountVaultDelete _delete;
  final DateTime Function() _clock;

  /// Most recently used first. Rebuilds account chrome on change.
  final ValueNotifier<List<AccountVaultEntry>> entries =
      ValueNotifier<List<AccountVaultEntry>>(const []);

  final Map<String, AccountVaultEntry> _accounts = {};
  final List<String> _order = [];
  bool _loaded = false;
  Future<void>? _loading;
  Future<void> _persistChain = Future.value();
  StreamSubscription<AuthState>? _sub;
  String? _lastSessionUserId;

  bool get isLoaded => _loaded;
  List<AccountVaultEntry> get accounts => entries.value;

  AccountVaultEntry? entryFor(String userId) => _accounts[userId];

  /// User ids in most-recent-first order.
  List<String> get order => List.unmodifiable(_order);

  Future<void> load() {
    final inflight = _loading;
    if (inflight != null) return inflight;
    final run = _load();
    _loading = run;
    return run;
  }

  Future<void> _load() async {
    try {
      final raw = await _read(storageKey);
      _accounts.clear();
      _order.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final accounts = decoded['accounts'];
          final order = decoded['order'];
          if (accounts is Map) {
            for (final entry in accounts.entries) {
              final key = entry.key;
              if (key is! String || key.isEmpty) continue;
              try {
                final parsed = AccountVaultEntry.fromJson(key, entry.value);
                if (parsed != null) _accounts[parsed.userId] = parsed;
              } catch (e) {
                debugPrint('[AccountVault] skipped entry $key: $e');
              }
            }
          }
          if (order is List) {
            for (final id in order) {
              if (id is String && _accounts.containsKey(id)) _order.add(id);
            }
          }
          for (final id in _accounts.keys) {
            if (!_order.contains(id)) _order.add(id);
          }
        }
      }
    } catch (e) {
      debugPrint('[AccountVault] load failed: $e');
      _accounts.clear();
      _order.clear();
    } finally {
      _loaded = true;
      _publish();
    }
  }

  /// Listens to auth events. Call once after the vault is loaded.
  void bind(Stream<AuthState> events) {
    unawaited(_sub?.cancel());
    _sub = events.listen(onAuthState, onError: (Object _) {});
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  @visibleForTesting
  Future<void> onAuthState(AuthState state) async {
    final session = state.session;
    switch (state.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.mfaChallengeVerified:
        if (session == null) return;
        _lastSessionUserId = session.user.id;
        await upsertFromSession(session);
      case AuthChangeEvent.signedOut:
        final userId = _lastSessionUserId;
        _lastSessionUserId = null;
        if (userId == null) return;
        if (state.signOutReason == SignOutReason.userInitiated) {
          await remove(userId);
        } else {
          await markNeedsSignIn(userId);
        }
      case AuthChangeEvent.passwordRecovery:
        if (session != null) {
          _lastSessionUserId = session.user.id;
          await upsertFromSession(session);
        }
      // ignore: deprecated_member_use
      case AuthChangeEvent.userDeleted:
        final userId = _lastSessionUserId ?? session?.user.id;
        _lastSessionUserId = null;
        if (userId != null) await remove(userId);
    }
  }

  /// Records [session] for its user and moves it to the front of [order].
  Future<void> upsertFromSession(Session session) async {
    await load();
    final fresh = AccountVaultEntry.fromSession(session, now: _clock());
    final existing = _accounts[fresh.userId];
    final merged = existing == null
        ? fresh
        : existing.copyWith(
            email: fresh.email.isNotEmpty ? fresh.email : existing.email,
            displayName: fresh.displayName ?? existing.displayName,
            // Keep the last good RT when gotrue hands back a session without
            // one (user-updated payloads) — never downgrade to needsSignIn.
            refreshToken: fresh.refreshToken.isNotEmpty
                ? fresh.refreshToken
                : existing.refreshToken,
            accessToken: fresh.accessToken,
            aal: fresh.aal,
            lastUsedAt: fresh.lastUsedAt,
            needsSignIn: fresh.refreshToken.isNotEmpty
                ? false
                : existing.needsSignIn,
          );
    _accounts[merged.userId] = merged;
    _moveToFront(merged.userId);
    _evictOverCap(keep: merged.userId);
    await _persist();
  }

  Future<void> markNeedsSignIn(String userId) async {
    await load();
    final existing = _accounts[userId];
    if (existing == null) return;
    _accounts[userId] = existing.copyWith(
      refreshToken: '',
      clearAccessToken: true,
      needsSignIn: true,
    );
    await _persist();
  }

  Future<void> remove(String userId) async {
    await load();
    if (_accounts.remove(userId) == null) return;
    _order.remove(userId);
    await _persist();
  }

  /// Marks [userId] as the most recently used account.
  Future<void> touch(String userId) async {
    await load();
    final existing = _accounts[userId];
    if (existing == null) return;
    _accounts[userId] = existing.copyWith(lastUsedAt: _clock().toUtc());
    _moveToFront(userId);
    await _persist();
  }

  Future<void> clear() async {
    _accounts.clear();
    _order.clear();
    _publish();
    _persistChain = _persistChain.then((_) => _delete(storageKey)).catchError((
      Object e,
    ) {
      debugPrint('[AccountVault] clear failed: $e');
    });
    await _persistChain;
  }

  void _moveToFront(String userId) {
    _order.remove(userId);
    _order.insert(0, userId);
  }

  void _evictOverCap({required String keep}) {
    while (_order.length > maxAccounts) {
      final victim = _order.last == keep
          ? _order[_order.length - 2]
          : _order.last;
      _order.remove(victim);
      _accounts.remove(victim);
    }
  }

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'order': List<String>.from(_order),
    'accounts': {
      for (final id in _order)
        if (_accounts[id] != null) id: _accounts[id]!.toJson(),
    },
  };

  Future<void> _persist() {
    _publish();
    final payload = jsonEncode(toJson());
    _persistChain = _persistChain
        .then((_) => _write(storageKey, payload))
        .catchError((Object e) {
          debugPrint('[AccountVault] persist failed: $e');
        });
    return _persistChain;
  }

  void _publish() {
    entries.value = List.unmodifiable([
      for (final id in _order)
        if (_accounts[id] != null) _accounts[id]!,
    ]);
  }
}
