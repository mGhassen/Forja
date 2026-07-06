import 'package:rust/rust.dart';

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

  Future<List<String>> getOrder() async {
    if (!Engine.isReady) return List.from(defaultOrder);
    return Engine.storageReadStringList(_orderKey, fallback: defaultOrder);
  }

  Future<void> setOrder(List<String> order) async {
    if (!Engine.isReady) return;
    Engine.storageWriteStringList(_orderKey, order);
  }

  Future<List<String>> getEnabled() async {
    if (!Engine.isReady) return List.from(defaultEnabled);
    return Engine.storageReadStringList(_enabledKey, fallback: defaultEnabled);
  }

  Future<void> setEnabled(List<String> ids) async {
    if (!Engine.isReady) return;
    Engine.storageWriteStringList(_enabledKey, ids);
  }

  Future<String?> getLastUsed() async {
    if (!Engine.isReady) return null;
    final v = Engine.storageRead(_lastUsedKey);
    return v is String ? v : null;
  }

  Future<void> setLastUsed(String id) async {
    if (!Engine.isReady) return;
    Engine.storageWriteString(_lastUsedKey, id);
  }
}
