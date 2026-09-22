import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

Widget _host({required bool tv, required Widget child}) {
  final profile = tv ? ShellProfile.tv : ShellProfile.desktop;
  return MaterialApp(
    home: ShellScope(
      profile: profile,
      config: shellPlatformConfigFor(profile),
      child: ForjaToastHost(child: child),
    ),
  );
}

void main() {
  tearDown(() {
    ForjaToast.controller.dismissTag('toast-tv-density-test');
    for (final e in List.of(ForjaToast.controller.entries)) {
      ForjaToast.controller.dismiss(e.id);
    }
  });

  testWidgets('toast column width follows TV chrome scale', (tester) async {
    await tester.pumpWidget(
      _host(
        tv: true,
        child: const SizedBox.expand(),
      ),
    );
    ForjaToast.info(
      'Leanback density toast',
      tag: 'toast-tv-density-test',
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.pump();

    final expectedW =
        ShellTokens.chromeScale(ShellTokens.toastWidth, tv: true);
    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(
      sized.any((s) => s.width != null && (s.width! - expectedW).abs() < 0.5),
      isTrue,
    );

    final text = tester.widget<Text>(
      find.text('Leanback density toast'),
    );
    expect(
      text.style?.fontSize,
      ShellTokens.tvTypeSize(ShellTokens.toastMessageFontSize),
    );
  });

  testWidgets('toast column keeps desktop width off TV', (tester) async {
    await tester.pumpWidget(
      _host(
        tv: false,
        child: const SizedBox.expand(),
      ),
    );
    ForjaToast.info(
      'Desktop density toast',
      tag: 'toast-tv-density-test',
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.pump();

    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(
      sized.any(
        (s) =>
            s.width != null && (s.width! - ShellTokens.toastWidth).abs() < 0.5,
      ),
      isTrue,
    );

    final text = tester.widget<Text>(
      find.text('Desktop density toast'),
    );
    expect(text.style?.fontSize, ShellTokens.toastMessageFontSize);
  });
}
