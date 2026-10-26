import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/auth/account_session_vault.dart';

void main() {
  late MemoryAccountSessionVaultStore store;
  late AccountSessionVault vault;

  setUp(() {
    store = MemoryAccountSessionVaultStore();
    vault = AccountSessionVault(store: store, maxAccounts: 3);
  });

  DeviceAccountSession entry(
    String id, {
    String email = '',
    String refresh = 'rt',
    String? access,
    int lastUsedMs = 0,
  }) {
    return DeviceAccountSession(
      userId: id,
      email: email.isEmpty ? '$id@example.com' : email,
      refreshToken: refresh,
      accessToken: access,
      lastUsedMs: lastUsedMs,
    );
  }

  test('upsert round-trip and setActive', () async {
    await vault.upsert(entry('a', refresh: 'rt-a', lastUsedMs: 1));
    await vault.upsert(entry('b', refresh: 'rt-b', lastUsedMs: 2));
    var state = await vault.load();
    expect(state.accounts, hasLength(2));
    expect(state.activeUserId, 'b');
    expect(state.byUserId('a')!.refreshToken, 'rt-a');

    state = await vault.setActive('a');
    expect(state.activeUserId, 'a');
  });

  test('rotate rewrite replaces refresh token for same user', () async {
    await vault.upsert(entry('a', refresh: 'rt-1', lastUsedMs: 1));
    await vault.upsert(
      entry('a', refresh: 'rt-2', access: 'at-2', lastUsedMs: 5),
    );
    final state = await vault.load();
    expect(state.accounts, hasLength(1));
    expect(state.byUserId('a')!.refreshToken, 'rt-2');
    expect(state.byUserId('a')!.accessToken, 'at-2');
    expect(state.byUserId('a')!.lastUsedMs, 5);
  });

  test('cap drops oldest inactive when over max', () async {
    await vault.upsert(entry('a', lastUsedMs: 1));
    await vault.upsert(entry('b', lastUsedMs: 2));
    await vault.upsert(entry('c', lastUsedMs: 3));
    await vault.upsert(entry('d', lastUsedMs: 4));
    final state = await vault.load();
    expect(state.accounts, hasLength(3));
    expect(state.byUserId('a'), isNull);
    expect(state.activeUserId, 'd');
    expect(state.byUserId('b'), isNotNull);
    expect(state.byUserId('c'), isNotNull);
    expect(state.byUserId('d'), isNotNull);
  });

  test('remove active promotes most recent remaining', () async {
    await vault.upsert(entry('a', lastUsedMs: 1));
    await vault.upsert(entry('b', lastUsedMs: 10));
    await vault.upsert(entry('c', lastUsedMs: 5));
    final state = await vault.remove('b');
    expect(state.byUserId('b'), isNull);
    expect(state.activeUserId, 'c');
  });

  test('clearAll empties store', () async {
    await vault.upsert(entry('a'));
    await vault.clearAll();
    final state = await vault.load();
    expect(state.accounts, isEmpty);
    expect(state.activeUserId, isNull);
    expect(await store.read(AccountSessionVault.defaultStorageKey), isNull);
  });

  test('sortedByLastUsed newest first', () async {
    await vault.upsert(entry('a', lastUsedMs: 1), setActive: false);
    await vault.upsert(entry('b', lastUsedMs: 9), setActive: true);
    await vault.upsert(entry('c', lastUsedMs: 3), setActive: false);
    final state = await vault.load();
    expect(state.sortedByLastUsed.map((e) => e.userId).toList(), [
      'b',
      'c',
      'a',
    ]);
    expect(state.mostRecent!.userId, 'b');
  });
}
