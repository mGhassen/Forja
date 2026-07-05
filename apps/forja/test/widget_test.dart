import 'package:flutter_test/flutter_test.dart';
import 'package:forja_shell/forja_shell.dart';
import 'package:forja_ui/forja_ui.dart';

void main() {
  test('bootstrapForja is defined', () {
    expect(bootstrapForja, isNotNull);
  });

  test('MainScreen can be instantiated', () {
    expect(() => const MainScreen(), returnsNormally);
  });
}
