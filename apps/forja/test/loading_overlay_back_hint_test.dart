import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

Widget _host(ShellProfile profile) {
  return MaterialApp(
    home: ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: const Scaffold(body: Center(child: LoadingOverlayBackHint())),
    ),
  );
}

void main() {
  group('LoadingOverlayBackHint', () {
    testWidgets('leanback TV shows the Back hint', (tester) async {
      await tester.pumpWidget(_host(ShellProfile.tv));
      await tester.pump();

      expect(find.text(LoadingOverlayBackHint.copy), findsOneWidget);
    });

    testWidgets('desktop paints nothing', (tester) async {
      await tester.pumpWidget(_host(ShellProfile.desktop));
      await tester.pump();

      expect(find.text(LoadingOverlayBackHint.copy), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('phone paints nothing', (tester) async {
      await tester.pumpWidget(_host(ShellProfile.mobile));
      await tester.pump();

      expect(find.text(LoadingOverlayBackHint.copy), findsNothing);
    });

    testWidgets('without a ShellScope it defaults to desktop (no hint)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingOverlayBackHint())),
      );
      await tester.pump();

      expect(find.text(LoadingOverlayBackHint.copy), findsNothing);
    });
  });
}
