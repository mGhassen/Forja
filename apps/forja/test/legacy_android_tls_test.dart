import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/network/legacy_android_tls.dart';

void main() {
  test('ISRG Root X1 PEM is a parseable certificate block', () {
    expect(kIsrgRootX1Pem, contains('BEGIN CERTIFICATE'));
    expect(kIsrgRootX1Pem, contains('END CERTIFICATE'));
    expect(kIsrgRootX1Pem, isNot(contains(r'\n')));
    expect(kIsrgRootX1Pem.length, greaterThan(1000));
  });

  test('ISRG Root X2 PEM is a parseable certificate block', () {
    expect(kIsrgRootX2Pem, contains('BEGIN CERTIFICATE'));
    expect(kIsrgRootX2Pem, contains('END CERTIFICATE'));
    expect(kIsrgRootX2Pem, isNot(contains(r'\n')));
    expect(kIsrgRootX2Pem.length, greaterThan(400));
  });

  test('installLegacyAndroidTlsTrust is a no-op off Android', () {
    // On macOS/Linux/Windows host tests this must not throw.
    installLegacyAndroidTlsTrust();
  });
}
