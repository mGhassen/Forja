import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_body.dart';
import 'package:forja/shell/shell_bottom_nav.dart';
import 'package:forja/shell/shell_nav_rail.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/shell_top_bar.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/forja_profile_avatar.dart';
import 'package:rust/src/settings_service.dart';

Widget _wrapShellScope(
  Widget child, {
  ShellProfile profile = ShellProfile.desktop,
  Size size = const Size(1200, 800),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size, padding: padding),
      child: ShellScope(
        profile: profile,
        config: shellPlatformConfigFor(profile),
        child: child,
      ),
    ),
  );
}

void main() {
  const visibleIds = ['home', 'search', 'settings'];

  setUp(() {
    ShellBus.homeCategory.value = null;
    ShellBus.homeSelectedGenreId.value = null;
    ShellBus.homeHeroHeight.value = 0;
    ShellBus.homeScrollOffset.value = 0;
    ShellBus.selectedWatchProviderId.value = null;
    ShellBus.homeProviderMenuVisible.value = false;
    ShellBus.requestTab.value = null;
    ShellBus.selectDefaultTabOnNextNavLoad = false;
    ShellBus.shellOverlayHasPage.value = false;
  });

  Future<void> pumpScaffold(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 800),
    ShellProfile profile = ShellProfile.mobile,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrapShellScope(child, profile: profile, size: size),
    );
  }

  ShellScaffold desktopScaffold({
    bool hideGlobalNav = false,
    Widget? shellTopBar,
    int selectedIndex = 1,
  }) {
    return ShellScaffold(
      useNavRail: true,
      visibleIds: visibleIds,
      selectedIndex: selectedIndex,
      mountedTabIds: const {'home', 'search'},
      onDestinationSelected: (_) {},
      tabFor: (id) => Center(child: Text(id)),
      hideGlobalNav: hideGlobalNav,
      shellTopBar: shellTopBar,
    );
  }

  testWidgets('ShellScaffold shows bottom nav on portrait mobile', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
  });

  testWidgets('ShellScaffold hides bottom nav when hideGlobalNav is true', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
        hideGlobalNav: true,
      ),
    );

    expect(find.byType(ShellBottomNav), findsNothing);
  });

  testWidgets('ShellScaffold shows rail on desktop; top bar only when passed', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(ShellNavRail), findsOneWidget);
    expect(find.byType(HomeTopBar), findsNothing);
    expect(find.byType(ShellBottomNav), findsNothing);
    expect(find.text('Films'), findsNothing);
  });

  testWidgets('ShellScaffold shows home top bar when shellTopBar is set', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(HomeTopBar), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('TV Shows'), findsOneWidget);
  });

  testWidgets('HomeTopBar Categories menu sets genre filter', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeSelectedGenreId.value, 'action');
  });

  testWidgets('HomeTopBar Films tap toggles homeCategory filter', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(ShellBus.homeCategory.value, isNull);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, ShellHomeCategory.films);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.homeCategory.value, isNull);
  });

  testWidgets('HomeTopBar shows provider rail when menu visible', (
    tester,
  ) async {
    ShellBus.homeProviderMenuVisible.value = true;
    await pumpScaffold(
      tester,
      desktopScaffold(
        shellTopBar: const HomeTopBar(),
        selectedIndex: 0,
      ),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pump();

    expect(find.byType(HomeWatchProviderRail), findsOneWidget);
  });

  testWidgets('HomeTopBar shows selected provider logo before Films', (
    tester,
  ) async {
    ShellBus.selectedWatchProviderId.value = 8; // Netflix
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pump();

    expect(find.byType(HomeSelectedWatchProviderLogo), findsOneWidget);
  });

  testWidgets('HomeTopBar slides away after scrolling past hero height', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    Offset hideOffset() {
      final transforms = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(HomeTopBar),
              matching: find.byType(Transform),
            ),
          )
          .toList();
      expect(transforms, isNotEmpty);
      final t = transforms.first.transform.getTranslation();
      return Offset(t.x, t.y);
    }

    ShellBus.homeHeroHeight.value = 400;
    ShellBus.homeScrollOffset.value = 0;
    await tester.pump();
    expect(hideOffset().dy, 0);

    // hideStart = heroHeight - barHeight; fully hidden well past that.
    ShellBus.homeScrollOffset.value = 2000;
    await tester.pump();
    expect(hideOffset().dy, lessThan(0));
  });

  testWidgets('ShellScaffold hides home top bar when shell overlay has page', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const HomeTopBar()),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.text('Films'), findsOneWidget);

    shellOverlayNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isTrue);

    shellOverlayNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(ShellBus.shellOverlayHasPage.value, isFalse);
  });

  testWidgets(
    'ShellScaffold dismisses shell overlay when nav destination selected',
    (tester) async {
      await pumpScaffold(
        tester,
        desktopScaffold(),
        size: const Size(1200, 800),
        profile: ShellProfile.desktop,
      );

      shellOverlayNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pumpAndSettle();

      expect(ShellBus.shellOverlayHasPage.value, isTrue);
      expect(find.text('Details'), findsOneWidget);

      await tester.tap(
        find.image(const AssetImage('assets/images/nav/home.png')),
      );
      await tester.pumpAndSettle();

      expect(ShellBus.shellOverlayHasPage.value, isFalse);
      expect(find.text('Details'), findsNothing);
    },
  );

  testWidgets(
    'ShellScaffold collapses nav rail to left menu on home when narrow',
    (tester) async {
      await pumpScaffold(
        tester,
        desktopScaffold(shellTopBar: const HomeTopBar()),
        size: const Size(800, 800),
      );

      expect(find.byType(ShellNavRail), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      final menuCenter = tester.getCenter(find.byIcon(Icons.menu_rounded));
      expect(menuCenter.dx, lessThan(120));

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ShellNavRail), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/nav/search.png')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ShellNavRail uses fixed width without hover expand', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final railFinder = find.byType(ShellNavRail);
    expect(tester.getSize(railFinder).width, ShellTokens.navRailWidth);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('ShellNavRail reveals label after sustained hover', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final searchIcon = find.image(
      const AssetImage('assets/images/nav/search.png'),
    );
    expect(searchIcon, findsOneWidget);
    expect(find.text('Search'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(searchIcon));
    await tester.pump();
    await tester.pump(ShellTokens.navRailLabelRevealDelay);
    for (var i = 0; i < 12; i++) {
      await tester.pump(ShellTokens.navRailLabelLetterInterval);
    }
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(
      tester
          .widget<NavDestinationIcon>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is NavDestinationIcon &&
                  widget.destination.id == 'search',
            ),
          )
          .color,
      navDestinationAccentColors['search'],
    );

    final searchItem = find.ancestor(
      of: searchIcon,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.height != null &&
            w.width == ShellTokens.navRailWidth,
      ),
    );
    expect(searchItem, findsWidgets);
  });

  testWidgets('desktop menu icon is grey idle and colored on hover', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pumpAndSettle();

    Finder homeIconWidget() => find.byWidgetPredicate(
      (widget) =>
          widget is NavDestinationIcon && widget.destination.id == 'home',
    );
    final homeImage = find.image(
      const AssetImage('assets/images/nav/home.png'),
    );
    expect(
      tester.widget<NavDestinationIcon>(homeIconWidget()).color,
      ForjaShellColors.iconMuted,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(homeImage));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavDestinationIcon>(homeIconWidget()).color,
      navDestinationAccentColors['home'],
    );
  });

  testWidgets('desktop selected underline keeps its icon accent on hover', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pumpAndSettle();

    final searchImage = find.image(
      const AssetImage('assets/images/nav/search.png'),
    );
    final underline = find.byKey(const ValueKey('nav-search-underline'));
    Color underlineColor() =>
        (tester.widget<AnimatedContainer>(underline).decoration
                as BoxDecoration)
            .color!;

    expect(underlineColor(), navDestinationAccentColors['search']);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(searchImage));
    await tester.pumpAndSettle();

    expect(underlineColor(), navDestinationAccentColors['search']);
  });

  testWidgets('TV selected nav icon uses destination accent at desktop size', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1920, 1080),
      profile: ShellProfile.tv,
    );
    await tester.pumpAndSettle();

    final searchIcon = tester.widget<NavDestinationIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is NavDestinationIcon && widget.destination.id == 'search',
      ),
    );
    expect(searchIcon.color, navDestinationAccentColors['search']);
    expect(searchIcon.size, ShellTokens.navRailIconSize);

    final underline = find.byKey(const ValueKey('nav-search-underline'));
    final underlineColor =
        (tester.widget<AnimatedContainer>(underline).decoration
                as BoxDecoration)
            .color!;
    expect(underlineColor, navDestinationAccentColors['search']);
  });

  testWidgets('TV nav rail fits all enabled tabs without scrolling', (
    tester,
  ) async {
    const manyIds = [
      'search',
      'home',
      'asian_drama',
      'anime',
      'iptv',
      'live_matches',
      'mylist',
      'settings',
    ];
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: true,
        visibleIds: manyIds,
        selectedIndex: 0,
        mountedTabIds: manyIds.toSet(),
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
      ),
      size: const Size(1280, 720),
      profile: ShellProfile.tv,
    );
    await tester.pumpAndSettle();

    for (final id in manyIds) {
      if (id == 'settings') continue;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is NavDestinationIcon && widget.destination.id == id,
        ),
        findsOneWidget,
        reason: '$id should be visible on 720p TV rail',
      );
    }

    final avatar = tester.widget<ForjaProfileAvatar>(
      find.byType(ForjaProfileAvatar),
    );
    expect(avatar.size, ShellTokens.navRailIconSize * ShellTokens.navRailProfileAvatarScaleTv);
    expect(avatar.size, lessThan(ShellTokens.navRailIconSize * ShellTokens.navRailProfileAvatarScaleDesktop));
  });

  testWidgets('desktop profile avatar is grey idle and colored on hover', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pumpAndSettle();

    final greyMarker = find.byKey(const ValueKey('nav-profile-avatar-grey'));
    expect(greyMarker, findsOneWidget);
    final avatarFinder = find.byType(ForjaProfileAvatar);
    final avatar = tester.widget<ForjaProfileAvatar>(avatarFinder);
    expect(avatar.showBorder, isFalse);
    expect(
      avatar.size,
      shellNavRailIconSize(tester.element(find.byType(ShellNavRail))) *
          shellNavRailProfileAvatarScale(
            tester.element(find.byType(ShellNavRail)),
          ),
    );
    final avatarScale = tester.widget<AnimatedScale>(
      find
          .ancestor(
            of: avatarFinder,
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(avatarScale.scale, 1);
    expect(find.text('Guest'), findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(avatarFinder));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('nav-profile-avatar-color')),
      findsOneWidget,
    );
    // Hover must not remount the avatar (would flash default forge artwork).
    expect(find.byType(ForjaProfileAvatar), findsOneWidget);
    expect(
      tester.widget<ForjaProfileAvatar>(avatarFinder).avatarKey,
      avatar.avatarKey,
    );
  });

  testWidgets(
    'desktop profile avatar keeps the same artwork across rapid hover',
    (tester) async {
      await pumpScaffold(
        tester,
        desktopScaffold(),
        size: const Size(1200, 800),
        profile: ShellProfile.desktop,
      );
      await tester.pumpAndSettle();

      final avatarFinder = find.byType(ForjaProfileAvatar);
      final avatarKey = tester
          .widget<ForjaProfileAvatar>(avatarFinder)
          .avatarKey;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final center = tester.getCenter(avatarFinder);
      for (var i = 0; i < 8; i++) {
        await gesture.moveTo(center);
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveTo(center + const Offset(80, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(find.byType(ForjaProfileAvatar), findsOneWidget);
      expect(
        tester.widget<ForjaProfileAvatar>(avatarFinder).avatarKey,
        avatarKey,
      );
      expect(
        find.byKey(const ValueKey('nav-profile-avatar-grey')),
        findsOneWidget,
      );
    },
  );

  testWidgets('ShellScaffold body is inset by fixed rail width', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
    expect(bodyBox.size.width, 1200 - ShellTokens.navRailWidth);
  });

  testWidgets('ShellScaffold TV profile applies system overscan inset once', (
    tester,
  ) async {
    const systemOverscan = 24.0;
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrapShellScope(
        desktopScaffold(),
        profile: ShellProfile.tv,
        size: const Size(1920, 1080),
        padding: const EdgeInsets.symmetric(horizontal: systemOverscan),
      ),
    );
    await tester.pumpAndSettle();

    final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
    expect(
      bodyBox.size.width,
      1920 - ShellTokens.navRailWidth - systemOverscan * 2,
    );

    final railBox = tester.renderObject<RenderBox>(find.byType(ShellNavRail));
    expect(railBox.localToGlobal(Offset.zero).dx, systemOverscan);
  });

  testWidgets('ShellScaffold keeps rail Offstage when hideGlobalNav is true', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(hideGlobalNav: true),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    // Keep-alive: rail Element stays mounted so player exit does not remount.
    final rail = find.byType(ShellNavRail, skipOffstage: false);
    expect(rail, findsOneWidget);
    expect(find.byType(ShellNavRail), findsNothing);
    final offstage = tester
        .widgetList<Offstage>(find.byType(Offstage, skipOffstage: false))
        .firstWhere((o) => o.offstage);
    expect(offstage.offstage, isTrue);
    expect(find.byType(HomeTopBar), findsNothing);
  });

  testWidgets(
    'ShellScaffold collapses rail gutter when hideGlobalNav is true',
    (tester) async {
      await pumpScaffold(
        tester,
        desktopScaffold(hideGlobalNav: true),
        size: const Size(1200, 800),
        profile: ShellProfile.desktop,
      );

      final bodyBox = tester.renderObject<RenderBox>(find.byType(ShellBody));
      expect(bodyBox.size.width, 1200);
    },
  );

  testWidgets(
    'ForjaGhostButton is text-only; ForjaPlainIcon has no border box',
    (tester) async {
      await pumpScaffold(
        tester,
        Scaffold(
          body: Row(
            children: [
              ForjaGhostButton(label: 'Watch Now', onTap: () {}),
              ForjaPlainIcon(icon: Icons.info_outline, onTap: () {}),
            ],
          ),
        ),
        size: const Size(600, 200),
      );

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.byType(ForjaPlainIcon), findsOneWidget);
      expect(find.byType(ForjaIconButton), findsNothing);
    },
  );

  testWidgets(
    'ForjaPlainIcon and ForjaCloseButton use circular hover, no border',
    (tester) async {
      await pumpScaffold(
        tester,
        const Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ForjaPlainIcon(icon: Icons.tune_rounded, onTap: null),
              ForjaCloseButton(onTap: null),
            ],
          ),
        ),
        size: const Size(200, 120),
      );

      final borderFinder = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      );
      expect(borderFinder, findsNothing);

      final circleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circleFinder, findsWidgets);
    },
  );

  testWidgets('ShellBottomNav is flat without BackdropFilter', (tester) async {
    await pumpScaffold(
      tester,
      ShellScaffold(
        useNavRail: false,
        visibleIds: visibleIds,
        selectedIndex: 0,
        mountedTabIds: const {'home'},
        onDestinationSelected: (_) {},
        tabFor: (id) => Center(child: Text(id)),
      ),
    );

    expect(find.byType(ShellBottomNav), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  test('ForjaShellColors uses dark shell palette', () {
    expect(ForjaShellColors.textPrimary, const Color(0xFFE5E7EB));
    expect(ForjaShellColors.cinematic.textPrimary, const Color(0xFFE5E7EB));
  });

  testWidgets(
    'ShellBody keeps tab State when a nav tab is enabled (visibleIds grow)',
    (tester) async {
      var settingsInits = 0;
      final settingsStates = <State>[];

      Widget tabFor(String id) {
        if (id == 'settings') {
          return _CountingTab(
            onInit: (state) {
              settingsInits += 1;
              settingsStates.add(state);
            },
          );
        }
        return Center(child: Text(id));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ShellBody(
            selectedIndex: 2,
            visibleIds: const ['home', 'search', 'settings'],
            mountedTabIds: const {'home', 'search', 'settings'},
            tabFor: tabFor,
          ),
        ),
      );
      await tester.pump();
      expect(settingsInits, 1);
      final firstState = settingsStates.single;

      // Enabling a tab inserts before settings - same as navbar config save.
      await tester.pumpWidget(
        MaterialApp(
          home: ShellBody(
            selectedIndex: 3,
            visibleIds: const ['home', 'search', 'anime', 'settings'],
            mountedTabIds: const {'home', 'search', 'settings'},
            tabFor: tabFor,
          ),
        ),
      );
      await tester.pump();

      expect(settingsInits, 1);
      expect(settingsStates.single, same(firstState));
      expect(find.text('settings-alive'), findsOneWidget);
    },
  );

  testWidgets(
    'ShellBody selected tab receives taps when later tabs stay mounted',
    (tester) async {
      // Repro: IPTV (or any mid-list tab) looked frozen after visiting a later
      // tab - hidden siblings kept maintainInteractivity and stole hit tests.
      var iptvTaps = 0;
      var settingsTaps = 0;

      Widget tabFor(String id) {
        if (id == 'iptv') {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => iptvTaps += 1,
            child: const SizedBox.expand(child: Text('iptv-catalog')),
          );
        }
        if (id == 'settings') {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => settingsTaps += 1,
            child: const SizedBox.expand(child: Text('settings-panel')),
          );
        }
        return Center(child: Text(id));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ShellBody(
            selectedIndex: 0,
            visibleIds: const ['iptv', 'settings'],
            mountedTabIds: const {'iptv', 'settings'},
            tabFor: tabFor,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('iptv-catalog'));
      await tester.pump();

      expect(iptvTaps, 1);
      expect(settingsTaps, 0);
    },
  );

  test('navDestinations includes default shell tabs', () {
    expect(navDestinations.containsKey('home'), isTrue);
    expect(navDestinations.containsKey('search'), isTrue);
    expect(navDestinations.containsKey('asian_drama'), isTrue);
    expect(navDestinations.containsKey('anime'), isTrue);
    expect(navDestinations.containsKey('iptv'), isTrue);
    expect(navDestinations.containsKey('live_matches'), isTrue);
    expect(navDestinations.containsKey('mylist'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(SettingsService.defaultVisibleNavIds, [
      'home',
      'asian_drama',
      'anime',
      'iptv',
      'live_matches',
      'mylist',
    ]);
  });

  test('temporarily hidden nav ids stay registered but are withheld', () {
    for (final id in temporarilyHiddenNavIds) {
      expect(navDestinations.containsKey(id), isTrue);
      expect(navTabBuilders.containsKey(id), isTrue);
    }
    expect(
      temporarilyHiddenNavIds.intersection(
        SettingsService.defaultVisibleNavIds.toSet(),
      ),
      isEmpty,
    );
  });
}

class _CountingTab extends StatefulWidget {
  const _CountingTab({required this.onInit});

  final void Function(State<StatefulWidget> state) onInit;

  @override
  State<_CountingTab> createState() => _CountingTabState();
}

class _CountingTabState extends State<_CountingTab> {
  @override
  void initState() {
    super.initState();
    widget.onInit(this);
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('settings-alive'));
  }
}
