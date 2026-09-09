import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('resolveBuildableShellTabIndex keeps preferred over Settings ghost', () {
    final visible = ['home', 'asian_drama', 'anime', 'settings'];
    bool onlySettings(String id) => id == 'settings';
    expect(
      SettingsService.resolveBuildableShellTabIndex(
        visible,
        defaultTabId: 'home',
        hasBuilder: onlySettings,
      ),
      0,
      reason: 'must not fall through to Settings when Home is starred',
    );
    expect(
      SettingsService.resolveBuildableShellTabIndex(
        visible,
        defaultTabId: 'home',
        hasBuilder: (id) => id == 'iptv' || id == 'settings',
      ),
      0,
      reason: 'iptv not in visible — still keep Home',
    );
    expect(
      SettingsService.resolveBuildableShellTabIndex(
        visible,
        defaultTabId: 'home',
        hasBuilder: (id) => id == 'anime' || id == 'settings',
      ),
      2,
      reason: 'prefer another feature builder over a ghost Home',
    );
    expect(
      SettingsService.resolveBuildableShellTabIndex(
        visible,
        defaultTabId: 'home',
        hasBuilder: (id) => id == 'home' || id == 'settings',
      ),
      0,
    );
  });
}
