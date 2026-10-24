import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/auth/account_switcher.dart';
import 'package:forja/shared/sync/auth/account_vault.dart';
import 'package:forja/shared/sync/auth/session_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fake_auth_session.dart';

class _MemoryStore {
  final Map<String, String> data = {};
  Future<String?> read(String key) async => data[key];
  Future<void> write(String key, String value) async => data[key] = value;
  Future<void> delete(String key) async => data.remove(key);
}

/// Records every call. Probe refreshes rotate `rt-<user>` → `rt-<user>-N`
/// and never touch [current]; `setSession` is the only way to change it.
class FakeSessionGateway implements SessionGateway {
  FakeSessionGateway({this.current});

  Session? current;
  final List<String> calls = [];
  final StreamController<AuthState> _events = StreamController.broadcast();
  int signedOutEmitted = 0;

  /// Thrown by the next [probeRefresh] (then cleared).
  Object? nextProbeError;

  /// Thrown by the next main [setSession] (then cleared).
  Object? nextApplyError;

  /// Completed by the test to release [awaitRefreshIdle].
  Completer<void>? refreshInFlight;

  /// Rotated RT → the session it produced.
  final Map<String, Session> probed = {};
  int _rotation = 0;

  @override
  Session? get currentSession => current;

  @override
  Stream<AuthState> get events => _events.stream;

  @override
  Future<Session> probeRefresh(String refreshToken) async {
    calls.add('probe:$refreshToken');
    final err = nextProbeError;
    if (err != null) {
      nextProbeError = null;
      throw err;
    }
    final userId = RegExp(r'^rt-user-([a-z0-9]+)')
        .firstMatch(refreshToken)!
        .group(1)!;
    final aal = refreshToken.contains('aal2') ? 'aal2' : 'aal1';
    final factors = refreshToken.contains('mfa')
        ? [verifiedTotpFactor()]
        : const <Factor>[];
    _rotation++;
    final session = fakeSession(
      'user-$userId',
      refreshToken: '$refreshToken-r$_rotation',
      aal: aal,
      factors: factors,
    );
    probed[session.refreshToken!] = session;
    return session;
  }

  @override
  Future<Session> setSession(
    String refreshToken, {
    required String accessToken,
  }) async {
    calls.add('setSession:$refreshToken');
    final err = nextApplyError;
    if (err != null) {
      nextApplyError = null;
      throw err;
    }
    final session = probed[refreshToken];
    if (session == null) {
      throw AuthSessionMissingException('unknown rt $refreshToken');
    }
    current = session;
    _events.add(AuthState(AuthChangeEvent.signedIn, session));
    return session;
  }

  @override
  Future<void> revoke(String accessToken) async {
    calls.add('revoke');
  }

  @override
  void startAutoRefresh() => calls.add('startAutoRefresh');

  @override
  void stopAutoRefresh() => calls.add('stopAutoRefresh');

  @override
  Future<void> awaitRefreshIdle() async {
    calls.add('awaitRefreshIdle');
    final c = refreshInFlight;
    if (c != null) await c.future;
    calls.add('refreshIdle');
  }

  @override
  bool requiresMfaChallenge() {
    final s = current;
    if (s == null) return false;
    final aal = AccountVaultEntry.jwtAalClaim(s.accessToken);
    final hasFactor =
        s.user.factors?.any((f) => f.status == FactorStatus.verified) ?? false;
    return hasFactor && aal != 'aal2';
  }

  /// Simulates a `signedOut` on the main client (must never happen).
  void emitSignedOut() {
    signedOutEmitted++;
    _events.add(
      const AuthState(
        AuthChangeEvent.signedOut,
        null,
        signOutReason: SignOutReason.sessionExpired,
      ),
    );
  }
}

class _Harness {
  _Harness({Session? current})
    : gateway = FakeSessionGateway(current: current) {
    vault = AccountVault(
      read: store.read,
      write: store.write,
      delete: store.delete,
    );
    switcher = AccountSwitcher(
      gateway: gateway,
      vault: vault,
      prepareProfileSwitch: () async {
        log.add('prepareProfileSwitch');
        if (failPrepare) throw StateError('push failed');
      },
      cancelPendingPushes: () => log.add('cancelPendingPushes'),
      clearAccountFeatures: () => log.add('clearAccountFeatures'),
      notifyIdentityChanged: () => log.add('notifyIdentityChanged'),
      isRetryableNetworkError: (e) => e is AuthRetryableFetchException,
    );
    gateway.events.listen((s) {
      if (s.event == AuthChangeEvent.signedOut) signedOutSeen++;
    });
  }

  final store = _MemoryStore();
  final FakeSessionGateway gateway;
  late final AccountVault vault;
  late final AccountSwitcher switcher;
  final List<String> log = [];
  bool failPrepare = false;
  int signedOutSeen = 0;

  Future<void> seed(List<Session> sessions) async {
    await vault.load();
    for (final s in sessions) {
      await vault.upsertFromSession(s);
    }
  }
}

void main() {
  test(
    'happy path: flush → stop → idle → snapshot → probe → apply → start',
    () async {
      final a = fakeSession('user-a');
      final h = _Harness(current: a);
      await h.seed([fakeSession('user-b'), a]);

      final result = await h.switcher.switchTo('user-b');

      expect(result, AccountSwitchResult.switched);
      expect(h.gateway.current!.user.id, 'user-b');
      expect(h.log.first, 'prepareProfileSwitch');
      expect(h.gateway.calls, [
        'stopAutoRefresh',
        'awaitRefreshIdle',
        'refreshIdle',
        'probe:rt-user-b',
        'setSession:rt-user-b-r1',
        'startAutoRefresh',
      ]);
      expect(h.log, [
        'prepareProfileSwitch',
        'clearAccountFeatures',
        'cancelPendingPushes',
        'notifyIdentityChanged',
      ]);
      // Rotated RT persisted; leaving account kept; target most recent.
      expect(h.vault.entryFor('user-b')!.refreshToken, 'rt-user-b-r1');
      expect(h.vault.entryFor('user-a')!.refreshToken, 'rt-user-a');
      expect(h.vault.order, ['user-b', 'user-a']);
      expect(h.signedOutSeen, 0);
      expect(h.gateway.signedOutEmitted, 0);
    },
  );

  test('same user → alreadyActive, nothing called', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([a]);
    expect(
      await h.switcher.switchTo('user-a'),
      AccountSwitchResult.alreadyActive,
    );
    expect(h.gateway.calls, isEmpty);
    expect(h.log, isEmpty);
  });

  test('pending push failure → pushFailed, main untouched', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a)..failPrepare = true;
    await h.seed([fakeSession('user-b'), a]);
    expect(await h.switcher.switchTo('user-b'), AccountSwitchResult.pushFailed);
    expect(h.gateway.calls, isEmpty);
    expect(h.gateway.current, same(a));
  });

  test(
    'probe rejected (non-retryable) → needsSignIn, main untouched',
    () async {
      final a = fakeSession('user-a');
      final h = _Harness(current: a);
      await h.seed([fakeSession('user-b'), a]);
      h.gateway.nextProbeError = const AuthApiException(
        'Invalid Refresh Token',
        statusCode: '400',
        code: 'refresh_token_not_found',
      );

      expect(
        await h.switcher.switchTo('user-b'),
        AccountSwitchResult.needsSignIn,
      );
      expect(h.gateway.current, same(a));
      expect(h.gateway.calls, isNot(contains(startsWith('setSession'))));
      expect(h.gateway.calls.last, 'startAutoRefresh');
      expect(h.vault.entryFor('user-b')!.needsSignIn, isTrue);
      expect(h.vault.entryFor('user-b')!.refreshToken, isEmpty);
      expect(h.signedOutSeen, 0);
    },
  );

  test('probe retryable network error → offline, vault entry intact', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([fakeSession('user-b'), a]);
    h.gateway.nextProbeError = AuthRetryableFetchException(
      message: 'Failed host lookup',
    );

    expect(await h.switcher.switchTo('user-b'), AccountSwitchResult.offline);
    expect(h.gateway.current, same(a));
    expect(h.vault.entryFor('user-b')!.needsSignIn, isFalse);
    expect(h.vault.entryFor('user-b')!.refreshToken, 'rt-user-b');
    expect(h.gateway.calls.last, 'startAutoRefresh');
  });

  test('in-flight refresh is awaited before the leaving snapshot', () async {
    final a = fakeSession('user-a', refreshToken: 'rt-user-a-old');
    final h = _Harness(current: a);
    await h.seed([fakeSession('user-b'), a]);
    final inflight = Completer<void>();
    h.gateway.refreshInFlight = inflight;

    final run = h.switcher.switchTo('user-b');
    await Future<void>.delayed(Duration.zero);
    expect(h.gateway.calls, ['stopAutoRefresh', 'awaitRefreshIdle']);
    // Refresh lands a rotated RT on the main client before we snapshot.
    h.gateway.current = fakeSession('user-a', refreshToken: 'rt-user-a-new');
    inflight.complete();

    expect(await run, AccountSwitchResult.switched);
    expect(h.vault.entryFor('user-a')!.refreshToken, 'rt-user-a-new');
  });

  test(
    'aal1 session with a verified factor → mfaRequired after apply',
    () async {
      final a = fakeSession('user-a');
      final h = _Harness(current: a);
      await h.seed([fakeSession('user-b', refreshToken: 'rt-user-b-mfa'), a]);

      expect(
        await h.switcher.switchTo('user-b'),
        AccountSwitchResult.mfaRequired,
      );
      expect(h.gateway.current!.user.id, 'user-b');
      expect(h.log, isNot(contains('notifyIdentityChanged')));
      expect(h.gateway.calls.last, 'startAutoRefresh');
    },
  );

  test('apply rejected once → re-probe with rotated RT, then apply', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([fakeSession('user-b'), a]);
    h.gateway.nextApplyError = const AuthApiException(
      'bad jwt',
      statusCode: '401',
    );

    expect(await h.switcher.switchTo('user-b'), AccountSwitchResult.switched);
    expect(
      h.gateway.calls,
      containsAllInOrder([
        'probe:rt-user-b',
        'setSession:rt-user-b-r1',
        'probe:rt-user-b-r1',
        'setSession:rt-user-b-r1-r2',
      ]),
    );
    expect(h.vault.entryFor('user-b')!.refreshToken, 'rt-user-b-r1-r2');
    expect(h.signedOutSeen, 0);
  });

  test('remove inactive account → probe + revoke + vault drop', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([fakeSession('user-b'), a]);
    var signedOutCalls = 0;

    final result = await h.switcher.remove(
      'user-b',
      signOutActive: () async => signedOutCalls++,
    );

    expect(result, AccountRemoveResult.removed);
    expect(signedOutCalls, 0);
    expect(h.gateway.calls, ['probe:rt-user-b', 'revoke']);
    expect(h.vault.entryFor('user-b'), isNull);
    expect(h.gateway.current, same(a));
  });

  test('remove inactive account offline → removed locally only', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([fakeSession('user-b'), a]);
    h.gateway.nextProbeError = AuthRetryableFetchException(message: 'offline');

    final result = await h.switcher.remove(
      'user-b',
      signOutActive: () async {},
    );

    expect(result, AccountRemoveResult.removedLocally);
    expect(h.gateway.calls, ['probe:rt-user-b']);
    expect(h.vault.entryFor('user-b'), isNull);
  });

  test('remove active account → regular sign-out path', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([a]);
    var signedOutCalls = 0;

    final result = await h.switcher.remove(
      'user-a',
      signOutActive: () async => signedOutCalls++,
    );

    expect(result, AccountRemoveResult.signedOut);
    expect(signedOutCalls, 1);
    expect(h.gateway.calls, isEmpty);
    expect(h.vault.entryFor('user-a'), isNull);
  });

  test('beginAdd snapshots the current account and pauses refresh', () async {
    final a = fakeSession('user-a', refreshToken: 'rt-user-a-live');
    final h = _Harness(current: a);
    await h.vault.load();

    await h.switcher.beginAdd();
    expect(h.gateway.calls, [
      'stopAutoRefresh',
      'awaitRefreshIdle',
      'refreshIdle',
    ]);
    expect(h.vault.entryFor('user-a')!.refreshToken, 'rt-user-a-live');

    h.switcher.cancelAdd();
    expect(h.gateway.calls.last, 'startAutoRefresh');
  });

  test('finishAdd reports whether the signed-in user changed', () async {
    final a = fakeSession('user-a');
    final h = _Harness(current: a);
    await h.seed([a]);
    await h.switcher.beginAdd();
    expect(
      await h.switcher.finishAdd(previousUserId: 'user-a'),
      isFalse,
      reason: 'same account signed in again',
    );
    expect(h.log, isNot(contains('clearAccountFeatures')));
    h.gateway.current = fakeSession('user-b');
    await h.vault.upsertFromSession(h.gateway.current!);
    expect(await h.switcher.finishAdd(previousUserId: 'user-a'), isTrue);
    expect(h.log, contains('clearAccountFeatures'));
  });
}
