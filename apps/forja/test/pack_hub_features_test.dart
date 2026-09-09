import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/pack_hub_features.dart';

void main() {
  test('hubTabIds uses official slot when nav has no tabId', () {
    final pack = EnginePack(
      packId: 'forjahq-home',
      name: 'Home',
      version: '1',
      sourceUrl:
          'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/home/manifest.json',
      plugins: [
        EnginePlugin(
          id: 'tmdb',
          name: 'Home',
          entry: 'tmdb.js',
          kind: 'catalog',
          nav: {'label': 'Home', 'icon': 'icons/nav.png'},
        ),
      ],
    );
    expect(PackHubFeatures.hubTabIds(pack), ['home']);
  });

  test('hubTabIds skips non-catalog plugins', () {
    final pack = EnginePack(
      packId: 'forjahq-providers',
      name: 'Providers',
      version: '1',
      sourceUrl:
          'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/providers/manifest.json',
      plugins: [
        EnginePlugin(
          id: 'videasy',
          name: 'Videasy',
          entry: 'videasy.js',
          kind: 'http',
        ),
      ],
    );
    expect(PackHubFeatures.hubTabIds(pack), isEmpty);
  });
}
