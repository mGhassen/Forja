import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/supabase/forja_passkeys.dart';

void main() {
  test('ForjaPasskeys.supported matches macOS/Windows only', () {
    final expected = Platform.isMacOS || Platform.isWindows;
    expect(ForjaPasskeys.supported, expected);
  });
}
