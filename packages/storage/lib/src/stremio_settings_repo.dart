import 'engine_storage.dart';

class StremioSettingsRepo {
  static const _key = 'stremio_addons';

  Future<List<Map<String, dynamic>>> getAddons() async {
    return EngineStorage.readMapList(_key);
  }

  Future<void> saveAddon(Map<String, dynamic> addon) async {
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == addon['baseUrl']);
    current.add(addon);
    EngineStorage.writeMapList(_key, current);
  }

  Future<void> removeAddon(String baseUrl) async {
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == baseUrl);
    EngineStorage.writeMapList(_key, current);
  }
}
