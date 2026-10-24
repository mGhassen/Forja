import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/auth/account_vault.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_auth_session.dart';

class _MemoryStore {
  final Map<String, String> data = {};
  int writes = 0;

  Future<String?> read(String key) async => data[key];
  Future<void> write(String key, String value) async {
    writes++;
    data[key] = value;
  }

  Future<void> delete(String key) async => data.remove(key);
}

AccountVault _vault(_MemoryStore store, {DateTime Function()? clock}) =>
    AccountVault(
      read: store.read,
      write: store.write,
      delete: store.delete,
      clock: clock,
    );

void main() {
  group('AccountVault store', () {
    test('upsert orders most recent first and round-trips JSON', () async {
      final store = _MemoryStore();
      var t = DateTime.utc(2026, 1, 1);
      final vault = _vault(store, clock: () => t);
      await vault.load();

      await vault.upsertFromSession(fakeSession('user-a'));
      t = t.add(const Duration(minutes: 1));
      await vault.upsertFromSession(fakeSession('user-b', aal: 'aal2'));
      expect(vault.order, ['user-b', 'user-a']);
      expect(vault.entryFor('user-b')!.aal, 'aal2');
      expect(vault.entryFor('user-a')!.email, 'user-a@example.test');

      t = t.add(const Duration(minutes: 1));
      await vault.touch('user-a');
      expect(vault.order, ['user-a', 'user-b']);

      final raw = store.data[AccountVault.storageKey]!;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['v'], AccountVault.schemaVersion);
      expect(decoded['order'], ['user-a', 'user-b']);

      final reloaded = _vault(store);
      await reloaded.load();
      expect(reloaded.order, ['user-a', 'user-b']);
      expect(reloaded.entryFor('user-a')!.refreshToken, 'rt-user-a');
      expect(reloaded.entryFor('user-b')!.aal, 'aal2');
      expect(reloaded.entryFor('user-b')!.needsSignIn, isFalse);
    });

    test('remove drops the entry and persists', () async {
      final store = _MemoryStore();
      final vault = _vault(store);
      await vault.load();
      await vault.upsertFromSession(fakeSession('user-a'));
      await vault.upsertFromSession(fakeSession('user-b'));
      await vault.remove('user-a');
      expect(vault.order, ['user-b']);
      final reloaded = _vault(store);
      await reloaded.load();
      expect(reloaded.entryFor('user-a'), isNull);
      expect(reloaded.order, ['user-b']);
    });

    test('markNeedsSignIn keeps the entry without tokens', () async {
      final vault = _vault(_MemoryStore());
      await vault.load();
      await vault.upsertFromSession(fakeSession('user-a'));
      await vault.markNeedsSignIn('user-a');
      final entry = vault.entryFor('user-a')!;
      expect(entry.needsSignIn, isTrue);
      expect(entry.refreshToken, isEmpty);
      expect(entry.accessToken, isNull);
      expect(entry.canResume, isFalse);
      expect(entry.email, 'user-a@example.test');
    });

    test('caps at maxAccounts by evicting the least recently used', () async {
      var t = DateTime.utc(2026);
      final vault = _vault(_MemoryStore(), clock: () => t);
      await vault.load();
      for (var i = 0; i < AccountVault.maxAccounts + 1; i++) {
        t = t.add(const Duration(minutes: 1));
        await vault.upsertFromSession(fakeSession('user-$i'));
      }
      expect(vault.accounts.length, AccountVault.maxAccounts);
      expect(vault.entryFor('user-0'), isNull);
      expect(vault.order.first, 'user-${AccountVault.maxAccounts}');
    });

    test('load tolerates corrupt JSON', () async {
      final store = _MemoryStore();
      store.data[AccountVault.storageKey] = '{not json';
      final vault = _vault(store);
      await vault.load();
      expect(vault.accounts, isEmpty);
      expect(vault.isLoaded, isTrue);
    });
  });

  group('AccountVault auth listener', () {
    late StreamController<AuthState> events;
    late AccountVault vault;
    late _MemoryStore store;

    setUp(() async {
      events = StreamController<AuthState>();
      store = _MemoryStore();
      vault = _vault(store);
      await vault.load();
      vault.bind(events.stream);
    });

    tearDown(() async {
      await vault.dispose();
      await events.close();
    });

    Future<void> emit(AuthState state) async {
      events.add(state);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('signedIn adds the account', () async {
      await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-a')));
      expect(vault.order, ['user-a']);
      expect(vault.entries.value.single.userId, 'user-a');
    });

    test('tokenRefreshed rotates the refresh token', () async {
      await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-a')));
      await emit(
        AuthState(
          AuthChangeEvent.tokenRefreshed,
          fakeSession('user-a', refreshToken: 'rt-user-a-2'),
        ),
      );
      expect(vault.entryFor('user-a')!.refreshToken, 'rt-user-a-2');
      expect(vault.order, ['user-a']);
    });

    test('signedOut(userInitiated) removes the account', () async {
      await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-a')));
      await emit(
        const AuthState(
          AuthChangeEvent.signedOut,
          null,
          signOutReason: SignOutReason.userInitiated,
        ),
      );
      expect(vault.entryFor('user-a'), isNull);
      expect(vault.accounts, isEmpty);
    });

    test('signedOut(sessionExpired) flags needsSignIn and keeps it', () async {
      await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-a')));
      await emit(
        const AuthState(
          AuthChangeEvent.signedOut,
          null,
          signOutReason: SignOutReason.sessionExpired,
        ),
      );
      final entry = vault.entryFor('user-a');
      expect(entry, isNotNull);
      expect(entry!.needsSignIn, isTrue);
      expect(entry.refreshToken, isEmpty);
    });

    test('signedOut(sessionMissing) flags needsSignIn and keeps it', () async {
      await emit(
        AuthState(AuthChangeEvent.initialSession, fakeSession('user-a')),
      );
      await emit(
        const AuthState(
          AuthChangeEvent.signedOut,
          null,
          signOutReason: SignOutReason.sessionMissing,
        ),
      );
      expect(vault.entryFor('user-a')!.needsSignIn, isTrue);
    });

    test(
      'a new signedIn for another user keeps the previous account',
      () async {
        await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-a')));
        await emit(AuthState(AuthChangeEvent.signedIn, fakeSession('user-b')));
        expect(vault.order, ['user-b', 'user-a']);
      },
    );
  });
}
