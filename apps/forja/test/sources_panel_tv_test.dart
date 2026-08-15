import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';

Widget _wrapTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(child: child),
      ),
    ),
  );
}

void main() {
  setUp(() {
    ShellTvFocusCoordinator.clearTab(SourcesPanelTv.tabId);
  });

  testWidgets('claimFocus focuses kind once the node is registered', (
    tester,
  ) async {
    final kind = FocusNode(debugLabel: 'sources-kind');

    await tester.pumpWidget(
      _wrapTv(
        Focus(focusNode: kind, child: const SizedBox(width: 40, height: 40)),
      ),
    );
    await tester.pump();

    ShellTvFocusCoordinator.registerItemNode(
      tabId: SourcesPanelTv.tabId,
      rowId: SourcesPanelTv.kindRowId,
      index: 0,
      node: kind,
    );

    SourcesPanelTv.claimFocus();
    await tester.pump();
    expect(kind.hasFocus, isTrue);

    kind.dispose();
  });

  testWidgets('claimFocus prefers list over kind when list is ready', (
    tester,
  ) async {
    final kind = FocusNode(debugLabel: 'sources-kind');
    final list = FocusNode(debugLabel: 'sources-list');

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Focus(
              focusNode: kind,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: list,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    ShellTvFocusCoordinator.registerItemNode(
      tabId: SourcesPanelTv.tabId,
      rowId: SourcesPanelTv.kindRowId,
      index: 0,
      node: kind,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: SourcesPanelTv.tabId,
      rowId: SourcesPanelTv.listRowId,
      index: 0,
      node: list,
    );

    SourcesPanelTv.claimFocus(listIndex: 0);
    await tester.pump();
    expect(list.hasFocus, isTrue);
    expect(kind.hasFocus, isFalse);

    kind.dispose();
    list.dispose();
  });
}
