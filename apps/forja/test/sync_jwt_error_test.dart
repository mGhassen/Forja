import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const iatFuture = PostgrestException(
    message: '{"code":"PGRST303","message":"JWTissued at future"}',
    code: '401',
    details: 'Unauthorized',
  );
  const expired = PostgrestException(
    message: '{"code":"PGRST303","message":"JWT expired"}',
    code: '401',
    details: 'Unauthorized',
  );

  test('issued at future is not treated as expired', () {
    expect(SyncService.isJwtIssuedAtFutureError(iatFuture), isTrue);
    expect(SyncService.isJwtExpiredError(iatFuture), isFalse);
    expect(SyncService.isJwtExpiredError(expired), isTrue);
    expect(SyncService.isJwtIssuedAtFutureError(expired), isFalse);
  });

  test('retryAfterJwtIatSkew retries the same call once', () async {
    var n = 0;
    final result = await SyncService.retryAfterJwtIatSkew(() async {
      n++;
      if (n == 1) throw iatFuture;
      return 42;
    });
    expect(result, 42);
    expect(n, 2);
  });
}
