import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart';

import 'lan_prefs.dart';

/// Desktop LAN server control (RFC-022).
class LanServerService {
  LanServerService._();
  static final LanServerService instance = LanServerService._();

  static bool get canRunServer =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool get isRunning => RustLib.instance.lanServerPort() > 0;

  int get port => RustLib.instance.lanServerPort();

  Future<bool> start({bool allInterfaces = true}) async {
    if (!canRunServer || !Engine.isReady) return false;
    if (isRunning) {
      await LanPrefs.instance.setLanServerEnabled(true);
      return true;
    }
    final bindMode = allInterfaces ? 1 : 0;
    final p = RustLib.instance.lanServerStart(
      bindMode: bindMode,
      preferredPort: 0,
    );
    if (p > 0) {
      await LanPrefs.instance.setLanServerEnabled(true);
      RustLib.instance.lanPairingCodeRefresh();
    }
    return p > 0;
  }

  Future<void> stop() async {
    RustLib.instance.lanServerStop();
    await LanPrefs.instance.setLanServerEnabled(false);
  }

  String refreshPairingCode() => RustLib.instance.lanPairingCodeRefresh();

  List<Map<String, dynamic>> listDevices() {
    final raw = RustLib.instance.lanDevicesJson();
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  bool revokeDevice(String deviceId) =>
      RustLib.instance.lanRevokeDevice(deviceId);
}
