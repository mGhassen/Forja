import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';

FocusNode? _nodeByLabel(String label) {
  FocusNode? hit;
  void walk(FocusNode n) {
    if (hit != null) return;
    if (n.debugLabel == label) {
      hit = n;
      return;
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(FocusManager.instance.rootScope);
  return hit;
}

Widget _packsHarness({required int packCount}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: Builder(
          builder: (context) {
            return ShellInputPolicy.maybeWrapFocusTraversal(
              enabled: true,
              child: Scaffold(
                body: ShellTvContainDpad(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < packCount; i++)
                          settingsExpandableWithSideActions(
                            context: context,
                            storageId: 'pack-$i',
                            leading: const Icon(Icons.bolt),
                            title: Text('pack-$i'),
                            onHeaderActivate: () {},
                            trailing: const SizedBox(width: 40, height: 40),
                            children: const [SizedBox(height: 8)],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Forja Packs details chevron: ↓ moves focus (no stuck settings-pack-details)',
    (tester) async {
      await tester.pumpWidget(_packsHarness(packCount: 2));
      await tester.pumpAndSettle();

      final details = _nodeByLabel('settings-pack-details');
      expect(details, isNotNull);
      details!.requestFocus();
      await tester.pump();
      expect(details.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(details.hasFocus, isFalse);
      expect(
        identical(FocusManager.instance.primaryFocus, details),
        isFalse,
        reason: '↓ from details must leave this chevron node (issue 490)',
      );
    },
  );

  testWidgets('Forja Packs details chevron: KeyRepeat ↓ does not stay stuck', (
    tester,
  ) async {
    await tester.pumpWidget(_packsHarness(packCount: 3));
    await tester.pumpAndSettle();

    final details = _nodeByLabel('settings-pack-details');
    expect(details, isNotNull);
    details!.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(details.hasFocus, isFalse);
    expect(
      identical(FocusManager.instance.primaryFocus, details),
      isFalse,
      reason: 'KeyRepeat ↓ must not leave focus stuck on this details chevron',
    );
  });
}
