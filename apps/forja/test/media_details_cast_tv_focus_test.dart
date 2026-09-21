import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/details/media_details_cast_section.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/shell_paint_host_install.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

Widget _wrapDetailsTv(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(1920, 1080)),
      child: ShellScope(
        profile: ShellProfile.tv,
        config: shellPlatformConfigFor(ShellProfile.tv),
        child: FocusScope(
          child: TvFocusGraph(
            tabId: MediaDetailsTv.tabId,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(installShellPaintHostAdapters);

  setUp(() {
    ShellTvFocusCoordinator.setNavOrder([MediaDetailsTv.tabId]);
    ShellTvFocus.currentNavTabId = MediaDetailsTv.tabId;
    ShellTvFocusCoordinator.clearTab(MediaDetailsTv.tabId);
  });

  testWidgets('MediaDetailsCastSection registers cast and crew TV rows',
      (tester) async {
    const cast = [
      {'name': 'A', 'character': 'Lead', 'profilePath': ''},
      {'name': 'B', 'character': 'Support', 'profilePath': ''},
    ];
    const crew = [
      {'name': 'C', 'character': 'Director', 'profilePath': ''},
    ];

    await tester.pumpWidget(
      _wrapDetailsTv(
        Column(
          children: [
            MediaDetailsCastSection(
              cast: cast,
              title: 'Characters',
              tvTabId: MediaDetailsTv.tabId,
              tvRowId: 'cast',
              tvRowOrder: 1,
            ),
            MediaDetailsCastSection(
              cast: crew,
              title: 'Crew',
              tvTabId: MediaDetailsTv.tabId,
              tvRowId: 'crew',
              tvRowOrder: 2,
            ),
            TvKitRow(
              tabId: MediaDetailsTv.tabId,
              rowId: 'trailers',
              sortOrder: 3,
              itemCount: 1,
              child: FocusableControl(
                tvMeta: const ShellTvFocusMeta(
                  tabId: MediaDetailsTv.tabId,
                  zone: ShellTvZone.row,
                  rowId: 'trailers',
                  itemIndex: 0,
                ),
                onTap: () {},
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.rowHandle(MediaDetailsTv.tabId, 'cast'),
      isNotNull,
    );
    expect(
      ShellTvFocusCoordinator.rowHandle(MediaDetailsTv.tabId, 'cast')!
          .itemCount,
      2,
    );
    expect(
      ShellTvFocusCoordinator.rowHandle(MediaDetailsTv.tabId, 'crew'),
      isNotNull,
    );
    expect(
      ShellTvFocusCoordinator.rowHandle(MediaDetailsTv.tabId, 'crew')!
          .itemCount,
      1,
    );

    final castNode = ShellTvFocusCoordinator.itemNode(
      MediaDetailsTv.tabId,
      'cast',
      0,
    );
    final crewNode = ShellTvFocusCoordinator.itemNode(
      MediaDetailsTv.tabId,
      'crew',
      0,
    );
    final trailerNode = ShellTvFocusCoordinator.itemNode(
      MediaDetailsTv.tabId,
      'trailers',
      0,
    );
    expect(castNode, isNotNull);
    expect(crewNode, isNotNull);
    expect(trailerNode, isNotNull);

    castNode!.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, castNode);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, crewNode);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, trailerNode);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, crewNode);
  });

  testWidgets('MediaDetailsCastSection without tvRowId does not register',
      (tester) async {
    await tester.pumpWidget(
      _wrapDetailsTv(
        const MediaDetailsCastSection(
          cast: [
            {'name': 'A', 'character': 'Lead', 'profilePath': ''},
          ],
          title: 'Cast',
        ),
      ),
    );
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.rowHandle(MediaDetailsTv.tabId, 'cast'),
      isNull,
    );
  });
}
