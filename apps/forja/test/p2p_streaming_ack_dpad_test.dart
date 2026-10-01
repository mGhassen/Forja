import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

void main() {
  testWidgets(
    'SettingsFilledButton onRightEdge / onLeftEdge moves focus under '
    'app-root DirectionalFocus no-op',
    (tester) async {
      final left = FocusNode(debugLabel: 'dlg-cancel');
      final right = FocusNode(debugLabel: 'dlg-confirm');

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellInputPolicy.maybeWrapFocusTraversal(
                enabled: true,
                child: Scaffold(
                  body: TvOverlayScope(
                    autofocusFirst: false,
                    child: ShellTvContainDpad(
                      child: Row(
                        children: [
                          SettingsFilledButton(
                            label: 'Cancel',
                            secondary: true,
                            focusNode: left,
                            onPressed: () {},
                            onRightEdge: () {
                              if (right.canRequestFocus) right.requestFocus();
                            },
                          ),
                          SettingsFilledButton(
                            label: 'I am aware',
                            focusNode: right,
                            onPressed: () {},
                            onLeftEdge: () {
                              if (left.canRequestFocus) left.requestFocus();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      left.requestFocus();
      await tester.pump();
      expect(left.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(right.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(left.hasPrimaryFocus, isTrue);

      left.dispose();
      right.dispose();
    },
  );
}
