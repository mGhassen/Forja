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
import 'package:forja/shared/catalog/forja_host_assets.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/hub_catalog_top_bar.dart';
import 'package:forja/shared/catalog/shell/catalog_vertical_filters_rail.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_pack_filters.dart';
import 'package:forja/shared/catalog/shell/catalog_vertical_filters.dart';
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
  const hubA = 'test_hub_a';
  const hubB = 'test_hub_b';
  const hubC = 'test_hub_c';
  const visibleIds = [hubA, hubB, 'settings'];

  void seedHomePackFilters() {
    CatalogPackFiltersRegistry.seedFromJson('test-provider-a', {
      'menus': [
        {
          'id': 'films',
          'label': 'Films',
          'filter': {'op': 'eq', 'field': 'type', 'value': 'movie'},
          'hideTypeFilterRails': true,
        },
        {
          'id': 'series',
          'label': 'Series',
          'filter': {'op': 'eq', 'field': 'type', 'value': 'tv'},
          'hideTypeFilterRails': true,
        },
      ],
      'fields': [
        {
          'field': 'genre',
          'options': [
            {'id': 'action', 'label': 'Action'},
          ],
        },
      ],
    });
  }

  void seedHomeVerticalFilters() {
    CatalogVerticalFiltersRegistry.register(
      CatalogVerticalFiltersSpec(
        widgetId: 'watch_providers',
        tabId: hubA,
        pluginId: 'test-provider-a',
        packSourceUrl: '',
        showSelectedInTopBar: true,
        options: [
          CatalogVerticalFilterOption(
            id: 'netflix',
            label: 'Netflix',
            logo: 'assets/watch_providers/netflix.svg',
            tileColor: const Color(0xFF000000),
            filter: CatalogFilterAst.eq('watch_provider', 8),
          ),
        ],
      ),
    );
  }

  setUp(() {
    PluginNavRegistry.seedTestHubNav(
      destinations: {
        hubA: const NavDestination(
          id: hubA,
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'Hub A',
          iconAsset: ForjaHostAssets.flutterNavHome,
        ),
        hubB: const NavDestination(
          id: hubB,
          icon: Icons.animation_outlined,
          activeIcon: Icons.animation,
          label: 'Hub B',
          iconAsset: ForjaHostAssets.flutterNavAnime,
        ),
        hubC: const NavDestination(
          id: hubC,
          icon: Icons.theater_comedy_outlined,
          activeIcon: Icons.theater_comedy,
          label: 'Hub C',
          iconAsset: ForjaHostAssets.flutterNavAsianDrama,
        ),
      },
    );
    CatalogVerticalFiltersRegistry.clearForTest();
    CatalogPackFiltersRegistry.clearForTest();
    seedHomePackFilters();
    seedHomeVerticalFilters();
    ShellBus.hubSelectedMenuIdFor(hubA).value = null;
    ShellBus.hubSelectedCategoryIdFor(hubA).value = null;
    ShellBus.hubHeroHeightFor(hubA).value = 0;
    ShellBus.hubScrollOffsetFor(hubA).value = 0;
    ShellBus.selectedWatchProviderId.value = null;
    CatalogVerticalFiltersRegistry.menuVisibleFor(hubA).value = false;
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
      mountedTabIds: const {hubA, hubB},
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
        mountedTabIds: const {hubA},
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
        mountedTabIds: const {hubA},
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
    expect(find.byType(PluginHubCatalogTopBar), findsNothing);
    expect(find.byType(ShellBottomNav), findsNothing);
    expect(find.text('Films'), findsNothing);
  });

  testWidgets('ShellScaffold shows home top bar when shellTopBar is set', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(find.byType(PluginHubCatalogTopBar), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
  });

  testWidgets(
    'PluginHubCatalogTopBar drops Films when tabId changes to hub without chrome',
    (tester) async {
      // hubA has vertical filters → VOD chrome. hubB has none. State must not
      // keep painting Search/Films after a hub switch (Live Sports regression).
      await pumpScaffold(
        tester,
        desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
        size: const Size(1200, 800),
        profile: ShellProfile.desktop,
      );
      expect(find.text('Films'), findsOneWidget);

      await pumpScaffold(
        tester,
        desktopScaffold(
          shellTopBar: PluginHubCatalogTopBar(
            key: ValueKey(hubB),
            tabId: hubB,
          ),
        ),
        size: const Size(1200, 800),
        profile: ShellProfile.desktop,
      );
      await tester.pump();

      expect(find.text('Films'), findsNothing);
      expect(find.text('Series'), findsNothing);
      expect(find.text('Search'), findsNothing);
    },
  );

  testWidgets('PluginHubCatalogTopBar Categories menu sets genre filter', (tester) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    expect(ShellBus.hubSelectedCategoryIdFor(hubA).value, 'action');
  });

  testWidgets('PluginHubCatalogTopBar Films tap toggles pack menu id', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    expect(ShellBus.hubSelectedMenuIdFor(hubA).value, isNull);

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.hubSelectedMenuIdFor(hubA).value, 'films');

    await tester.tap(find.text('Films'));
    await tester.pumpAndSettle();

    expect(ShellBus.hubSelectedMenuIdFor(hubA).value, isNull);
  });

  testWidgets('PluginHubCatalogTopBar shows provider rail when menu visible', (
    tester,
  ) async {
    CatalogVerticalFiltersRegistry.menuVisibleFor(hubA).value = true;
    await pumpScaffold(
      tester,
      desktopScaffold(
        shellTopBar: const PluginHubCatalogTopBar(tabId: hubA),
        selectedIndex: 0,
      ),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pump();

    expect(find.byType(CatalogVerticalFiltersRail), findsOneWidget);
  });

  testWidgets('PluginHubCatalogTopBar shows selected provider logo before Films', (
    tester,
  ) async {
    ShellBus.selectedWatchProviderId.value = 8; // legacy — logo uses registry
    CatalogVerticalFiltersRegistry.selectedIdFor(hubA).value = 'netflix';
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );
    await tester.pump();

    expect(find.byType(CatalogVerticalFilterTopBarLogo), findsOneWidget);
  });

  testWidgets('PluginHubCatalogTopBar slides away after scrolling past hero height', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
      size: const Size(1200, 800),
      profile: ShellProfile.desktop,
    );

    Offset hideOffset() {
      final transforms = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(PluginHubCatalogTopBar),
              matching: find.byType(Transform),
            ),
          )
          .toList();
      expect(transforms, isNotEmpty);
      final t = transforms.first.transform.getTranslation();
      return Offset(t.x, t.y);
    }

    ShellBus.hubHeroHeightFor(hubA).value = 400;
    ShellBus.hubScrollOffsetFor(hubA).value = 0;
    await tester.pump();
    expect(hideOffset().dy, 0);

    // hideStart = heroHeight - barHeight; fully hidden well past that.
    ShellBus.hubScrollOffsetFor(hubA).value = 2000;
    await tester.pump();
    expect(hideOffset().dy, lessThan(0));
  });

  testWidgets('ShellScaffold hides home top bar when shell overlay has page', (
    tester,
  ) async {
    await pumpScaffold(
      tester,
      desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
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
        desktopScaffold(shellTopBar: const PluginHubCatalogTopBar(tabId: hubA)),
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
        find.image(const AssetImage('assets/images/nav/anime.png')),
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
    expect(find.text('Anime'), findsNothing);
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

    final animeIcon = find.image(
      const AssetImage('assets/images/nav/anime.png'),
    );
    expect(animeIcon, findsOneWidget);
    expect(find.text('Anime'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(animeIcon));
    await tester.pump();
    await tester.pump(ShellTokens.navRailLabelRevealDelay);
    for (var i = 0; i < 12; i++) {
      await tester.pump(ShellTokens.navRailLabelLetterInterval);
    }
    await tester.pumpAndSettle();

    expect(find.text('Hub B'), findsOneWidget);
    expect(
      tester
          .widget<NavDestinationIcon>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is NavDestinationIcon &&
                  widget.destination.id == hubB,
            ),
          )
          .color,
      navDestinationAccentColors[hubB],
    );

    final animeItem = find.ancestor(
      of: animeIcon,
      matching: find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.height != null &&
            w.width == ShellTokens.navRailWidth,
      ),
    );
    expect(animeItem, findsWidgets);
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
          widget is NavDestinationIcon && widget.destination.id == hubA,
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
      navDestinationAccentColors[hubA],
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

    final animeImage = find.image(
      const AssetImage('assets/images/nav/anime.png'),
    );
    final underline = find.byKey(ValueKey('nav-$hubB-underline'));
    Color underlineColor() =>
        (tester.widget<AnimatedContainer>(underline).decoration
                as BoxDecoration)
            .color!;

    expect(underlineColor(), navDestinationAccentColors[hubB]);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(animeImage));
    await tester.pumpAndSettle();

    expect(underlineColor(), navDestinationAccentColors[hubB]);
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

    final animeIcon = tester.widget<NavDestinationIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is NavDestinationIcon && widget.destination.id == hubB,
      ),
    );
    expect(animeIcon.color, navDestinationAccentColors[hubB]);
    expect(animeIcon.size, ShellTokens.navRailIconSize);

    final underline = find.byKey(ValueKey('nav-$hubB-underline'));
    final underlineColor =
        (tester.widget<AnimatedContainer>(underline).decoration
                as BoxDecoration)
            .color!;
    expect(underlineColor, navDestinationAccentColors[hubB]);
  });

  testWidgets('TV nav rail fits all enabled tabs without scrolling', (
    tester,
  ) async {
    const manyIds = [
      hubA,
      hubC,
      hubB,
      'iptv',
      'live_matches',
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
    expect(find.byType(PluginHubCatalogTopBar), findsNothing);
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
        mountedTabIds: const {hubA},
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
            visibleIds: const [hubA, hubB, 'settings'],
            mountedTabIds: const {hubA, hubB, 'settings'},
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
            visibleIds: const [hubA, hubB, 'settings'],
            mountedTabIds: const {hubA, hubB, 'settings'},
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

  test('navDestinations includes core and seeded hub tabs', () {
    expect(navDestinations.containsKey(hubA), isTrue);
    expect(navDestinations.containsKey(hubB), isTrue);
    expect(navDestinations.containsKey(hubC), isTrue);
    expect(navDestinations.containsKey('iptv'), isTrue);
    expect(navDestinations.containsKey('live_matches'), isTrue);
    expect(navDestinations.containsKey('settings'), isTrue);
    expect(navDestinations.containsKey('mylist'), isFalse);
    expect(navDestinations.containsKey('search'), isFalse);
    expect(SettingsService.defaultVisibleNavIds, contains('iptv'));
    expect(SettingsService.defaultVisibleNavIds, contains('live_matches'));
  });

  test('archived nav ids are not registered in shell', () {
    for (final id in archivedNavIds) {
      expect(navDestinations.containsKey(id), isFalse);
      expect(navTabBuilders.containsKey(id), isFalse);
    }
    expect(
      archivedNavIds.intersection(
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
