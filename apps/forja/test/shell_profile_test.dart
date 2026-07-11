import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester,
    Size size,
    void Function(BuildContext context) expectFn,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(
            builder: (context) {
              expectFn(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('resolveShellProfile returns mobile for phone portrait on mobile OS',
      (tester) async {
    await pumpProfile(tester, const Size(390, 844), (context) {
      if (Platform.isAndroid || Platform.isIOS) {
        expect(resolveShellProfile(context), ShellProfile.mobile);
      } else {
        expect(resolveShellProfile(context), ShellProfile.desktop);
      }
    });
  });

  testWidgets('resolveShellProfile returns desktop on desktop host or wide layout',
      (tester) async {
    await pumpProfile(tester, const Size(1200, 800), (context) {
      expect(resolveShellProfile(context), ShellProfile.desktop);
    });
  });

  test('shellPlatformConfigFor maps all profiles', () {
    expect(
      shellPlatformConfigFor(ShellProfile.mobile).chromeKind,
      ShellChromeKind.bottomNav,
    );
    expect(
      shellPlatformConfigFor(ShellProfile.desktop).chromeKind,
      ShellChromeKind.navRail,
    );
    expect(
      shellPlatformConfigFor(ShellProfile.tv).chromeKind,
      ShellChromeKind.navRailTv,
    );
  });
}
