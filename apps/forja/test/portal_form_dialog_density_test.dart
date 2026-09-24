import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/portals/portal_form_dialog.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

Widget _harness({
  required ShellProfile profile,
  required Widget child,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: profile == ShellProfile.tv
            ? const Size(1920, 1080)
            : const Size(1440, 900),
      ),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(installShellPaintHostAdapters);

  test('desktop hybrid keeps focus chips without TV density', () {
    final desktop = shellPlatformConfigFor(ShellProfile.desktop);
    expect(desktop.inputPolicy.useFocusableMoodChips, isTrue);
    expect(desktop.metrics.usesTvDensity, isFalse);

    final tv = shellPlatformConfigFor(ShellProfile.tv);
    expect(tv.inputPolicy.useFocusableMoodChips, isTrue);
    expect(tv.metrics.usesTvDensity, isTrue);
  });

  testWidgets(
    'Add portal dialog stays desktop-wide under desktop hybrid focus',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          profile: ShellProfile.desktop,
          child: const PortalFormDialog(pluginId: 'test-iptv'),
        ),
      );
      await tester.pumpAndSettle();

      final dialogSized = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final widths = dialogSized
          .map((w) => w.width)
          .whereType<double>()
          .toList();
      expect(
        widths,
        contains(ShellTokens.shareCodeDialogWidth),
        reason: 'desktop must use shareCodeDialogWidth, not TV shrink',
      );
      expect(
        widths,
        isNot(contains(ShellTokens.shareCodeDialogWidthTv)),
        reason: 'TV dialog width must not apply on desktop hybrid',
      );
    },
  );

  testWidgets(
    'Add portal dialog uses leanback width on TV density',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          profile: ShellProfile.tv,
          child: const PortalFormDialog(pluginId: 'test-iptv'),
        ),
      );
      await tester.pumpAndSettle();

      final dialogSized = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final widths = dialogSized
          .map((w) => w.width)
          .whereType<double>()
          .toList();
      expect(widths, contains(ShellTokens.shareCodeDialogWidthTv));
    },
  );
}
