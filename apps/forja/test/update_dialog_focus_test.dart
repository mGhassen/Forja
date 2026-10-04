import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/services/update/app_updater_release_notes.dart';
import 'package:forja/shared/services/update/app_updater_service.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shell/update/update_dialog.dart';

UpdateInfo _info() => UpdateInfo(
  currentVersion: '2.0.17',
  latestVersion: '2.0.18',
  downloadUrl: 'https://example.com/forja.apk',
  changelogs: const [
    VersionChangelog(version: '2.0.18', body: '- **Fix:** a\n- **Add:** b'),
    VersionChangelog(version: '2.0.17', body: '- **Fix:** c'),
  ],
  fullChangelogUrl: 'https://example.com/changelog',
  publishedAt: DateTime.now(),
  isMacOS: false,
);

void main() {
  testWidgets('TV update gate keeps D-pad focus when the shell below grabs it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final shellNodes = [
      for (var i = 0; i < 2; i++) FocusNode(debugLabel: 'shell-$i'),
    ];
    addTearDown(() {
      for (final node in shellNodes) {
        node.dispose();
      }
    });
    late BuildContext host;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final config = shellPlatformConfigFor(ShellProfile.tv);
          return ShellScope(
            profile: ShellProfile.tv,
            config: config,
            child: ShellInputPolicy.maybeWrapFocusTraversal(
              enabled: config.inputPolicy.wrapAppFocusTraversal,
              child: child!,
            ),
          );
        },
        home: Builder(
          builder: (context) {
            host = context;
            return Column(
              children: [
                for (final node in shellNodes)
                  ForjaInteractive(
                    focusNode: node,
                    onTap: () {},
                    builder: (_, _) => const SizedBox(width: 200, height: 60),
                  ),
              ],
            );
          },
        ),
      ),
    );

    UpdateDialog.show(host, _info());
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    String? primary() => FocusManager.instance.primaryFocus?.debugLabel;
    expect(primary(), 'update-install');

    // Cold start: the shell mounts under the gate and claims focus.
    shellNodes[1].requestFocus();
    await tester.pump();
    expect(primary(), 'update-install');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(primary(), 'update-skip');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(primary(), 'update-install');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(primary(), 'update-changelog');
  });
}
