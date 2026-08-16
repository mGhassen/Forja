import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

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

FocusableControl _listTile(FocusNode node, int index) {
  return FocusableControl(
    focusNode: node,
    scaleOnFocus: 1.0,
    tvMeta: ShellTvFocusMeta(
      tabId: SourcesPanelTv.tabId,
      zone: ShellTvZone.row,
      rowId: SourcesPanelTv.listRowId,
      itemIndex: index,
    ),
    onTap: () {},
    child: const SizedBox(width: 80, height: 40),
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

  testWidgets('vertical sources list: ↓ moves to the next tile', (tester) async {
    final a = FocusNode(debugLabel: 'sources-list-0');
    final b = FocusNode(debugLabel: 'sources-list-1');

    await tester.pumpWidget(
      _wrapTv(
        TvOverlayScope(
          autofocusFirst: false,
          debugLabel: 'sources-panel-tv',
          child: TvCatalogRow(
            tabId: SourcesPanelTv.tabId,
            rowId: SourcesPanelTv.listRowId,
            sortOrder: SourcesPanelTv.listSort,
            itemCount: 2,
            orientation: ShellTvRowOrientation.vertical,
            child: Column(
              children: [_listTile(a, 0), _listTile(b, 1)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    a.requestFocus();
    await tester.pump();
    expect(a.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(b.hasFocus, isTrue, reason: '↓ must leave sources-list-0');

    a.dispose();
    b.dispose();
  });

  testWidgets(
    'vertical sources list: ↓ still moves after the row handle is gone',
    (tester) async {
      final a = FocusNode(debugLabel: 'sources-list-0');
      final b = FocusNode(debugLabel: 'sources-list-1');

      await tester.pumpWidget(
        _wrapTv(
          TvOverlayScope(
            autofocusFirst: false,
            debugLabel: 'sources-panel-tv',
            child: Column(
              children: [_listTile(a, 0), _listTile(b, 1)],
            ),
          ),
        ),
      );
      await tester.pump();

      // Player file picker / Sources overlay unregistered the shared row.
      shellTvUnregisterRow(
        tabId: SourcesPanelTv.tabId,
        rowId: SourcesPanelTv.listRowId,
      );
      expect(
        ShellTvFocusCoordinator.rowHandle(
          SourcesPanelTv.tabId,
          SourcesPanelTv.listRowId,
        ),
        isNull,
      );

      a.requestFocus();
      await tester.pump();
      expect(a.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        b.hasFocus,
        isTrue,
        reason: 'missing sources-list handle must not swallow ↓',
      );

      a.dispose();
      b.dispose();
    },
  );
}

