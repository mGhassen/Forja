import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';
import 'package:passkeys/exceptions.dart';

void main() {
  test('ForjaPasskeys.supported matches macOS/Windows only', () {
    final expected = Platform.isMacOS || Platform.isWindows;
    expect(ForjaPasskeys.supported, expected);
  });

  test('userMessage maps domain association failures', () {
    expect(
      ForjaPasskeys.userMessage(DomainNotAssociatedException(null)),
      contains('www.forjahq.xyz'),
    );
    expect(
      ForjaPasskeys.userMessage(PasskeyAuthCancelledException()),
      'Passkey sign-in was cancelled.',
    );
    expect(
      ForjaPasskeys.userMessage(NoCredentialsAvailableException()),
      contains('No passkey found'),
    );
  });
}
