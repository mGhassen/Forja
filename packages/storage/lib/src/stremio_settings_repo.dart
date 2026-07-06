import 'package:rust/rust.dart';

class StremioSettingsRepo {
  static const _key = 'stremio_addons';

  Future<List<Map<String, dynamic>>> getAddons() async {
    if (!Engine.isReady) return [];
    return Engine.storageReadMapList(_key);
  }

  Future<void> saveAddon(Map<String, dynamic> addon) async {
    if (!Engine.isReady) return;
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == addon['baseUrl']);
    current.add(addon);
    Engine.storageWriteMapList(_key, current);
  }

  Future<void> removeAddon(String baseUrl) async {
    if (!Engine.isReady) return;
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == baseUrl);
    Engine.storageWriteMapList(_key, current);
  }
}
