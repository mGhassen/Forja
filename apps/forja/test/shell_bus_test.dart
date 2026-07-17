import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ShellBus.clearHideGlobalNav();
    ShellBus.selectDefaultTabOnNextNavLoad = false;
    while (ShellBus.playerSurfaceActive.value) {
      ShellBus.leavePlayerSurface();
    }
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
