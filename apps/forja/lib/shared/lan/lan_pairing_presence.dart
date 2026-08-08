import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/lan/lan_server_service.dart';

/// Whether this device has a LAN pairing relationship (not necessarily online).
///
/// Desktop: ≥1 paired device in the server store.
/// Client (TV/phone): saved token + server address.
class LanPairingPresence {
  LanPairingPresence._();
  static final LanPairingPresence instance = LanPairingPresence._();

  final ValueNotifier<bool> paired = ValueNotifier(false);

  Future<void>? _inFlight;

  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  void notifyChanged() => unawaited(refresh());

  Future<void> _refresh() async {
    final next = await _compute();
    if (paired.value != next) paired.value = next;
  }

  Future<bool> _compute() async {
    if (LanServerService.canRunServer) {
      return LanServerService.instance.listDevices().isNotEmpty;
    }
    return LanPrefs.instance.isPaired;
  }
}
