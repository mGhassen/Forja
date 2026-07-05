import 'package:rust/rust.dart';

class StremioSettingsRepo {
  static const _key = 'stremio_addons';

  Future<List<Map<String, dynamic>>> getAddons() async {
    if (!ForjaEngine.isReady) return [];
    return ForjaEngine.storageReadMapList(_key);
  }

  Future<void> saveAddon(Map<String, dynamic> addon) async {
    if (!ForjaEngine.isReady) return;
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == addon['baseUrl']);
    current.add(addon);
    ForjaEngine.storageWriteMapList(_key, current);
  }

  Future<void> removeAddon(String baseUrl) async {
    if (!ForjaEngine.isReady) return;
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == baseUrl);
    ForjaEngine.storageWriteMapList(_key, current);
  }
}
