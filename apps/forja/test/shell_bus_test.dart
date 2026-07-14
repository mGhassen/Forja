import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shell/shell_bus.dart';

void main() {
  tearDown(ShellBus.clearHideGlobalNav);

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

  test('ShellBus.clearHideGlobalNav resets hideGlobalNav', () {
    ShellBus.hideGlobalNav.value = true;
    ShellBus.clearHideGlobalNav();
    expect(ShellBus.hideGlobalNav.value, isFalse);
  });
}
