import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Unsigned JWT with the given claims — enough for `Session.expiresAt`,
/// `AccountVaultEntry.jwtAalClaim` and gotrue's `aal` parsing.
String fakeJwt({
  required String sub,
  String aal = 'aal1',
  Duration ttl = const Duration(hours: 1),
}) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = enc({'alg': 'none', 'typ': 'JWT'});
  final payload = enc({
    'sub': sub,
    'aal': aal,
    'iat': now,
    'exp': now + ttl.inSeconds,
  });
  return '$header.$payload.sig';
}

User fakeUser(String id, {String? email, List<Factor> factors = const []}) =>
    User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email ?? '$id@example.test',
      createdAt: '2026-01-01T00:00:00Z',
      factors: factors,
    );

Factor verifiedTotpFactor([String id = 'factor-1']) => Factor(
  id: id,
  friendlyName: 'phone',
  factorType: FactorType.totp,
  status: FactorStatus.verified,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Session fakeSession(
  String userId, {
  String? refreshToken,
  String aal = 'aal1',
  Duration ttl = const Duration(hours: 1),
  List<Factor> factors = const [],
  String? email,
}) => Session(
  accessToken: fakeJwt(sub: userId, aal: aal, ttl: ttl),
  refreshToken: refreshToken ?? 'rt-$userId',
  tokenType: 'bearer',
  user: fakeUser(userId, email: email, factors: factors),
);
