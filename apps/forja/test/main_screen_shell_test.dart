import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/adapters/shell_host.dart';
import 'package:forja/shell/main_screen.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

import 'helpers/rust_test_init.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initEngineForTests();
  });

  tearDown(() {
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    ShellTokens.nativeAndroidTvDetected = false;
  });

  testWidgets('desktop layout uses ShellHost nav rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: const MainScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ShellHost), findsOneWidget);
    expect(find.byType(ShellNavRail), findsOneWidget);
  });
}
