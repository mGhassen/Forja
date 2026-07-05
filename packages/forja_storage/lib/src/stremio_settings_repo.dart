import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StremioSettingsRepo {
  static const _key = 'forja_stremio_addons';

  Future<List<Map<String, dynamic>>> getAddons() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<void> saveAddon(Map<String, dynamic> addon) async {
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == addon['baseUrl']);
    current.add(addon);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      current.map((e) => json.encode(e)).toList(),
    );
  }

  Future<void> removeAddon(String baseUrl) async {
    final current = await getAddons();
    current.removeWhere((a) => a['baseUrl'] == baseUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      current.map((e) => json.encode(e)).toList(),
    );
  }
}
