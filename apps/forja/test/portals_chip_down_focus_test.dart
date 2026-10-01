import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/actions/portals/portals_action_host.dart';
import 'package:forja/shared/engine/runtime/kit/hosts/iptv_catalog_land.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';

void main() {
  const tab = 'hub';

  tearDown(() {
    ShellTvFocusCoordinator.clearTab(tab);
  });

  testWidgets('panel closed ↓ from the chip focuses the remembered channel', (
    tester,
  ) async {
    final category = FocusNode(debugLabel: 'category');
    final first = FocusNode(debugLabel: 'channel-0');
    final remembered = FocusNode(debugLabel: 'channel-1');
    addTearDown(category.dispose);
    addTearDown(first.dispose);
    addTearDown(remembered.dispose);

    shellTvRegisterRow(
      tabId: tab,
      rowId: IptvCatalogLand.catsRowId,
      sortOrder: 1,
      itemCount: 1,
    );
    shellTvRegisterRow(
      tabId: tab,
      rowId: IptvCatalogLand.itemsRowId,
      sortOrder: 2,
      itemCount: 2,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: IptvCatalogLand.catsRowId,
      index: 0,
      node: category,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: IptvCatalogLand.itemsRowId,
      index: 0,
      node: first,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: IptvCatalogLand.itemsRowId,
      index: 1,
      node: remembered,
    );
    ShellTvFocusCoordinator.setRowLastFocusedIndex(
      tab,
      IptvCatalogLand.itemsRowId,
      1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScope(
          profile: ShellProfile.tv,
          config: shellPlatformConfigFor(ShellProfile.tv),
          child: Row(
            children: [
              Focus(
                focusNode: category,
                child: const SizedBox(width: 40, height: 40),
              ),
              Focus(
                focusNode: first,
                child: const SizedBox(width: 40, height: 40),
              ),
              Focus(
                focusNode: remembered,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusRowItemExact(
      tab,
      IptvCatalogLand.catsRowId,
      0,
    ), isTrue);
    await tester.pump();
    expect(category.hasFocus, isTrue);

    expect(PortalsActionHost.focusItemsBelowChip(tab), isTrue);
    await tester.pump();

    expect(remembered.hasFocus, isTrue);
    expect(first.hasFocus, isFalse);
    expect(category.hasFocus, isFalse);
  });

  test('panel closed ↓ does not steal focus when the channel grid is absent', () {
    expect(PortalsActionHost.focusItemsBelowChip(tab), isFalse);
    expect(PortalsActionHost.focusItemsBelowChip(''), isFalse);
  });
}
