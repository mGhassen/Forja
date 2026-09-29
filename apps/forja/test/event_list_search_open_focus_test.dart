import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/runtime/actions/event_search/kit_event_list_search.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

void main() {
  setUpAll(installShellPaintHostAdapters);

  setUp(() {
    ShellTvFocus.currentNavTabId = 'hub';
    ShellTvFocusCoordinator.clearTab('hub');
  });

  tearDown(() {
    ShellTvFocusCoordinator.clearTab('hub');
  });

  testWidgets('open search field takes the shelf neighbor slot', (tester) async {
    final shelf = FocusNode(debugLabel: 'shelf');
    addTearDown(shelf.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ShellScope(
          profile: ShellProfile.tv,
          config: shellPlatformConfigFor(ShellProfile.tv),
          child: Scaffold(
            body: TvKitRow(
              tabId: 'hub',
              rowId: 'chrome',
              sortOrder: 0,
              itemCount: 2,
              child: Row(
                children: [
                  Builder(
                    builder: (context) => shellFocusableTap(
                      context: context,
                      focusNode: shelf,
                      tvTabId: 'hub',
                      tvRowId: 'chrome',
                      tvItemIndex: 0,
                      tvZone: ShellTvZone.topBar,
                      onTap: () {},
                      child: const SizedBox(width: 48, height: 48),
                    ),
                  ),
                  const KitEventListSearch(
                    tooltip: 'Search',
                    placeholder: 'Search',
                    tvItemIndex: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.itemNode('hub', 'chrome', 1)?.debugLabel,
      'event-list-search-tool',
    );

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final field = ShellTvFocusCoordinator.itemNode('hub', 'chrome', 1);
    expect(field?.debugLabel, 'event-list-search');
    expect(field?.canRequestFocus, isTrue);

    shelf.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(field!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(shelf.hasFocus, isTrue);
  });
}
