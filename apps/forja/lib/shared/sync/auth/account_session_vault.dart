import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One saved GoTrue session for multi-account switch on this device.
@immutable
class DeviceAccountSession {
  const DeviceAccountSession({
    required this.userId,
    required this.email,
    required this.refreshToken,
    this.accessToken,
    required this.lastUsedMs,
  });

  final String userId;
  final String email;
  final String refreshToken;
  final String? accessToken;
  final int lastUsedMs;

  DeviceAccountSession copyWith({
    String? userId,
    String? email,
    String? refreshToken,
    String? accessToken,
    int? lastUsedMs,
    bool clearAccessToken = false,
  }) {
    return DeviceAccountSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      lastUsedMs: lastUsedMs ?? this.lastUsedMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'refreshToken': refreshToken,
    if (accessToken != null && accessToken!.isNotEmpty)
      'accessToken': accessToken,
    'lastUsedMs': lastUsedMs,
  };

  static DeviceAccountSession? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final userId = (json['userId'] as String?)?.trim() ?? '';
    final refresh = (json['refreshToken'] as String?)?.trim() ?? '';
    if (userId.isEmpty || refresh.isEmpty) return null;
    final email = (json['email'] as String?)?.trim() ?? '';
    final access = (json['accessToken'] as String?)?.trim();
    final last = json['lastUsedMs'];
    final lastUsedMs = last is int
        ? last
        : (last is num ? last.toInt() : DateTime.now().millisecondsSinceEpoch);
    return DeviceAccountSession(
      userId: userId,
      email: email,
      refreshToken: refresh,
      accessToken: (access == null || access.isEmpty) ? null : access,
      lastUsedMs: lastUsedMs,
    );
  }

  static DeviceAccountSession? fromSession(
    Session? session, {
    int? lastUsedMs,
  }) {
    if (session == null) return null;
    final userId = session.user.id.trim();
    final refresh = session.refreshToken?.trim() ?? '';
    if (userId.isEmpty || refresh.isEmpty) return null;
    final access = session.accessToken.trim();
    return DeviceAccountSession(
      userId: userId,
      email: session.user.email?.trim() ?? '',
      refreshToken: refresh,
      accessToken: access.isEmpty ? null : access,
      lastUsedMs: lastUsedMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

@immutable
class AccountSessionVaultState {
  const AccountSessionVaultState({this.activeUserId, this.accounts = const []});

  final String? activeUserId;
  final List<DeviceAccountSession> accounts;

  static const empty = AccountSessionVaultState();

  List<DeviceAccountSession> get sortedByLastUsed {
    final copy = List<DeviceAccountSession>.from(accounts);
    copy.sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs));
    return copy;
  }

  DeviceAccountSession? byUserId(String userId) {
    for (final a in accounts) {
      if (a.userId == userId) return a;
    }
    return null;
  }

  DeviceAccountSession? get mostRecent {
    final sorted = sortedByLastUsed;
    return sorted.isEmpty ? null : sorted.first;
  }

  Map<String, dynamic> toJson() => {
    if (activeUserId != null && activeUserId!.isNotEmpty)
      'activeUserId': activeUserId,
    'accounts': accounts.map((a) => a.toJson()).toList(),
  };

  static AccountSessionVaultState fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final raw = json['accounts'];
    final accounts = <DeviceAccountSession>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final parsed = DeviceAccountSession.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (parsed != null) accounts.add(parsed);
      }
    }
    final active = (json['activeUserId'] as String?)?.trim();
    return AccountSessionVaultState(
      activeUserId: (active == null || active.isEmpty) ? null : active,
      accounts: accounts,
    );
  }
}

/// Persist / load layer for [AccountSessionVault] (tests inject memory).
abstract class AccountSessionVaultStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class PlatformAccountSessionVaultStore
    implements AccountSessionVaultStore {
  const PlatformAccountSessionVaultStore();

  @override
  Future<String?> read(String key) => ForjaPlatformSecureStore.read(key);

  @override
  Future<void> write(String key, String value) =>
      ForjaPlatformSecureStore.write(key, value);

  @override
  Future<void> delete(String key) => ForjaPlatformSecureStore.delete(key);
}

/// In-memory store for unit tests.
final class MemoryAccountSessionVaultStore implements AccountSessionVaultStore {
  MemoryAccountSessionVaultStore([Map<String, String>? seed])
    : _map = Map<String, String>.from(seed ?? const {});

  final Map<String, String> _map;

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _map.remove(key);
  }
}

/// Secure multi-account GoTrue session vault (one live Supabase client; N cold tokens).
class AccountSessionVault {
  AccountSessionVault({
    AccountSessionVaultStore? store,
    this.maxAccounts = 5,
    this.storageKey = defaultStorageKey,
  }) : _store = store ?? const PlatformAccountSessionVaultStore();

  static const defaultStorageKey = 'forja_account_session_vault_v1';

  final AccountSessionVaultStore _store;
  final int maxAccounts;
  final String storageKey;

  Future<AccountSessionVaultState> load() async {
    try {
      final raw = await _store.read(storageKey);
      if (raw == null || raw.isEmpty) return AccountSessionVaultState.empty;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AccountSessionVaultState.empty;
      return AccountSessionVaultState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e) {
      debugPrint('[AccountVault] load failed: $e');
      return AccountSessionVaultState.empty;
    }
  }

  Future<void> save(AccountSessionVaultState state) async {
    if (state.accounts.isEmpty) {
      await _store.delete(storageKey);
      return;
    }
    await _store.write(storageKey, jsonEncode(state.toJson()));
  }

  /// Insert or replace [entry]; set active; enforce [maxAccounts] (drop oldest inactive).
  Future<AccountSessionVaultState> upsert(
    DeviceAccountSession entry, {
    bool setActive = true,
  }) async {
    final current = await load();
    final next = <DeviceAccountSession>[];
    var replaced = false;
    for (final a in current.accounts) {
      if (a.userId == entry.userId) {
        next.add(entry);
        replaced = true;
      } else {
        next.add(a);
      }
    }
    if (!replaced) next.add(entry);

    while (next.length > maxAccounts) {
      // Drop oldest non-active (or oldest overall if needed).
      final activeId = setActive ? entry.userId : current.activeUserId;
      DeviceAccountSession? victim;
      for (final a in next) {
        if (activeId != null && a.userId == activeId) continue;
        if (victim == null || a.lastUsedMs < victim.lastUsedMs) {
          victim = a;
        }
      }
      victim ??= next.reduce((a, b) => a.lastUsedMs <= b.lastUsedMs ? a : b);
      next.removeWhere((a) => a.userId == victim!.userId);
    }

    final state = AccountSessionVaultState(
      activeUserId: setActive ? entry.userId : current.activeUserId,
      accounts: next,
    );
    await save(state);
    return state;
  }

  Future<AccountSessionVaultState> setActive(String userId) async {
    final current = await load();
    if (current.byUserId(userId) == null) return current;
    final state = AccountSessionVaultState(
      activeUserId: userId,
      accounts: current.accounts,
    );
    await save(state);
    return state;
  }

  Future<AccountSessionVaultState> remove(String userId) async {
    final current = await load();
    final next = current.accounts.where((a) => a.userId != userId).toList();
    final active = current.activeUserId == userId
        ? (next.isEmpty
              ? null
              : (List<DeviceAccountSession>.from(next)
                      ..sort((a, b) => b.lastUsedMs.compareTo(a.lastUsedMs)))
                    .first
                    .userId)
        : current.activeUserId;
    final state = AccountSessionVaultState(
      activeUserId: active,
      accounts: next,
    );
    await save(state);
    return state;
  }

  Future<void> clearAll() => save(AccountSessionVaultState.empty);

  /// Snapshot [session] into the vault (active).
  Future<AccountSessionVaultState> snapshotFromSession(Session? session) async {
    final entry = DeviceAccountSession.fromSession(session);
    if (entry == null) return load();
    return upsert(entry, setActive: true);
  }
}
