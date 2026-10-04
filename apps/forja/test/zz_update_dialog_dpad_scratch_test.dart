import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/update/update_dialog.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_keyboard_focus.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shared/services/update/app_updater_release_notes.dart';
import 'package:forja/shared/services/update/app_updater_service.dart';

void main() {
  for (final profile in [ShellProfile.tv, ShellProfile.desktop])
  testWidgets('update dialog dpad \$profile', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    late BuildContext host;
    final shellNodes = [for (var i = 0; i < 3; i++) FocusNode(debugLabel: 'shell-\$i')];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final config = shellPlatformConfigFor(profile);
          Widget body = child!;
          if (config.inputPolicy.scaleOnHover) {
            body = ShellKeyboardFocusHost(child: body);
          }
          return ShellScope(
            profile: profile,
            config: config,
            child: ShellInputPolicy.maybeWrapFocusTraversal(
              enabled: config.inputPolicy.wrapAppFocusTraversal,
              child: body,
            ),
          );
        },
        home: Builder(
          builder: (c) {
            host = c;
            return Column(
              children: [
                for (var i = 0; i < 3; i++)
                  ForjaInteractive(
                    focusNode: shellNodes[i],
                    autoFocus: i == 0,
                    onTap: () {},
                    builder: (_, _) => const SizedBox(width: 200, height: 60),
                  ),
              ],
            );
          },
        ),
      ),
    );
    final info = UpdateInfo(
      currentVersion: '2.0.17',
      latestVersion: '2.0.18',
      downloadUrl: 'https://x',
      changelogs: const [
        VersionChangelog(version: '2.0.18', body: '- **Fix:** a\n- **Add:** b'),
        VersionChangelog(version: '2.0.17', body: '- **Fix:** c'),
      ],
      fullChangelogUrl: 'https://x/changelog',
      publishedAt: DateTime.now(),
      isMacOS: false,
    );
    UpdateDialog.show(host, info);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    String label() =>
        FocusManager.instance.primaryFocus?.debugLabel ?? 'null';
    // ignore: avoid_print
    print('\$profile initial: ${label()}');
    shellNodes[1].requestFocus(); // shell autofocus under the gate
    await tester.pump(const Duration(milliseconds: 100));
    print('after shell steal: ${label()}');
    for (final k in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ]) {
      await tester.sendKeyEvent(k);
      await tester.pump(const Duration(milliseconds: 100));
      // ignore: avoid_print
      print('after ${k.keyLabel}: ${label()}');
    }
  });
}
