import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';
import 'package:passkeys/exceptions.dart';

void main() {
  test('ForjaPasskeys.supported stays off while uiEnabled is false', () {
    expect(ForjaPasskeys.uiEnabled, isFalse);
    expect(ForjaPasskeys.supported, isFalse);
  });

  test('macosOsSupportsPasskeys parses Version major.minor', () {
    if (!Platform.isMacOS) {
      expect(ForjaPasskeys.macosOsSupportsPasskeys, isFalse);
      return;
    }
    final match = RegExp(
      r'Version (\d+)\.(\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    expect(match, isNotNull);
    final major = int.parse(match!.group(1)!);
    final minor = int.parse(match.group(2)!);
    final expected = major > 13 || (major == 13 && minor >= 5);
    expect(ForjaPasskeys.macosOsSupportsPasskeys, expected);
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
