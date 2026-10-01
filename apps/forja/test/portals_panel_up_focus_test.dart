import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_panel_tv.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';

void main() {
  const tab = 'hub';

  tearDown(() {
    PortalsPanelTvFocus.unbindChip(tabId: tab, rowId: 'chrome', index: 2);
    ShellTvFocusCoordinator.clearTab(tab);
  });

  testWidgets('panel action up focuses the portals chip, not the shelf', (
    tester,
  ) async {
    final shelf = FocusNode(debugLabel: 'shelf');
    final chip = FocusNode(debugLabel: 'portals-chip');
    addTearDown(shelf.dispose);
    addTearDown(chip.dispose);

    PortalsPanelTvFocus.bindChip(tabId: tab, rowId: 'chrome', index: 2);
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: 'chrome',
      index: 0,
      node: shelf,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: 'chrome',
      index: 2,
      node: chip,
    );
    shellTvRegisterRow(
      tabId: tab,
      rowId: 'chrome',
      sortOrder: -1,
      itemCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScope(
          profile: ShellProfile.tv,
          config: shellPlatformConfigFor(ShellProfile.tv),
          child: Row(
            children: [
              Focus(focusNode: shelf, child: const SizedBox(width: 40, height: 40)),
              Focus(focusNode: chip, child: const SizedBox(width: 40, height: 40)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusRowItemExact(tab, 'chrome', 0), isTrue);
    await tester.pump();
    expect(shelf.hasFocus, isTrue);

    PortalsPanelTvFocus(tabId: tab).exitUpToChip();
    await tester.pump();

    expect(chip.hasFocus, isTrue);
    expect(shelf.hasFocus, isFalse);
  });
}
