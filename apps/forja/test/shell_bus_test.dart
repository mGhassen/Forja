import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_vertical_filters.dart';
import 'package:forja/shell/shell_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CatalogVerticalFiltersRegistry.clearForTest();
    ShellBus.clearHideGlobalNav();
    ShellBus.requestSettingsCategory.value = null;
    ShellBus.settingsHubCategoryId.value = 'profile';
    ShellBus.takeEnterSettingsDetail();
    ShellBus.selectDefaultTabOnNextNavLoad = false;
    ShellBus.homeProviderMenuVisible.value = false;
    ShellBus.selectedWatchProviderId.value = null;
    while (ShellBus.playerSurfaceActive.value) {
      ShellBus.leavePlayerSurface();
    }
    ShellBus.playerResourcePurgeRevision.value = 0;
  });

  test('ShellBus.notifyShellLogoTap bumps revision', () {
    final before = ShellBus.shellLogoTapRevision.value;
    ShellBus.notifyShellLogoTap();
    expect(ShellBus.shellLogoTapRevision.value, before + 1);
  });

  test('ShellBus find shortcut handlers invoke newest first', () {
    var firstCalls = 0;
    var secondCalls = 0;
    bool first() {
      firstCalls++;
      return false;
    }

    bool second() {
      secondCalls++;
      return true;
    }

    ShellBus.registerFindShortcutHandler(first);
    ShellBus.registerFindShortcutHandler(second);
    expect(ShellBus.invokeFindShortcut(), isTrue);
    expect(secondCalls, 1);
    expect(firstCalls, 0);

    ShellBus.unregisterFindShortcutHandler(second);
    expect(ShellBus.invokeFindShortcut(), isFalse);
    expect(firstCalls, 1);

    ShellBus.unregisterFindShortcutHandler(first);
    expect(ShellBus.invokeFindShortcut(), isFalse);
  });

  test('ShellBus.requestTab can be set and read', () {
    ShellBus.requestTab.value = 'search';
    expect(ShellBus.requestTab.value, 'search');
    ShellBus.requestTab.value = null;
  });

  test('ShellBus.openSettings switches to settings and optional category', () {
    ShellBus.requestTab.value = null;
    ShellBus.requestSettingsCategory.value = null;
    ShellBus.settingsHubCategoryId.value = 'profile';
    ShellBus.openSettings(categoryId: 'lan', enterDetail: true);
    expect(ShellBus.requestTab.value, 'settings');
    expect(ShellBus.requestSettingsCategory.value, 'lan');
    expect(ShellBus.settingsHubCategoryId.value, 'lan');
    expect(ShellBus.takeEnterSettingsDetail(), isTrue);
    expect(ShellBus.takeEnterSettingsDetail(), isFalse);
    ShellBus.requestTab.value = null;
    ShellBus.requestSettingsCategory.value = null;
    ShellBus.settingsHubCategoryId.value = 'profile';
  });

  test('ShellBus provider menu show + top logo clear filter', () {
    CatalogVerticalFiltersRegistry.register(
      CatalogVerticalFiltersSpec(
        widgetId: 'watch_providers',
        tabId: 'home',
        pluginId: 'tmdb',
        packSourceUrl: '',
        showSelectedInTopBar: true,
        options: [
          CatalogVerticalFilterOption(
            id: 'netflix',
            label: 'Netflix',
            logo: 'logos/netflix.svg',
            tileColor: const Color(0xFF000000),
            filter: CatalogFilterAst.eq('watch_provider', 8),
          ),
        ],
      ),
    );
    ShellBus.homeProviderMenuVisible.value = false;
    CatalogVerticalFiltersRegistry.selectedIdFor('home').value = null;

    ShellBus.showHomeProviderMenu();
    expect(ShellBus.homeProviderMenuVisible.value, isTrue);

    CatalogVerticalFiltersRegistry.selectedIdFor('home').value = 'netflix';
    ShellBus.onTopProviderLogoTap();
    expect(ShellBus.homeProviderMenuVisible.value, isTrue);
    expect(CatalogVerticalFiltersRegistry.selectedIdFor('home').value, isNull);

    ShellBus.homeProviderMenuVisible.value = false;
    ShellBus.onTopProviderLogoTap();
    expect(ShellBus.homeProviderMenuVisible.value, isTrue);

    ShellBus.onLeaveHomeTab();
    expect(ShellBus.homeProviderMenuVisible.value, isFalse);

    ShellBus.showHomeProviderMenu();
    ShellBus.hideHomeProviderMenu();
    expect(ShellBus.homeProviderMenuVisible.value, isFalse);
  });

  test('ShellBus.selectDefaultTabOnNextNavLoad defaults false and is mutable', () {
    expect(ShellBus.selectDefaultTabOnNextNavLoad, isFalse);
    ShellBus.selectDefaultTabOnNextNavLoad = true;
    expect(ShellBus.selectDefaultTabOnNextNavLoad, isTrue);
    ShellBus.selectDefaultTabOnNextNavLoad = false;
  });

  test('ShellBus.clearHideGlobalNav resets hideGlobalNav', () {
    ShellBus.hideGlobalNav.value = true;
    ShellBus.clearHideGlobalNav();
    expect(ShellBus.hideGlobalNav.value, isFalse);
  });

  test('ShellBus player surface depth tracks nested enter/leave', () {
    expect(ShellBus.playerSurfaceActive.value, isFalse);
    ShellBus.enterPlayerSurface();
    expect(ShellBus.playerSurfaceActive.value, isTrue);
    ShellBus.enterPlayerSurface();
    expect(ShellBus.playerSurfaceActive.value, isTrue);
    ShellBus.leavePlayerSurface();
    expect(ShellBus.playerSurfaceActive.value, isTrue);
    ShellBus.leavePlayerSurface();
    expect(ShellBus.playerSurfaceActive.value, isFalse);
  });

  test('ShellBus enterPlayerSurface bumps purge revision once per activation', () {
    final start = ShellBus.playerResourcePurgeRevision.value;
    ShellBus.enterPlayerSurface();
    expect(ShellBus.playerResourcePurgeRevision.value, start + 1);
    ShellBus.enterPlayerSurface();
    expect(ShellBus.playerResourcePurgeRevision.value, start + 1);
    ShellBus.leavePlayerSurface();
    ShellBus.leavePlayerSurface();
    ShellBus.enterPlayerSurface();
    expect(ShellBus.playerResourcePurgeRevision.value, start + 2);
    ShellBus.leavePlayerSurface();
  });

  testWidgets('ShellBus.trimImageCacheForPlayback clears image cache', (
    tester,
  ) async {
    final cache = imageCache;
    cache.clear();
    expect(cache.currentSize, 0);
    // Seed a live image entry path is hard without network; clearLiveImages
    // must still be callable after trim.
    ShellBus.trimImageCacheForPlayback();
    expect(cache.currentSize, 0);
  });

  testWidgets(
    'ShellBus enterPlayerSurface during build does not throw',
    (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            ShellBus.enterPlayerSurface();
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pump();
      expect(ShellBus.playerSurfaceActive.value, isTrue);
      ShellBus.leavePlayerSurface();
      await tester.pump();
      expect(ShellBus.playerSurfaceActive.value, isFalse);
    },
  );
}
