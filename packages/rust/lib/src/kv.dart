import 'facade.dart';

Future<bool> kvHasKey(String key) async {
  if (!Engine.isReady) return false;
  return Engine.storageHasKey(key);
}

Future<String?> kvGetString(String key) async {
  return kvGetStringSync(key);
}

String? kvGetStringSync(String key) {
  if (!Engine.isReady) return null;
  final v = Engine.storageRead(key);
  return v is String ? v : null;
}

Future<void> kvSetString(String key, String value) async {
  if (!Engine.isReady) return;
  Engine.storageWriteString(key, value);
}

Future<bool> kvGetBool(String key, {required bool fallback}) async {
  return kvGetBoolSync(key, fallback: fallback);
}

bool kvGetBoolSync(String key, {required bool fallback}) {
  if (!Engine.isReady) return fallback;
  return Engine.storageReadBool(key, fallback: fallback);
}

Future<void> kvSetBool(String key, bool value) async {
  if (!Engine.isReady) return;
  Engine.storageWriteBool(key, value);
}

Future<int> kvGetInt(String key, {required int fallback}) async {
  if (!Engine.isReady) return fallback;
  final v = Engine.storageRead(key);
  if (v is num) return v.toInt();
  return fallback;
}

Future<void> kvSetInt(String key, int value) async {
  if (!Engine.isReady) return;
  Engine.storageWrite(key, value);
}

Future<double> kvGetDouble(String key, {required double fallback}) async {
  if (!Engine.isReady) return fallback;
  final v = Engine.storageRead(key);
  if (v is num) return v.toDouble();
  return fallback;
}

Future<void> kvSetDouble(String key, double value) async {
  if (!Engine.isReady) return;
  Engine.storageWrite(key, value);
}

Future<List<String>> kvGetStringList(
  String key, {
  required List<String> fallback,
}) async {
  if (!Engine.isReady) return List.from(fallback);
  return Engine.storageReadStringList(key, fallback: fallback);
}

Future<void> kvSetStringList(String key, List<String> values) async {
  if (!Engine.isReady) return;
  Engine.storageWriteStringList(key, values);
}

Future<List<Map<String, dynamic>>> kvGetMapList(String key) async {
  if (!Engine.isReady) return [];
  return Engine.storageReadMapList(key);
}

Future<void> kvSetMapList(String key, List<Map<String, dynamic>> values) async {
  if (!Engine.isReady) return;
  Engine.storageWriteMapList(key, values);
}

Future<List<Map<String, dynamic>>> kvGetJsonList(String key) async {
  if (!Engine.isReady) return [];
  final v = Engine.storageRead(key);
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return [];
}

Future<void> kvSetJsonList(String key, List<Map<String, dynamic>> values) async {
  if (!Engine.isReady) return;
  Engine.storageWrite(key, values);
}

Future<List<String>> kvGetJsonStringList(String key) async {
  if (!Engine.isReady) return [];
  final v = Engine.storageRead(key);
  if (v is List) return v.map((e) => '$e').toList();
  return [];
}

Future<void> kvSetJsonStringList(String key, List<String> values) async {
  if (!Engine.isReady) return;
  Engine.storageWrite(key, values);
}
