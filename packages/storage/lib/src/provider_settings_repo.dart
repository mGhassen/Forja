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
    if (!ForjaEngine.isReady) return List.from(defaultOrder);
    return ForjaEngine.storageReadStringList(_orderKey, fallback: defaultOrder);
  }

  Future<void> setOrder(List<String> order) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteStringList(_orderKey, order);
  }

  Future<List<String>> getEnabled() async {
    if (!ForjaEngine.isReady) return List.from(defaultEnabled);
    return ForjaEngine.storageReadStringList(_enabledKey, fallback: defaultEnabled);
  }

  Future<void> setEnabled(List<String> ids) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteStringList(_enabledKey, ids);
  }

  Future<String?> getLastUsed() async {
    if (!ForjaEngine.isReady) return null;
    final v = ForjaEngine.storageRead(_lastUsedKey);
    return v is String ? v : null;
  }

  Future<void> setLastUsed(String id) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteString(_lastUsedKey, id);
  }
}
