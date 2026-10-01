import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_row.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

void main() {
  setUpAll(installShellPaintHostAdapters);

  testWidgets(
    'PortalListRow main stays on portals row after → into actions',
    (tester) async {
      const tab = 'iptv-test';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
              child: ShellPaintTvTabScope(
                tabId: tab,
                child: TvKitRow(
                  tabId: tab,
                  rowId: 'portals',
                  sortOrder: 1,
                  itemCount: 1,
                  orientation: ShellTvRowOrientation.vertical,
                  child: PortalListRow(
                    leanback: true,
                    listIndex: 0,
                    item: const PortalListItem(
                      id: 'p1',
                      label: 'Portal One',
                      subtitle: 'xtream',
                    ),
                    onFavorite: () {},
                    onCopyShareCode: () async => 'ABCD-EFGH',
                    onEdit: () {},
                    onDelete: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = ShellTvFocusCoordinator.rowHandle(tab, 'portals');
      expect(handle, isNotNull);
      expect(handle!.itemCount, 1);

      final main = handle.nodeAt(0);
      expect(main, isNotNull);
      main!.requestFocus();
      await tester.pump();
      expect(main.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Action chrome may own focus, but portals row must still register the
      // main tile (reveal must not remaps it onto portal-0-actions).
      final after = ShellTvFocusCoordinator.rowHandle(tab, 'portals');
      expect(after, isNotNull);
      expect(after!.nodeAt(0), same(main));
      expect(
        ShellTvFocusCoordinator.rowHandle(tab, 'portal-0-actions'),
        isNotNull,
        reason: 'action chrome registers under portal-N-actions',
      );
    },
  );
}
