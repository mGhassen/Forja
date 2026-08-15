import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/design/src/forja_shell_chip.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/shell_tv_app_exit.dart';
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
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvFocus.clearNavRegistrationsForTest();
    ShellTvFocusCoordinator.setNavOrder(['home', 'search', 'settings']);
    ShellTvFocus.currentNavTabId = 'home';
    ShellTvFocusCoordinator.resetBackDebounceForTest();
  });

  testWidgets('focusActiveNavTab requests current tab node', (tester) async {
    final home = FocusNode(debugLabel: 'nav-home');
    ShellTvFocus.registerNav('home', home);

    await tester.pumpWidget(
      _wrapTv(
        Focus(focusNode: home, child: const SizedBox(width: 40, height: 40)),
      ),
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

  testWidgets('nav vertical skips unregistered holes after async reload', (
    tester,
  ) async {
    final home = FocusNode(debugLabel: 'nav-home');
    final settings = FocusNode(debugLabel: 'nav-settings');
    ShellTvFocusCoordinator.setNavOrder(['home', 'search', 'settings']);
    ShellTvFocus.registerNav('home', home);
    // `search` intentionally missing — simulates FocusNode not yet remounted.
    ShellTvFocus.registerNav('settings', settings);

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Focus(focusNode: home, child: const SizedBox(height: 40)),
            Focus(focusNode: settings, child: const SizedBox(height: 40)),
          ],
        ),
      ),
    );
    await tester.pump();
    home.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.focusNextNavItem(), isTrue);
    await tester.pump();
    expect(settings.hasFocus, isTrue);

    home.dispose();
    settings.dispose();
  });

  testWidgets('row down restores next row focus history', (tester) async {
    final nodes = List.generate(3, (i) => FocusNode(debugLabel: 'a-$i'));
    final nodesB = List.generate(3, (i) => FocusNode(debugLabel: 'b-$i'));

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
      sortOrder: 2,
      itemCount: 3,
    );

    await tester.pumpWidget(
      _wrapTv(
        Column(
          children: [
            Row(
              children: nodes
                  .map(
                    (n) => Focus(
                      focusNode: n,
                      child: const SizedBox(width: 40, height: 40),
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: nodesB
                  .map(
                    (n) => Focus(
                      focusNode: n,
                      child: const SizedBox(width: 40, height: 40),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    ShellTvFocusCoordinator.onRowItemFocused(
      tabId: 'home',
      rowId: 'row-b',
      index: 2,
      node: nodesB[2],
    );
    nodes[1].requestFocus();
    await tester.pump();

    expect(
      ShellTvFocusCoordinator.moveVerticalInTab(
        tabId: 'home',
        rowId: 'row-a',
        currentIndex: 1,
        down: true,
      ),
      isTrue,
    );
    await tester.pump();
    expect(nodesB[2].hasFocus, isTrue);

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

  testWidgets('FocusableControl activates on select key when focused', (
    tester,
  ) async {
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

  testWidgets('HomeMovieCard uses FocusableControl on tv profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapTv(HomeMovieCard(movie: _testMovie(), onTap: () {})),
    );
    expect(find.byType(FocusableControl), findsAtLeastNWidgets(1));
  });

  testWidgets('hero row left edge focuses active nav tab', (tester) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final play = FocusNode(debugLabel: 'details-play');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    ShellTvFocusCoordinator.registerItemNode(
      tabId: MediaDetailsTv.tabId,
      rowId: MediaDetailsTv.heroRowId,
      index: 0,
      node: play,
    );
    shellTvRegisterRow(
      tabId: MediaDetailsTv.tabId,
      rowId: MediaDetailsTv.heroRowId,
      sortOrder: MediaDetailsTv.heroRowSortOrder,
      itemCount: 1,
    );

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            FocusableControl(
              focusNode: play,
              tvMeta: const ShellTvFocusMeta(
                tabId: MediaDetailsTv.tabId,
                zone: ShellTvZone.row,
                rowId: MediaDetailsTv.heroRowId,
                itemIndex: 0,
              ),
              onTap: () {},
              child: const SizedBox(width: 100, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    play.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(homeNav.hasFocus, isTrue);
    expect(play.hasFocus, isFalse);

    homeNav.dispose();
    play.dispose();
  });

  testWidgets('non-hero row left edge stays trapped at first item', (
    tester,
  ) async {
    final first = FocusNode(debugLabel: 'first-rec');
    ShellTvFocus.currentNavTabId = 'home';
    shellTvRegisterRow(
      tabId: MediaDetailsTv.tabId,
      rowId: 'recommendations',
      sortOrder: 0,
      itemCount: 1,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: MediaDetailsTv.tabId,
      rowId: 'recommendations',
      index: 0,
      node: first,
    );

    await tester.pumpWidget(
      _wrapTv(
        FocusableControl(
          focusNode: first,
          tvMeta: const ShellTvFocusMeta(
            tabId: MediaDetailsTv.tabId,
            zone: ShellTvZone.row,
            rowId: 'recommendations',
            itemIndex: 0,
          ),
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pump();
    first.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(first.hasFocus, isTrue);
    first.dispose();
  });

  testWidgets('row-bound FocusableControl traps RIGHT at last item', (
    tester,
  ) async {
    final last = FocusNode(debugLabel: 'last-card');
    ShellTvFocus.currentNavTabId = 'home';
    shellTvRegisterRow(
      tabId: 'home',
      rowId: 'featured',
      sortOrder: 0,
      itemCount: 2,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: 'home',
      rowId: 'featured',
      index: 0,
      node: FocusNode(debugLabel: 'first-card'),
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: 'home',
      rowId: 'featured',
      index: 1,
      node: last,
    );

    await tester.pumpWidget(
      _wrapTv(
        FocusableControl(
          focusNode: last,
          tvMeta: const ShellTvFocusMeta(
            tabId: 'home',
            zone: ShellTvZone.row,
            rowId: 'featured',
            itemIndex: 1,
          ),
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    await tester.pump();
    last.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(last.hasFocus, isTrue);
    last.dispose();
  });

  testWidgets('nav RIGHT restores page focus after nav visit', (tester) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final pageNode = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    ShellTvFocusCoordinator.saveFocus(
      'home',
      ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: 'featured',
        itemIndex: 2,
        node: pageNode,
      ),
    );

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: pageNode,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    homeNav.requestFocus();
    await tester.pump();

    ShellTvFocusCoordinator.saveFocus(
      'home',
      const ShellTvFocusMemory(zone: ShellTvZone.nav),
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => pageNode,
    );

    expect(
      ShellTvFocusCoordinator.handleNavKey(LogicalKeyboardKey.arrowRight),
      isTrue,
    );
    await tester.pump();
    await tester.pump();
    expect(pageNode.hasFocus, isTrue);
    expect(homeNav.hasFocus, isFalse);

    homeNav.dispose();
    pageNode.dispose();
  });

  testWidgets('nav RIGHT restores media-details memory while overlay open', (
    tester,
  ) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final play = FocusNode(debugLabel: 'details-play');
    final episode = FocusNode(debugLabel: 'details-ep');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    shellTvRegisterRow(
      tabId: MediaDetailsTv.tabId,
      rowId: 'episodes',
      sortOrder: 1,
      itemCount: 1,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: MediaDetailsTv.tabId,
      rowId: 'episodes',
      index: 0,
      node: episode,
    );
    ShellTvFocusCoordinator.saveFocus(
      MediaDetailsTv.tabId,
      ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: 'episodes',
        itemIndex: 0,
        node: episode,
      ),
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => play,
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      MediaDetailsTv.tabId,
      defaultFocus: () => play,
    );

    await tester.pumpWidget(
      _wrapTv(
        Stack(
          children: [
            Row(
              children: [
                Focus(
                  focusNode: homeNav,
                  child: const SizedBox(width: 40, height: 40),
                ),
                Focus(
                  focusNode: play,
                  child: const SizedBox(width: 40, height: 40),
                ),
                Focus(
                  focusNode: episode,
                  child: const SizedBox(width: 40, height: 40),
                ),
              ],
            ),
            const Positioned.fill(child: ShellOverlayNavigator()),
          ],
        ),
      ),
    );
    await tester.pump();

    final overlay = shellOverlayNavigatorKey.currentState!;
    await overlay.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(shellOverlayCanPop(), isTrue);

    homeNav.requestFocus();
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    expect(
      ShellTvFocusCoordinator.handleNavKey(LogicalKeyboardKey.arrowRight),
      isTrue,
    );
    await tester.pump();
    await tester.pump();

    expect(episode.hasFocus, isTrue);
    expect(play.hasFocus, isFalse);
    expect(homeNav.hasFocus, isFalse);

    homeNav.dispose();
    play.dispose();
    episode.dispose();
  });

  testWidgets(
    'restoreTabFocusAfterNav keeps snapshot if Play pollutes memory',
    (tester) async {
      final homeNav = FocusNode(debugLabel: 'nav-home');
      final play = FocusNode(debugLabel: 'hero-play');
      final card = FocusNode(debugLabel: 'catalog-card');
      ShellTvFocus.registerNav('home', homeNav);
      ShellTvFocus.currentNavTabId = 'home';

      shellTvRegisterRow(
        tabId: 'home',
        rowId: 'featured',
        sortOrder: 0,
        itemCount: 1,
      );
      ShellTvFocusCoordinator.registerItemNode(
        tabId: 'home',
        rowId: 'featured',
        index: 0,
        node: card,
      );
      ShellTvFocusCoordinator.saveFocus(
        'home',
        ShellTvFocusMemory(
          zone: ShellTvZone.row,
          rowId: 'featured',
          itemIndex: 0,
          node: card,
        ),
      );
      ShellTvFocusCoordinator.registerTabDefaults(
        'home',
        defaultFocus: () => play,
      );

      await tester.pumpWidget(
        _wrapTv(
          Row(
            children: [
              Focus(
                focusNode: homeNav,
                child: const SizedBox(width: 40, height: 40),
              ),
              Focus(
                focusNode: play,
                child: const SizedBox(width: 40, height: 40),
              ),
              Focus(
                focusNode: card,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      homeNav.requestFocus();
      await tester.pump();

      // Snapshot is taken inside restore; pollute live memory the same way
      // Play autofocus used to (hero overwrites row) before post-frame passes.
      ShellTvFocusCoordinator.restoreTabFocusAfterNav('home');
      ShellTvFocusCoordinator.saveFocus(
        'home',
        ShellTvFocusMemory(zone: ShellTvZone.hero, node: play),
      );
      await tester.pump();
      await tester.pump();

      expect(card.hasFocus, isTrue);
      expect(play.hasFocus, isFalse);

      homeNav.dispose();
      play.dispose();
      card.dispose();
    },
  );

  test('restoreTabFocus ignores stale nav-only memory', () {
    final pageNode = FocusNode(debugLabel: 'page-item');
    ShellTvFocusCoordinator.saveFocus(
      'home',
      const ShellTvFocusMemory(zone: ShellTvZone.nav),
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => pageNode,
    );

    expect(ShellTvFocusCoordinator.restoreTabFocus('home'), isTrue);

    pageNode.dispose();
  });

  testWidgets('handleShellBackKey focuses active nav from page content', (
    tester,
  ) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: page,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    page.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    homeNav.dispose();
    page.dispose();
  });

  testWidgets('handleShellBackKey on nav: first Back arms exit', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    var exited = 0;
    ShellTvAppExit.debugExitOverride = () async {
      exited++;
    };
    addTearDown(ShellTvFocusCoordinator.resetBackDebounceForTest);

    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => page,
    );
    addTearDown(() {
      ShellTvFocusCoordinator.unregisterTabDefaults('home');
      homeNav.dispose();
      page.dispose();
    });

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              autofocus: true,
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: page,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(ShellTvAppExit.isArmed, isTrue);
    expect(exited, 0);

    // Same-press duplicate (HardwareKeyboard + didPopRoute) must not quit.
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(exited, 0);
    expect(ShellTvAppExit.isArmed, isTrue);
  });

  testWidgets('handleShellExitKey: first Exit arms without quitting', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    var exited = 0;
    ShellTvAppExit.debugExitOverride = () async {
      exited++;
    };
    addTearDown(ShellTvFocusCoordinator.resetBackDebounceForTest);

    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: page,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    page.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.handleShellExitKey(), isTrue);
    expect(ShellTvAppExit.isArmed, isTrue);
    expect(exited, 0);

    expect(ShellTvFocusCoordinator.handleShellExitKey(), isTrue);
    expect(exited, 0);

    homeNav.dispose();
    page.dispose();
  });

  testWidgets('handleShellBackKey always consumes on root page', (
    tester,
  ) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item', skipTraversal: true);
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: page,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    page.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    homeNav.dispose();
    page.dispose();
  });

  testWidgets('handleShellBackKey pops shell overlay before nav focus', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvFocus.currentNavTabId = 'home';

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: ShellScope(
            profile: ShellProfile.mobile,
            config: shellPlatformConfigFor(ShellProfile.mobile),
            child: const Stack(
              children: [SizedBox.expand(), ShellOverlayNavigator()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('tv back policy absorbs duplicate back within debounce window', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: homeNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: page,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    page.requestFocus();
    await tester.pump();

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    expect(homeNav.hasFocus, isTrue);

    homeNav.dispose();
    page.dispose();
  });

  testWidgets('tv back policy never returns false on page content', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvFocus.currentNavTabId = null;

    await tester.pumpWidget(
      _wrapTv(
        Focus(
          focusNode: FocusNode(debugLabel: 'orphan-page'),
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
  });

  testWidgets('claimHeroPlayAfterPlayerExit focuses Play when page empty', (
    tester,
  ) async {
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    final play = FocusNode(debugLabel: 'details-hero-play');
    final other = FocusNode(debugLabel: 'other');

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: play,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: other,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    other.requestFocus();
    await tester.pump();
    other.unfocus();
    await tester.pump();
    expect(play.hasFocus, isFalse);

    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      play,
      isMounted: () => true,
    );
    await tester.pump();
    await tester.pump();

    expect(play.hasFocus, isTrue);

    play.dispose();
    other.dispose();
  });

  testWidgets('claimHeroPlayAfterPlayerExit always reclaims Play', (
    tester,
  ) async {
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    final play = FocusNode(debugLabel: 'details-hero-play');
    final episode = FocusNode(debugLabel: 'episode');

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: play,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: episode,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    episode.requestFocus();
    await tester.pump();

    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      play,
      isMounted: () => true,
    );
    await tester.pump();
    await tester.pump();

    expect(play.hasFocus, isTrue);
    expect(episode.hasFocus, isFalse);

    play.dispose();
    episode.dispose();
  });

  testWidgets('claimHeroPlayAfterPlayerExit skip leaves Play unfocused', (
    tester,
  ) async {
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    final play = FocusNode(debugLabel: 'details-hero-play');

    await tester.pumpWidget(
      _wrapTv(
        Focus(focusNode: play, child: const SizedBox(width: 40, height: 40)),
      ),
    );
    await tester.pump();
    play.unfocus();
    await tester.pump();

    ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
      play,
      isMounted: () => true,
      skip: () => true,
    );
    await tester.pump();
    await tester.pump();

    expect(play.hasFocus, isFalse);

    play.dispose();
  });
}
