import 'engine_storage.dart';

class ProviderSettingsRepo {
  static const _orderKey = 'forja_provider_order';
  static const _enabledKey = 'forja_enabled_providers';
  static const _lastUsedKey = 'forja_last_provider';

  static const defaultOrder = [
    'videasy',
    'vidsrc',
    'vidnest',
    'vidlink',
    'vixsrc',
    'vidzee',
    'vidrock',
    'service111477',
  ];

  static const defaultEnabled = defaultOrder;

  static Future<void> migrateLegacyPrefsIfNeeded() =>
      EngineStorage.migrateLegacyPrefsIfNeeded();

  Future<List<String>> getOrder() async {
    return EngineStorage.readStringList(_orderKey, fallback: defaultOrder);
  }

  Future<void> setOrder(List<String> order) async {
    EngineStorage.writeStringList(_orderKey, order);
  }

  Future<List<String>> getEnabled() async {
    return EngineStorage.readStringList(_enabledKey, fallback: defaultEnabled);
  }

  Future<void> setEnabled(List<String> ids) async {
    EngineStorage.writeStringList(_enabledKey, ids);
  }

  Future<String?> getLastUsed() async {
    final v = EngineStorage.read(_lastUsedKey);
    return v is String ? v : null;
  }

  Future<void> setLastUsed(String id) async {
    EngineStorage.writeString(_lastUsedKey, id);
  }
}
