import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:rust/rust.dart';

/// Manifest `platforms` device gate (RFC-120).
///
/// Synthetic packs only — no shipped pack ids or slots.
void main() {
  Map<String, dynamic> manifest({
    Map<String, dynamic> plugin = const {},
    Map<String, dynamic> root = const {},
  }) => {
    'schema': 1,
    'id': 'test-pack',
    'name': 'Test pack',
    'version': '1.0.0',
    ...root,
    'plugins': [
      {
        'id': 'p1',
        'name': 'Plugin one',
        'entry': 'p1.js',
        'kind': 'catalog',
        ...plugin,
      },
    ],
  };

  EnginePack pack({
    Map<String, dynamic> plugin = const {},
    Map<String, dynamic> root = const {},
  }) => EnginePack.fromJson(
    manifest(plugin: plugin, root: root),
    sourceUrl: 'https://example.test/manifest.json',
  );

  tearDown(() {
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
  });

  test('no gate → available everywhere', () {
    for (final profile in PlatformProfile.values) {
      SettingsService.configurePlatformProfile(profile);
      final p = pack();
      expect(p.isPluginAvailable(p.plugins.first), isTrue, reason: '$profile');
      expect(p.isPluginActive(p.plugins.first), isTrue);
    }
  });

  test('platforms desktop+phone → off on TV, stored state untouched', () {
    final p = pack(plugin: {'platforms': ['desktop', 'phone']});
    final pl = p.plugins.first;

    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    expect(p.isPluginAvailable(pl), isFalse);
    expect(p.isPluginActive(pl), isFalse);
    expect(p.isUnavailableHere, isTrue);
    expect(enabledEnginePluginIds([p]), isEmpty);
    // Stored state untouched — cloud sync must carry the user's choice.
    expect(pl.enabled, isTrue);
    expect(p.enabled, isTrue);

    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    expect(p.isPluginAvailable(pl), isTrue);
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    expect(p.isPluginAvailable(pl), isTrue);
  });

  test('plugin platforms allow-list with aliases', () {
    final p = pack(plugin: {'platforms': ['Desktop', 'android_tv', 'nope']});
    expect(p.plugins.first.platforms, ['desktop', 'tv']);
    SettingsService.configurePlatformProfile(PlatformProfile.phone);
    expect(p.isPluginAvailable(p.plugins.first), isFalse);
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    expect(p.isPluginAvailable(p.plugins.first), isTrue);
    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    expect(p.isPluginAvailable(p.plugins.first), isTrue);
  });

  test('pack platforms is the default; plugin list overrides it', () {
    final inherit = pack(root: {'platforms': ['tv']});
    expect(inherit.platforms, ['tv']);
    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    expect(inherit.isPluginAvailable(inherit.plugins.first), isFalse);
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    expect(inherit.isPluginAvailable(inherit.plugins.first), isTrue);

    final override = pack(
      root: {'platforms': ['tv']},
      plugin: {'platforms': ['desktop']},
    );
    SettingsService.configurePlatformProfile(PlatformProfile.desktop);
    expect(override.isPluginAvailable(override.plugins.first), isTrue);
    SettingsService.configurePlatformProfile(PlatformProfile.androidTv);
    expect(override.isPluginAvailable(override.plugins.first), isFalse);
  });

  test('gate fields survive the stored round trip', () {
    final p = pack(
      root: {'platforms': ['desktop', 'phone']},
      plugin: {'platforms': ['tv']},
    );
    final back = EnginePack.fromStored(p.toJson());
    expect(back.platforms, ['desktop', 'phone']);
    expect(back.plugins.first.platforms, ['tv']);
    expect(back.plugins.first.copyWith(enabled: false).platforms, ['tv']);
  });

  test('PlatformInfo maps profiles to manifest platform ids', () {
    expect(PlatformInfo.packPlatformIdFor(PlatformProfile.desktop), 'desktop');
    expect(PlatformInfo.packPlatformIdFor(PlatformProfile.phone), 'phone');
    expect(PlatformInfo.packPlatformIdFor(PlatformProfile.androidTv), 'tv');
  });
}
