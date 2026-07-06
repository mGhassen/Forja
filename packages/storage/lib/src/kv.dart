import 'dart:convert';

import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

Future<bool> kvHasKey(String key) async {
  if (Engine.isReady) return Engine.storageHasKey(key);
  return (await _prefs()).containsKey(key);
}

Future<String?> kvGetString(String key) async {
  if (Engine.isReady) {
    final v = Engine.storageRead(key);
    return v is String ? v : null;
  }
  return (await _prefs()).getString(key);
}

Future<void> kvSetString(String key, String value) async {
  if (Engine.isReady) {
    Engine.storageWriteString(key, value);
    return;
  }
  await (await _prefs()).setString(key, value);
}

Future<bool> kvGetBool(String key, {required bool fallback}) async {
  if (Engine.isReady) {
    return Engine.storageReadBool(key, fallback: fallback);
  }
  return (await _prefs()).getBool(key) ?? fallback;
}

Future<void> kvSetBool(String key, bool value) async {
  if (Engine.isReady) {
    Engine.storageWriteBool(key, value);
    return;
  }
  await (await _prefs()).setBool(key, value);
}

Future<int> kvGetInt(String key, {required int fallback}) async {
  if (Engine.isReady) {
    final v = Engine.storageRead(key);
    if (v is num) return v.toInt();
    return fallback;
  }
  return (await _prefs()).getInt(key) ?? fallback;
}

Future<void> kvSetInt(String key, int value) async {
  if (Engine.isReady) {
    Engine.storageWrite(key, value);
    return;
  }
  await (await _prefs()).setInt(key, value);
}

Future<double> kvGetDouble(String key, {required double fallback}) async {
  if (Engine.isReady) {
    final v = Engine.storageRead(key);
    if (v is num) return v.toDouble();
    return fallback;
  }
  return (await _prefs()).getDouble(key) ?? fallback;
}

Future<void> kvSetDouble(String key, double value) async {
  if (Engine.isReady) {
    Engine.storageWrite(key, value);
    return;
  }
  await (await _prefs()).setDouble(key, value);
}

Future<List<String>> kvGetStringList(
  String key, {
  required List<String> fallback,
}) async {
  if (Engine.isReady) {
    return Engine.storageReadStringList(key, fallback: fallback);
  }
  return (await _prefs()).getStringList(key) ?? fallback;
}

Future<void> kvSetStringList(String key, List<String> values) async {
  if (Engine.isReady) {
    Engine.storageWriteStringList(key, values);
    return;
  }
  await (await _prefs()).setStringList(key, values);
}

Future<List<Map<String, dynamic>>> kvGetMapList(String key) async {
  if (Engine.isReady) {
    return Engine.storageReadMapList(key);
  }
  final raw = (await _prefs()).getStringList(key) ?? const [];
  return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
}

Future<void> kvSetMapList(String key, List<Map<String, dynamic>> values) async {
  if (Engine.isReady) {
    Engine.storageWriteMapList(key, values);
    return;
  }
  await (await _prefs()).setStringList(
    key,
    values.map((e) => jsonEncode(e)).toList(),
  );
}

Future<List<Map<String, dynamic>>> kvGetJsonList(String key) async {
  if (Engine.isReady) {
    final v = Engine.storageRead(key);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
  final raw = await kvGetString(key);
  if (raw == null) return [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded.cast<Map<String, dynamic>>();
}

Future<void> kvSetJsonList(String key, List<Map<String, dynamic>> values) async {
  if (Engine.isReady) {
    Engine.storageWrite(key, values);
    return;
  }
  await kvSetString(key, jsonEncode(values));
}

Future<List<String>> kvGetJsonStringList(String key) async {
  if (Engine.isReady) {
    final v = Engine.storageRead(key);
    if (v is List) return v.map((e) => '$e').toList();
    return [];
  }
  final raw = await kvGetString(key);
  if (raw == null) return [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded.map((e) => '$e').toList();
}

Future<void> kvSetJsonStringList(String key, List<String> values) async {
  if (Engine.isReady) {
    Engine.storageWrite(key, values);
    return;
  }
  await kvSetString(key, jsonEncode(values));
}
