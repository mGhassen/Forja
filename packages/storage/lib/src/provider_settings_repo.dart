import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_orderKey) ?? List.from(defaultOrder);
  }

  Future<void> setOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderKey, order);
  }

  Future<List<String>> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_enabledKey) ?? List.from(defaultEnabled);
  }

  Future<void> setEnabled(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledKey, ids);
  }

  Future<String?> getLastUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUsedKey);
  }

  Future<void> setLastUsed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedKey, id);
  }
}
