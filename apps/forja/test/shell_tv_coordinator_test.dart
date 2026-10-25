import 'package:forja/shared/engine/details/poster_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja_foundation/widgets/chrome/shell_chip.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_app_exit.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';

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
    // Same frame hooks bootstrap binds — Back on details needs the overlay pop.
    ShellTvFocusCoordinator.bindFrame(
      playerSurfaceActive: ShellBus.playerSurfaceActive,
      activeShellTabId: () => ShellBus.activeShellTabId,
      overlayCanPop: shellOverlayCanPop,
      overlayMaybePop: maybePopShellOverlay,
    );
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

  testWidgets('row down lands on the same column, not the remembered index', (
    tester,
  ) async {
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
    // Both rows are 40 px tiles from x = 0: A[1] sits over B[1]. B remembered
    // index 2 is only the fallback when B has no mounted geometry.
    expect(nodesB[1].hasFocus, isTrue);
    expect(nodesB[2].hasFocus, isFalse);

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

  testWidgets(
    'FocusableControl scale-1.0 does not paint ink fill unless opted in',
    (tester) async {
      bool hasInkHoverFill() {
        return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((
          d,
        ) {
          final deco = d.decoration;
          return deco is BoxDecoration &&
              deco.color == ForjaShellColors.inkHover;
        });
      }

      final defaultNode = FocusNode(debugLabel: 'scale1-default');
      await tester.pumpWidget(
        _wrapTv(
          FocusableControl(
            focusNode: defaultNode,
            scaleOnFocus: 1.0,
            onTap: () {},
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );
      defaultNode.requestFocus();
      await tester.pump();
      expect(hasInkHoverFill(), isFalse);
      defaultNode.dispose();

      final optInNode = FocusNode(debugLabel: 'scale1-opt-in');
      await tester.pumpWidget(
        _wrapTv(
          FocusableControl(
            focusNode: optInNode,
            scaleOnFocus: 1.0,
            showFocusFill: true,
            onTap: () {},
            child: const SizedBox(width: 200, height: 120),
          ),
        ),
      );
      optInNode.requestFocus();
      await tester.pump();
      expect(hasInkHoverFill(), isTrue);
      optInNode.dispose();
    },
  );

  testWidgets('ForjaShellChip is focusable on tv profile', (tester) async {
    await tester.pumpWidget(
      _wrapTv(ForjaShellChip(label: 'Action', onTap: () {})),
    );
    expect(find.byType(FocusableControl), findsOneWidget);
  });

  testWidgets('MoviePosterCard uses FocusableControl on tv profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapTv(MoviePosterCard(movie: _testMovie(), onTap: () {})),
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
      ),
    );
    await tester.pump();

    homeNav.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    // Overlay route mapping is covered by [_navRestoreTabId] call sites;
    // ShellOverlayNavigator push hangs pump in widget tests — restore the
    // details tab id directly (same path handleNavKey uses after mapping).
    ShellTvFocusCoordinator.restoreTabFocusAfterNav(MediaDetailsTv.tabId);
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    await tester.pump();

    expect(episode.hasFocus, isTrue);
    expect(play.hasFocus, isFalse);
    expect(homeNav.hasFocus, isFalse);

    ShellTvFocusCoordinator.clearTab(MediaDetailsTv.tabId);
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

  testWidgets('nav RIGHT restores row without marking hero Play first', (
    tester,
  ) async {
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final play = FocusNode(debugLabel: 'hero-play');
    final card = FocusNode(debugLabel: 'catalog-card');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';

    shellTvRegisterRow(
      tabId: 'home',
      rowId: 'genre_mystery',
      sortOrder: 5,
      itemCount: 1,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: 'home',
      rowId: 'genre_mystery',
      index: 0,
      node: card,
    );
    ShellTvFocusCoordinator.saveFocus(
      'home',
      ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: 'genre_mystery',
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
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);

    final focused = <String>[];
    void track() {
      final label = FocusManager.instance.primaryFocus?.debugLabel;
      if (label != null) focused.add(label);
    }

    FocusManager.instance.addListener(track);
    expect(
      ShellTvFocusCoordinator.handleNavKey(LogicalKeyboardKey.arrowRight),
      isTrue,
    );
    FocusManager.instance.applyFocusChangesIfNeeded();
    FocusManager.instance.removeListener(track);

    expect(card.hasFocus, isTrue);
    expect(play.hasFocus, isFalse);
    expect(focused, isNot(contains('hero-play')));
    expect(focused, contains('catalog-card'));

    ShellTvFocusCoordinator.clearTab('home');
    homeNav.dispose();
    play.dispose();
    card.dispose();
  });

  testWidgets(
    'nav RIGHT restores details episode after Play pollutes leave memory',
    (tester) async {
      final homeNav = FocusNode(debugLabel: 'nav-home');
      final play = FocusNode(debugLabel: 'hub-details-play');
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
        MediaDetailsTv.tabId,
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
                focusNode: episode,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      episode.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      expect(episode.hasFocus, isTrue);

      // ← to nav freezes episode memory, then Play steals live memory (details
      // autofocus gap) before RIGHT — leave snapshot must win.
      expect(ShellTvFocusCoordinator.focusActiveNavTab(), isTrue);
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      ShellTvFocusCoordinator.saveFocus(
        MediaDetailsTv.tabId,
        ShellTvFocusMemory(zone: ShellTvZone.hero, node: play),
      );

      ShellTvFocusCoordinator.restoreTabFocusAfterNav(MediaDetailsTv.tabId);
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      await tester.pump();

      expect(episode.hasFocus, isTrue);
      expect(play.hasFocus, isFalse);

      ShellTvFocusCoordinator.clearTab(MediaDetailsTv.tabId);
      homeNav.dispose();
      play.dispose();
      episode.dispose();
    },
  );

  testWidgets(
    'restoreTabFocusAfterOverlayPop keeps catalog card if top bar remounts',
    (tester) async {
      final homeNav = FocusNode(debugLabel: 'nav-home');
      final play = FocusNode(debugLabel: 'hero-play');
      final card = FocusNode(debugLabel: 'catalog-card');
      final search = FocusNode(debugLabel: 'top-bar-search');
      ShellTvFocus.registerNav('home', homeNav);
      ShellTvFocus.currentNavTabId = 'home';

      shellTvRegisterRow(
        tabId: 'home',
        rowId: 'featured',
        sortOrder: 0,
        itemCount: 3,
      );
      ShellTvFocusCoordinator.registerItemNode(
        tabId: 'home',
        rowId: 'featured',
        index: 2,
        node: card,
      );
      ShellTvFocusCoordinator.saveFocus(
        'home',
        ShellTvFocusMemory(
          zone: ShellTvZone.row,
          rowId: 'featured',
          itemIndex: 2,
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
                focusNode: search,
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
      search.requestFocus();
      await tester.pump();
      expect(search.hasFocus, isTrue);

      ShellTvFocusCoordinator.captureOverlayReturnFocus();
      ShellTvFocusCoordinator.saveFocus(
        'home',
        ShellTvFocusMemory(zone: ShellTvZone.topBar, node: search),
      );
      ShellTvFocusCoordinator.restoreCapturedOverlayReturnFocus();
      await tester.pump();
      await tester.pump();

      expect(card.hasFocus, isTrue);
      expect(search.hasFocus, isFalse);
      expect(play.hasFocus, isFalse);

      homeNav.dispose();
      play.dispose();
      card.dispose();
      search.dispose();
      ShellTvFocusCoordinator.clearTab('home');
    },
  );

  testWidgets(
    'hero notifyFocused reveals only when landing from another zone',
    (tester) async {
      final play = FocusNode(debugLabel: 'hero-play');
      var revealed = 0;
      ShellTvFocusCoordinator.registerTabDefaults(
        'home',
        defaultFocus: () => play,
        heroReveal: () => revealed++,
      );

      await tester.pumpWidget(
        _wrapTv(
          Focus(focusNode: play, child: const SizedBox(width: 40, height: 40)),
        ),
      );
      await tester.pump();

      const meta = ShellTvFocusMeta(tabId: 'home', zone: ShellTvZone.hero);

      // First land on hero (no prior memory) → reveal once.
      meta.notifyFocused(play);
      expect(revealed, 1);

      // Window focus / resume re-fires focus while still on hero → no yank.
      meta.notifyFocused(play);
      expect(revealed, 1);

      // Leave to a row, then return → reveal again.
      ShellTvFocusCoordinator.saveFocus(
        'home',
        ShellTvFocusMemory(zone: ShellTvZone.row, rowId: 'popular', node: play),
      );
      meta.notifyFocused(play);
      expect(revealed, 2);

      play.dispose();
      ShellTvFocusCoordinator.clearTab('home');
    },
  );

  testWidgets('restoreTabFocus ignores stale nav-only memory', (tester) async {
    final pageNode = FocusNode(debugLabel: 'page-item');
    ShellTvFocusCoordinator.saveFocus(
      'home',
      const ShellTvFocusMemory(zone: ShellTvZone.nav),
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      defaultFocus: () => pageNode,
    );

    await tester.pumpWidget(
      _wrapTv(
        Focus(
          focusNode: pageNode,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();

    expect(ShellTvFocusCoordinator.restoreTabFocus('home'), isTrue);
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    expect(pageNode.hasFocus, isTrue);

    pageNode.dispose();
    ShellTvFocusCoordinator.clearTab('home');
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

  testWidgets(
    'first Back on details pops the overlay — chevron is not an arm step',
    (tester) async {
      ShellTvFocusCoordinator.resetBackDebounceForTest();
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      ShellTvFocus.currentNavTabId = 'home';
      final play = FocusNode(debugLabel: 'details-play');
      final back = FocusNode(debugLabel: 'details-back');
      final scroll = ScrollController();
      addTearDown(() {
        play.dispose();
        back.dispose();
        scroll.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1920, 1080)),
            child: ShellScope(
              profile: ShellProfile.tv,
              config: shellPlatformConfigFor(ShellProfile.tv),
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
          builder: (_) => MediaDetailsTvScope(
            heroPlayFocus: play,
            scrollController: scroll,
            child: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: back,
                    child: const SizedBox(width: 40, height: 40),
                  ),
                  Focus(focusNode: play, child: const Text('Details Play')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      play.requestFocus();
      await tester.pump();
      expect(find.text('Details Play'), findsOneWidget);
      expect(play.hasFocus, isTrue);

      // One press: details gone. Focus must not stop on the Back chevron.
      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Details Play'), findsNothing);
      expect(back.hasFocus, isFalse);
    },
  );

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

  testWidgets(
    'late didPopRoute of a held HW Back is swallowed (press-keyed, not timed)',
    (tester) async {
      ShellTvFocusCoordinator.resetBackDebounceForTest();
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      final homeNav = FocusNode(debugLabel: 'nav-home');
      final page = FocusNode(debugLabel: 'page-item');
      ShellTvFocus.registerNav('home', homeNav);
      ShellTvFocus.currentNavTabId = 'home';
      addTearDown(() {
        homeNav.dispose();
        page.dispose();
      });

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

      // KeyDown handled by ShellTvBackHandler: page → nav rail.
      ShellTvFocusCoordinator.noteHardwareBackDown();
      expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
      await tester.pump();
      expect(homeNav.hasFocus, isTrue);
      expect(ShellTvAppExit.isArmed, isFalse);

      // Key held 1.5 s (emulator lag), then released.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );
      ShellTvFocusCoordinator.noteHardwareBackUp();

      // didPopRoute for the SAME press lands 350 ms after KeyUp — far outside
      // the 80 ms twin / 400 ms debounce windows. Must be paired and ignored.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      expect(ShellTvFocusCoordinator.consumePopRouteTwin(), isTrue);
      // Nothing else ran: a real second Back on the rail would have armed exit.
      expect(ShellTvAppExit.isArmed, isFalse);
      expect(homeNav.hasFocus, isTrue);

      // No pending press left — a bare pop later is a real one.
      expect(ShellTvFocusCoordinator.consumePopRouteTwin(), isFalse);
    },
  );

  testWidgets('two distinct HW Back presses 2 s apart both act', (
    tester,
  ) async {
    ShellTvFocusCoordinator.resetBackDebounceForTest();
    ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
    ShellTvAppExit.debugExitOverride = () async {};
    addTearDown(() => ShellTvAppExit.debugExitOverride = null);
    final homeNav = FocusNode(debugLabel: 'nav-home');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('home', homeNav);
    ShellTvFocus.currentNavTabId = 'home';
    addTearDown(() {
      homeNav.dispose();
      page.dispose();
    });

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

    // Press 1: down (handled) → up → its pop swallowed.
    ShellTvFocusCoordinator.noteHardwareBackDown();
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pump();
    expect(homeNav.hasFocus, isTrue);
    ShellTvFocusCoordinator.noteHardwareBackUp();
    expect(ShellTvFocusCoordinator.consumePopRouteTwin(), isTrue);
    expect(ShellTvAppExit.isArmed, isFalse);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );

    // Press 2: a new physical press acts (rail → arm exit); its pop swallowed.
    ShellTvFocusCoordinator.noteHardwareBackDown();
    expect(ShellTvFocusCoordinator.handleShellBackKey(), isTrue);
    await tester.pump();
    expect(ShellTvAppExit.isArmed, isTrue);
    ShellTvFocusCoordinator.noteHardwareBackUp();
    expect(ShellTvFocusCoordinator.consumePopRouteTwin(), isTrue);
    // Still only armed — the twin did not confirm the quit.
    expect(ShellTvAppExit.isArmed, isTrue);
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

  test(
    'row unregister from stale PageView owner keeps active registration',
    () {
      const tab = 'home';
      const row = MediaDetailsTv.heroRowId;
      final ownerA = Object();
      final ownerB = Object();

      shellTvRegisterRow(
        tabId: tab,
        rowId: row,
        sortOrder: MediaDetailsTv.heroRowSortOrder,
        itemCount: 2,
        owner: ownerA,
      );
      // Active slide registers after (or before) the inactive sibling.
      shellTvRegisterRow(
        tabId: tab,
        rowId: row,
        sortOrder: MediaDetailsTv.heroRowSortOrder,
        itemCount: 2,
        owner: ownerB,
      );
      // Deactivating slide must not wipe the active owner.
      shellTvUnregisterRow(tabId: tab, rowId: row, owner: ownerA);

      expect(ShellTvFocusCoordinator.rowHandle(tab, row), isNotNull);
      expect(ShellTvFocusCoordinator.rowHandle(tab, row)!.itemCount, 2);

      shellTvUnregisterRow(tabId: tab, rowId: row, owner: ownerB);
      expect(ShellTvFocusCoordinator.rowHandle(tab, row), isNull);
    },
  );

  testWidgets('shared hero Play item node survives stale PageView unregister', (
    tester,
  ) async {
    const tab = 'home';
    const row = MediaDetailsTv.heroRowId;
    final play = FocusNode(debugLabel: 'hero-play-shared');
    final pin = FocusNode(debugLabel: 'hero-pin');

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: play,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(focusNode: pin, child: const SizedBox(width: 40, height: 40)),
          ],
        ),
      ),
    );
    await tester.pump();

    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: row,
      index: 0,
      node: play,
    );
    ShellTvFocusCoordinator.registerItemNode(
      tabId: tab,
      rowId: row,
      index: 1,
      node: pin,
    );
    shellTvRegisterRow(
      tabId: tab,
      rowId: row,
      sortOrder: MediaDetailsTv.heroRowSortOrder,
      itemCount: 2,
    );

    // Stale sibling unregisters the shared Play node while it is still
    // attached to the active slide's Focus widget.
    ShellTvFocusCoordinator.unregisterItemNode(
      tabId: tab,
      rowId: row,
      index: 0,
      node: play,
    );
    expect(ShellTvFocusCoordinator.itemNode(tab, row, 0), same(play));

    pin.requestFocus();
    await tester.pump();
    expect(
      ShellTvFocusCoordinator.focusAdjacentInRow(
        tabId: tab,
        rowId: row,
        currentIndex: 1,
        right: false,
      ),
      isTrue,
    );
    await tester.pump();
    expect(play.hasFocus, isTrue);

    play.dispose();
    pin.dispose();
    ShellTvFocusCoordinator.clearTab(tab);
  });

  testWidgets(
    'focusAdjacentInRow → with step 3 lands on index+3, clamps at the end, '
    'and falls back to the farthest mounted card',
    (tester) async {
      const tab = 'test-tab';
      const row = 'test-rail';
      // Items 0..4 mounted; the handle claims 7 so 5 and 6 are "unbuilt".
      final nodes = List.generate(5, (i) => FocusNode(debugLabel: 'card-$i'));

      await tester.pumpWidget(
        _wrapTv(
          Row(
            children: [
              for (final n in nodes)
                Focus(
                  focusNode: n,
                  child: const SizedBox(width: 40, height: 40),
                ),
            ],
          ),
        ),
      );
      await tester.pump();

      for (var i = 0; i < nodes.length; i++) {
        ShellTvFocusCoordinator.registerItemNode(
          tabId: tab,
          rowId: row,
          index: i,
          node: nodes[i],
        );
      }
      shellTvRegisterRow(tabId: tab, rowId: row, sortOrder: 10, itemCount: 7);

      nodes[0].requestFocus();
      await tester.pump();

      // Stride 3 from 0 → 3.
      expect(
        ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tab,
          rowId: row,
          currentIndex: 0,
          right: true,
          step: 3,
        ),
        isTrue,
      );
      await tester.pump();
      expect(nodes[3].hasFocus, isTrue);

      // Stride 3 from 3 → 6 (clamped in range) is unbuilt → farthest mounted (4).
      expect(
        ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tab,
          rowId: row,
          currentIndex: 3,
          right: true,
          step: 3,
        ),
        isTrue,
      );
      await tester.pump();
      expect(nodes[4].hasFocus, isTrue);

      // Stride 3 back from 4 → 1.
      expect(
        ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tab,
          rowId: row,
          currentIndex: 4,
          right: false,
          step: 3,
        ),
        isTrue,
      );
      await tester.pump();
      expect(nodes[1].hasFocus, isTrue);

      // Stride 3 back from 1 clamps to 0.
      expect(
        ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tab,
          rowId: row,
          currentIndex: 1,
          right: false,
          step: 3,
        ),
        isTrue,
      );
      await tester.pump();
      expect(nodes[0].hasFocus, isTrue);

      // Clamp with nowhere to go stays put and still reports handled.
      expect(
        ShellTvFocusCoordinator.focusAdjacentInRow(
          tabId: tab,
          rowId: row,
          currentIndex: 0,
          right: false,
          step: 5,
        ),
        isTrue,
      );
      await tester.pump();
      expect(nodes[0].hasFocus, isTrue);

      for (final n in nodes) {
        n.dispose();
      }
      ShellTvFocusCoordinator.clearTab(tab);
    },
  );

  testWidgets('restoreTabFocusAfterNav falls back when row memory is dead', (
    tester,
  ) async {
    final settingsNav = FocusNode(debugLabel: 'nav-settings');
    final category = FocusNode(debugLabel: 'settings-category');
    ShellTvFocus.registerNav('settings', settingsNav);
    ShellTvFocus.currentNavTabId = 'settings';
    ShellTvFocusCoordinator.setNavOrder(['settings']);

    // Stale empty-shell memory — row was never registered (gate dismissed).
    ShellTvFocusCoordinator.saveFocus(
      'settings',
      const ShellTvFocusMemory(
        zone: ShellTvZone.row,
        rowId: 'empty-shell-cards',
        itemIndex: 0,
      ),
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'settings',
      defaultFocus: () => category,
      restoreFocus: () {
        if (!category.canRequestFocus) return false;
        category.requestFocus();
        return true;
      },
      preferCustomRestoreFromNav: true,
    );

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: settingsNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: category,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    settingsNav.requestFocus();
    await tester.pump();

    ShellTvFocusCoordinator.restoreTabFocusAfterNav('settings');
    FocusManager.instance.applyFocusChangesIfNeeded();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(category.hasFocus, isTrue);
    expect(settingsNav.hasFocus, isFalse);

    settingsNav.dispose();
    category.dispose();
    ShellTvFocusCoordinator.clearTab('settings');
  });

  testWidgets(
    'restoreTabFocusAfterNav drops dead row memory without custom prefer',
    (tester) async {
      final settingsNav = FocusNode(debugLabel: 'nav-settings');
      final category = FocusNode(debugLabel: 'settings-category');
      ShellTvFocus.registerNav('settings', settingsNav);
      ShellTvFocus.currentNavTabId = 'settings';
      ShellTvFocusCoordinator.setNavOrder(['home', 'settings']);

      ShellTvFocusCoordinator.saveFocus(
        'settings',
        const ShellTvFocusMemory(
          zone: ShellTvZone.row,
          rowId: 'empty-shell-cards',
          itemIndex: 0,
        ),
      );
      ShellTvFocusCoordinator.registerTabDefaults(
        'settings',
        defaultFocus: () => category,
      );

      await tester.pumpWidget(
        _wrapTv(
          Row(
            children: [
              Focus(
                focusNode: settingsNav,
                child: const SizedBox(width: 40, height: 40),
              ),
              Focus(
                focusNode: category,
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      settingsNav.requestFocus();
      await tester.pump();

      ShellTvFocusCoordinator.restoreTabFocusAfterNav('settings');
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      await tester.pump();

      expect(category.hasFocus, isTrue);
      expect(settingsNav.hasFocus, isFalse);

      settingsNav.dispose();
      category.dispose();
      ShellTvFocusCoordinator.clearTab('settings');
    },
  );

  testWidgets('focusActiveNavTab no-ops when Settings is the only nav tab', (
    tester,
  ) async {
    final settingsNav = FocusNode(debugLabel: 'nav-settings');
    final page = FocusNode(debugLabel: 'page-item');
    ShellTvFocus.registerNav('settings', settingsNav);
    ShellTvFocus.currentNavTabId = 'settings';
    ShellTvFocusCoordinator.setNavOrder(['settings']);

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: settingsNav,
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

    expect(ShellTvFocusCoordinator.focusActiveNavTab(), isFalse);
    await tester.pump();
    expect(page.hasFocus, isTrue);
    expect(settingsNav.hasFocus, isFalse);

    settingsNav.dispose();
    page.dispose();
  });

  testWidgets('pageBack-only bind keeps Settings enterFromNav + preferCustom', (
    tester,
  ) async {
    final settingsNav = FocusNode(debugLabel: 'nav-settings');
    final category = FocusNode(debugLabel: 'settings-hub-selected');
    var pageBackCalls = 0;
    ShellTvFocus.registerNav('settings', settingsNav);
    ShellTvFocus.currentNavTabId = 'settings';
    ShellTvFocusCoordinator.setNavOrder(['home', 'settings']);

    // SettingsScreen bind, then SettingsHubScaffold pageBack-only merge.
    ShellTvFocusCoordinator.registerTabDefaults(
      'settings',
      defaultFocus: () => category,
      enterFromNavFocus: () {
        if (category.canRequestFocus) category.requestFocus();
      },
      restoreFocus: () {
        if (!category.canRequestFocus) return false;
        category.requestFocus();
        return true;
      },
      preferCustomRestoreFromNav: true,
    );
    ShellTvFocusCoordinator.registerTabDefaults(
      'settings',
      pageBack: () {
        pageBackCalls++;
        return true;
      },
    );

    await tester.pumpWidget(
      _wrapTv(
        Row(
          children: [
            Focus(
              focusNode: settingsNav,
              child: const SizedBox(width: 40, height: 40),
            ),
            Focus(
              focusNode: category,
              child: const SizedBox(width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    settingsNav.requestFocus();
    await tester.pump();

    ShellTvFocusCoordinator.enterTabFromNav('settings');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(category.hasFocus, isTrue);
    expect(settingsNav.hasFocus, isFalse);
    expect(ShellTvFocusCoordinator.tryPageBack('settings'), isTrue);
    expect(pageBackCalls, 1);

    settingsNav.dispose();
    category.dispose();
    ShellTvFocusCoordinator.clearTab('settings');
  });

  testWidgets(
    'enterTabFromNav lands first content when hero defaultFocus missing',
    (tester) async {
      // Catalog hubs omit pack focus.enter and rely on hero CTA — when the
      // hero is unbound/empty, land must still leave the nav rail.
      const tab = 'hub_catalog';
      final nav = FocusNode(debugLabel: 'nav-$tab');
      final card = FocusNode(debugLabel: 'rail-card');
      ShellTvFocus.registerNav(tab, nav);
      ShellTvFocus.currentNavTabId = tab;
      ShellTvFocusCoordinator.setNavOrder(['home', tab]);
      // No enterFromNavFocus / defaultFocus — same as Asian Drama layout omit.

      shellTvRegisterRow(
        tabId: tab,
        rowId: 'latest',
        sortOrder: 1,
        itemCount: 1,
      );
      ShellTvFocusCoordinator.registerItemNode(
        tabId: tab,
        rowId: 'latest',
        index: 0,
        node: card,
      );

      await tester.pumpWidget(
        _wrapTv(
          Row(
            children: [
              Focus(
                focusNode: nav,
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
      nav.requestFocus();
      await tester.pump();
      expect(nav.hasFocus, isTrue);

      ShellTvFocusCoordinator.enterTabFromNav(tab);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(
        card.hasFocus,
        isTrue,
        reason:
            'nav=${nav.hasFocus} primary=${FocusManager.instance.primaryFocus?.debugLabel} anyNav=${ShellTvFocus.anyNavFocused} row=${ShellTvFocusCoordinator.rowHandle(tab, 'latest')?.itemCount}',
      );
      expect(nav.hasFocus, isFalse);

      nav.dispose();
      card.dispose();
      ShellTvFocusCoordinator.clearTab(tab);
    },
  );

  test('clearTabPageBack drops a stale Back ladder', () {
    var calls = 0;
    ShellTvFocusCoordinator.registerTabDefaults(
      'home',
      pageBack: () {
        calls++;
        return true;
      },
    );
    expect(ShellTvFocusCoordinator.tryPageBack('home'), isTrue);
    expect(calls, 1);
    ShellTvFocusCoordinator.clearTabPageBack('home');
    expect(ShellTvFocusCoordinator.tryPageBack('home'), isFalse);
    expect(calls, 1);
    ShellTvFocusCoordinator.clearTab('home');
  });

  testWidgets(
    'handleShellBackKey on Settings-only page arms exit (skips nav)',
    (tester) async {
      ShellTvFocusCoordinator.resetBackDebounceForTest();
      ShellTvFocusCoordinator.tvBackPolicyEnabled = true;
      var exited = 0;
      ShellTvAppExit.debugExitOverride = () async {
        exited++;
      };
      addTearDown(() {
        ShellTvAppExit.debugExitOverride = null;
        ShellTvFocusCoordinator.resetBackDebounceForTest();
      });

      final settingsNav = FocusNode(debugLabel: 'nav-settings');
      final page = FocusNode(debugLabel: 'page-item');
      ShellTvFocus.registerNav('settings', settingsNav);
      ShellTvFocus.currentNavTabId = 'settings';
      ShellTvFocusCoordinator.setNavOrder(['settings']);

      await tester.pumpWidget(
        _wrapTv(
          Row(
            children: [
              Focus(
                focusNode: settingsNav,
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
      expect(settingsNav.hasFocus, isFalse);
      expect(page.hasFocus, isTrue);
      expect(ShellTvAppExit.isArmed, isTrue);
      expect(exited, 0);

      settingsNav.dispose();
      page.dispose();
    },
  );

  testWidgets(
    'shellTvEnsureVisibleItem scrolls outer page past NeverScrollable nest',
    (tester) async {
      final outer = ScrollController();
      final targetKey = GlobalKey();

      await tester.pumpWidget(
        _wrapTv(
          SizedBox(
            width: 400,
            height: 240,
            child: SingleChildScrollView(
              controller: outer,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 12; i++)
                    SizedBox(
                      key: i == 10 ? targetKey : null,
                      height: 64,
                      child: Text('row-$i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(outer.offset, 0);
      final ctx = targetKey.currentContext;
      expect(ctx, isNotNull);
      shellTvEnsureVisibleItem(ctx!);
      await tester.pump();

      expect(
        outer.offset,
        greaterThan(0),
        reason:
            'must scroll the outer SingleChildScrollView, not the '
            'shrink-wrap NeverScrollable ListView nest',
      );

      outer.dispose();
    },
  );

  // --- Column memory (RFC-122 T05): ↑/↓ land on the item nearest in x ---

  group('vertical column memory', () {
    const tab = 'home';

    Widget rowOf(List<FocusNode> nodes, double width, {double leading = 0}) {
      return Row(
        children: [
          if (leading > 0) SizedBox(width: leading),
          for (final n in nodes)
            Focus(
              focusNode: n,
              child: SizedBox(width: width, height: 40),
            ),
        ],
      );
    }

    void register(
      String rowId,
      int sortOrder,
      List<FocusNode> nodes, {
      VoidCallback? onFocusDown,
    }) {
      for (var i = 0; i < nodes.length; i++) {
        ShellTvFocusCoordinator.registerItemNode(
          tabId: tab,
          rowId: rowId,
          index: i,
          node: nodes[i],
        );
      }
      shellTvRegisterRow(
        tabId: tab,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: nodes.length,
        onFocusDown: onFocusDown,
      );
    }

    List<FocusNode> nodesNamed(String prefix, int count) =>
        List.generate(count, (i) => FocusNode(debugLabel: '$prefix-$i'));

    setUp(() => ShellTvFocusCoordinator.clearTab(tab));
    tearDown(() => ShellTvFocusCoordinator.clearTab(tab));

    testWidgets('↓ lands on the nearest-x item, ↑ returns to the origin', (
      tester,
    ) async {
      // A: 8 × 100 px (centers 50 … 750). B: 6 × 120 px (centers 60 … 660).
      final a = nodesNamed('a', 8);
      final b = nodesNamed('b', 6);
      register('col-a', 0, a);
      register('col-b', 1, b);

      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(a, 100), rowOf(b, 120)])),
      );
      await tester.pump();

      // B remembers index 0 — column memory must beat it.
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'col-b', 0);
      a[5].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 5,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      // A[5] center 550 → B[4] center 540 (B[5] is 660).
      expect(b[4].hasFocus, isTrue);
      expect(
        ShellTvFocusCoordinator.rowHandle(tab, 'col-b')!.lastFocusedIndex,
        4,
      );

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-b',
          currentIndex: 4,
          down: false,
        ),
        isTrue,
      );
      await tester.pump();
      // B[4] center 540 → A[5] center 550 (A[4] is 450).
      expect(a[5].hasFocus, isTrue);

      for (final n in [...a, ...b]) {
        n.dispose();
      }
    });

    testWidgets('equidistant items → lower index', (tester) async {
      // A: 8 × 100 (A[1] center 150). B: 6 × 100 offset 50 (centers 100, 200 …).
      final a = nodesNamed('a', 8);
      final b = nodesNamed('b', 6);
      register('col-a', 0, a);
      register('col-b', 1, b);

      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(a, 100), rowOf(b, 100, leading: 50)])),
      );
      await tester.pump();
      a[1].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 1,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(b[0].hasFocus, isTrue);

      for (final n in [...a, ...b]) {
        n.dispose();
      }
    });

    testWidgets('pack focusDown picks the row, column memory picks the item', (
      tester,
    ) async {
      final a = nodesNamed('a', 8);
      final skipped = nodesNamed('s', 8);
      final b = nodesNamed('b', 6);
      // Mirrors the pack edge resolver's default landing (`index: 0`).
      register(
        'col-a',
        0,
        a,
        onFocusDown: () => ShellTvFocusCoordinator.focusRowItemRemembered(
          tab,
          'col-b',
          index: 0,
        ),
      );
      register('col-skipped', 1, skipped);
      register('col-b', 2, b);

      await tester.pumpWidget(
        _wrapTv(
          Column(children: [rowOf(a, 100), rowOf(skipped, 100), rowOf(b, 120)]),
        ),
      );
      await tester.pump();
      a[5].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 5,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(b[4].hasFocus, isTrue, reason: 'hook row, nearest column');
      expect(skipped.any((n) => n.hasFocus), isFalse);

      for (final n in [...a, ...skipped, ...b]) {
        n.dispose();
      }
    });

    testWidgets('setVerticalColumnMemory(false) pins the remembered index', (
      tester,
    ) async {
      final a = nodesNamed('a', 8);
      final b = nodesNamed('b', 6);
      register('col-a', 0, a);
      register('col-b', 1, b);

      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(a, 100), rowOf(b, 120)])),
      );
      await tester.pump();

      ShellTvFocusCoordinator.setVerticalColumnMemory(tab, false);
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'col-b', 1);
      a[5].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 5,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(b[1].hasFocus, isTrue);

      ShellTvFocusCoordinator.setVerticalColumnMemory(tab, true);
      for (final n in [...a, ...b]) {
        n.dispose();
      }
    });

    testWidgets('unmounted target row falls back to its remembered index', (
      tester,
    ) async {
      final a = nodesNamed('a', 8);
      final b = nodesNamed('b', 6);
      register('col-a', 0, a);
      register('col-b', 1, b);

      // B is registered (lazy row) but not in the tree yet.
      await tester.pumpWidget(_wrapTv(Column(children: [rowOf(a, 100)])));
      await tester.pump();
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'col-b', 1);
      a[5].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 5,
          down: true,
        ),
        isTrue,
      );
      // Row mounts during the post-frame retries.
      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(a, 100), rowOf(b, 120)])),
      );
      await tester.pump();
      await tester.pump();
      expect(b[1].hasFocus, isTrue);

      for (final n in [...a, ...b]) {
        n.dispose();
      }
    });

    testWidgets('chip strip ↓ and results ↑ follow the column', (tester) async {
      // Chips: 5 × 160 (centers 80 … 720). Results: 8 × 100 (centers 50 … 750).
      final chips = nodesNamed('chip', 5);
      final results = nodesNamed('res', 8);
      register('chips', 0, chips);
      register('results', 1, results);

      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(chips, 160), rowOf(results, 100)])),
      );
      await tester.pump();

      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'results', 0);
      chips[3].requestFocus();
      await tester.pump();
      ShellTvFocusCoordinator.onRowItemFocused(
        tabId: tab,
        rowId: 'chips',
        index: 3,
        node: chips[3],
        zone: ShellTvZone.chipStrip,
      );

      expect(
        ShellTvFocusCoordinator.focusFromChipStripDown(
          tabId: tab,
          chipRowId: 'chips',
          resultsRowId: 'results',
        ),
        isTrue,
      );
      await tester.pump();
      // chip[3] center 560 → results[5] center 550.
      expect(results[5].hasFocus, isTrue);

      expect(
        ShellTvFocusCoordinator.focusFromResultsRowUp(
          tabId: tab,
          chipRowId: 'chips',
        ),
        isTrue,
      );
      await tester.pump();
      expect(chips[3].hasFocus, isTrue);

      // OK on the selected chip restores results history instead.
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'results', 0);
      expect(
        ShellTvFocusCoordinator.focusFromChipStripDown(
          tabId: tab,
          chipRowId: 'chips',
          resultsRowId: 'results',
          columnMemory: false,
        ),
        isTrue,
      );
      await tester.pump();
      expect(results[0].hasFocus, isTrue);

      for (final n in [...chips, ...results]) {
        n.dispose();
      }
    });

    testWidgets('grid target keeps its remembered tile', (tester) async {
      final a = nodesNamed('a', 8);
      final g = nodesNamed('g', 6);
      register('col-a', 0, a);
      register('grid-b', 1, g);
      ShellTvFocusCoordinator.markRowGrid(tab, 'grid-b');

      await tester.pumpWidget(
        _wrapTv(Column(children: [rowOf(a, 100), rowOf(g, 120)])),
      );
      await tester.pump();
      ShellTvFocusCoordinator.setRowLastFocusedIndex(tab, 'grid-b', 1);
      a[5].requestFocus();
      await tester.pump();

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'col-a',
          currentIndex: 5,
          down: true,
        ),
        isTrue,
      );
      await tester.pump();
      expect(g[1].hasFocus, isTrue, reason: 'grids are not column targets');

      for (final n in [...a, ...g]) {
        n.dispose();
      }
    });

    testWidgets(
      'grid first-row ↑ / last-row ↓ walk the tab graph (episode chips)',
      (tester) async {
        // seasons (row) → episodes (1×N grid) → cast (row). Single-row grids
        // used to trap ↑/↓; details number chips need to leave like cards.
        final seasons = nodesNamed('s', 2);
        final episodes = nodesNamed('e', 4);
        final cast = nodesNamed('c', 3);
        register('seasons', 0, seasons);
        register('episodes', 1, episodes);
        register('cast', 2, cast);
        ShellTvFocusCoordinator.markRowGrid(tab, 'episodes');

        await tester.pumpWidget(
          _wrapTv(
            Column(
              children: [
                rowOf(seasons, 80),
                rowOf(episodes, 60),
                rowOf(cast, 70),
              ],
            ),
          ),
        );
        await tester.pump();
        episodes[1].requestFocus();
        await tester.pump();

        expect(
          ShellTvFocusCoordinator.moveInGrid(
            tabId: tab,
            rowId: 'episodes',
            currentIndex: 1,
            columns: 4,
            rowDelta: -1,
            colDelta: 0,
          ),
          isTrue,
        );
        await tester.pump();
        expect(seasons.any((n) => n.hasFocus), isTrue);

        episodes[1].requestFocus();
        await tester.pump();
        expect(
          ShellTvFocusCoordinator.moveInGrid(
            tabId: tab,
            rowId: 'episodes',
            currentIndex: 1,
            columns: 4,
            rowDelta: 1,
            colDelta: 0,
          ),
          isTrue,
        );
        await tester.pump();
        expect(cast.any((n) => n.hasFocus), isTrue);

        for (final n in [...seasons, ...episodes, ...cast]) {
          n.dispose();
        }
      },
    );

    testWidgets('landed card keeps its visual column — no focus-column scroll', (
      tester,
    ) async {
      // Two leanback rails, viewport 800: padding-left 100, 10 × 100 px cards
      // (content 1100, max scroll 300). FocusableControl aligns a focused
      // card to the leading column on ←/→ — a column-memory landing must not.
      const cards = 10;
      const cardW = 100.0;
      const lead = 100.0;
      final a = nodesNamed('a', cards);
      final b = nodesNamed('b', cards);
      final scrollA = ScrollController();
      final scrollB = ScrollController();

      Widget rail(
        String rowId,
        int sortOrder,
        List<FocusNode> nodes,
        ScrollController scroll,
      ) {
        return TvKitRow(
          tabId: tab,
          rowId: rowId,
          sortOrder: sortOrder,
          itemCount: cards,
          child: SizedBox(
            width: 800,
            height: 120,
            child: ListView.builder(
              controller: scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: lead),
              // Mount every card so far indices can be focused directly.
              // ignore: deprecated_member_use
              cacheExtent: 4000,
              itemCount: cards,
              itemBuilder: (_, i) => FocusableControl(
                focusNode: nodes[i],
                scaleOnFocus: 1.0,
                showFocusBorder: false,
                tvMeta: ShellTvFocusMeta(
                  tabId: tab,
                  zone: ShellTvZone.row,
                  rowId: rowId,
                  itemIndex: i,
                ),
                onTap: () {},
                child: const SizedBox(width: cardW, height: 100),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        _wrapTv(
          Column(
            children: [
              rail('rail-a', 0, a, scrollA),
              rail('rail-b', 1, b, scrollB),
            ],
          ),
        ),
      );
      await tester.pump();

      // ←/→ path: A[7] aligns to the column, clamped at max scroll (300) →
      // A[7] sits at x 500 … 600 (center 550).
      a[7].requestFocus();
      await tester.pumpAndSettle();
      expect(scrollA.offset, 300);
      expect(scrollB.offset, 0);

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'rail-a',
          currentIndex: 7,
          down: true,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      // B[4] (unscrolled: x 500 … 600) is the card under A[7] and B stays put.
      expect(b[4].hasFocus, isTrue);
      expect(scrollB.offset, 0, reason: 'landing must not scroll B');

      expect(
        ShellTvFocusCoordinator.moveVerticalInTab(
          tabId: tab,
          rowId: 'rail-b',
          currentIndex: 4,
          down: false,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(a[7].hasFocus, isTrue, reason: '↑ returns to the origin card');
      expect(scrollA.offset, 300);

      // A plain focus gain afterwards aligns again (marker was consumed).
      b[2].requestFocus();
      await tester.pumpAndSettle();
      expect(scrollB.offset, greaterThan(0));

      scrollA.dispose();
      scrollB.dispose();
      for (final n in [...a, ...b]) {
        n.dispose();
      }
    });
  });
}
