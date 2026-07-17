import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';

void main() {
  test('every menu destination has its own accent color', () {
    expect(
      navDestinationAccentColors.keys.toSet(),
      navDestinations.keys.toSet(),
    );
    expect(
      navDestinationAccentColors.values.toSet().length,
      navDestinations.length,
    );
  });
}
