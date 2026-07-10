import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/design/src/forja_shell_chip.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/home_movie_card.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

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

Movie _testMovie() => Movie(
      id: 1,
      title: 'Test',
      posterPath: '',
      backdropPath: '',
      voteAverage: 0,
      releaseDate: '2024',
      overview: '',
      mediaType: 'movie',
    );

void main() {
  setUp(() {
    ShellTvFocusCoordinator.setNavOrder(['home', 'search', 'settings']);
    ShellTvFocus.currentNavTabId = 'home';
  });

  testWidgets('focusActiveNavTab requests current tab node', (tester) async {
    final home = FocusNode(debugLabel: 'nav-home');
    ShellTvFocus.registerNav('home', home);

    await tester.pumpWidget(
      _wrapTv(Focus(focusNode: home, child: const SizedBox(width: 40, height: 40))),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusActiveNavTab(), isTrue);
    await tester.pump();
    expect(home.hasFocus, isTrue);

    home.dispose();
  });

  testWidgets('nav vertical chain stops at last item', (tester) async {
    final home = FocusNode(debugLabel: 'nav-home');
    final search = FocusNode(debugLabel: 'nav-search');
    final settings = FocusNode(debugLabel: 'nav-settings');
    ShellTvFocus.registerNav('home', home);
    ShellTvFocus.registerNav('search', search);
    ShellTvFocus.registerNav('settings', settings);

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Focus(focusNode: home, child: const SizedBox(height: 40)),
            Focus(focusNode: search, child: const SizedBox(height: 40)),
            Focus(focusNode: settings, child: const SizedBox(height: 40)),
          ],
        ),
      ),
    );
    await tester.pump();
    settings.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusNextNavItem(), isFalse);
    expect(settings.hasFocus, isTrue);

    home.dispose();
    search.dispose();
    settings.dispose();
  });

  testWidgets('row down preserves column index', (tester) async {
    final nodes = List.generate(3, (i) => FocusNode(debugLabel: 'a-$i'));
    final nodesB = List.generate(2, (i) => FocusNode(debugLabel: 'b-$i'));

    for (var i = 0; i < nodes.length; i++) {
      ShellTvFocusCoordinator.registerItemNode(
        tabId: 'home',
        rowId: 'row-a',
        index: i,
        node: nodes[i],
      );
    }
    for (var i = 0; i < nodesB.length; i++) {
      ShellTvFocusCoordinator.registerItemNode(
        tabId: 'home',
        rowId: 'row-b',
        index: i,
        node: nodesB[i],
      );
    }

    shellTvRegisterRow(
      tabId: 'home',
      rowId: 'row-a',
      sortOrder: 0,
      itemCount: 3,
    );
    shellTvRegisterRow(
      tabId: 'home',
      rowId: 'row-b',
      sortOrder: 1,
      itemCount: 2,
    );

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Row(
              children: nodes
                  .map((n) => Focus(focusNode: n, child: const SizedBox(width: 40, height: 40)))
                  .toList(),
            ),
            Row(
              children: nodesB
                  .map((n) => Focus(focusNode: n, child: const SizedBox(width: 40, height: 40)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    nodes[2].requestFocus();
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.moveVerticalInTab(
        tabId: 'home',
        rowId: 'row-a',
        currentIndex: 2,
        down: true,
      ),
      isTrue,
    );
    await tester.pump();
    expect(nodesB[1].hasFocus, isTrue);

    for (final n in [...nodes, ...nodesB]) {
      n.dispose();
    }
  });

  test('shellTvIsActivateKey recognizes select and enter', () {
    expect(
      shellTvIsActivateKey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.select,
          logicalKey: LogicalKeyboardKey.select,
          timeStamp: Duration.zero,
        ),
      ),
      isTrue,
    );
    expect(
      shellTvIsActivateKey(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('FocusableControl activates on select key when focused', (tester) async {
    var tapped = false;
    final focusNode = FocusNode();
    await tester.pumpWidget(
      _wrapTv(
        FocusableControl(
          focusNode: focusNode,
          onTap: () => tapped = true,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pump();
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(tapped, isTrue);
    focusNode.dispose();
  });

  testWidgets('ForjaShellChip is focusable on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapTv(ForjaShellChip(label: 'Action', onTap: () {})),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('HomeMovieCard uses FocusableControl on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapTv(HomeMovieCard(movie: _testMovie(), onTap: () {})),
    );
    expect(find.byType(FocusableControl), findsAtLeastNWidgets(1));
  });
}
