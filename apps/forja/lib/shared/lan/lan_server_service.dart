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

  bool get isRunning =>
      Engine.isReady && RustLib.instance.lanServerPort() > 0;

  int get port => Engine.isReady ? RustLib.instance.lanServerPort() : 0;

  /// Boot / post-splash: start only if the user left the server enabled.
  Future<bool> restoreIfEnabled() async {
    if (!canRunServer) return false;
    if (!await LanPrefs.instance.isLanServerEnabled()) return false;
    return start();
  }

  Future<bool> start({bool allInterfaces = true}) async {
    if (!canRunServer || !Engine.isReady) return false;
    if (isRunning) {
      await LanPrefs.instance.setLanServerEnabled(true);
      final running = port;
      if (running > 0) {
        await LanPrefs.instance.setListenPort(running);
      }
      return true;
    }

    // LAN remounts torrent/proxy streams — engines must be up before bind.
    if (PlatformPlayback.capabilities.localTorrentEngine) {
      final torrentOk = await TorrentStreamService().start();
      if (!torrentOk) {
        debugPrint('[LAN] torrent engine required but failed to start');
        return false;
      }
    }
    await LocalServerService().start();

    final bindMode = allInterfaces ? 1 : 0;
    final preferred = await LanPrefs.instance.listenPort ?? 0;
    var p = _startOnce(bindMode, preferred);

    // Preferred briefly busy after stop — retry before giving up the sticky port.
    if (p <= 0 && preferred > 0 && _isBindConflict(lastStartError())) {
      for (var i = 0; i < 5 && p <= 0; i++) {
        await Future<void>.delayed(Duration(milliseconds: 100 * (i + 1)));
        debugPrint('[LAN] retry preferred port $preferred (${i + 1}/5)');
        p = _startOnce(bindMode, preferred);
      }
    }

    var usedEphemeral = false;
    if (p <= 0 && preferred > 0 && _isBindConflict(lastStartError())) {
      debugPrint('[LAN] port $preferred busy — ephemeral fallback (sticky kept)');
      p = _startOnce(bindMode, 0);
      usedEphemeral = p > 0;
    }

    if (p > 0) {
      await LanPrefs.instance.setLanServerEnabled(true);
      // Don't overwrite sticky with a temporary ephemeral bind.
      if (!usedEphemeral || preferred == 0) {
        await LanPrefs.instance.setListenPort(p);
      }
      RustLib.instance.lanPairingCode();
      return true;
    }

    final err = lastStartError();
    if (err.isNotEmpty) {
      debugPrint('[LAN] start failed: $err');
    }
    return false;
  }

  int _startOnce(int bindMode, int preferredPort) =>
      RustLib.instance.lanServerStart(
        bindMode: bindMode,
        preferredPort: preferredPort,
      );

  String lastStartError() =>
      Engine.isReady ? RustLib.instance.lanServerLastError() : 'engine not ready';

  /// True when the LAN listen socket itself could not bind.
  static bool _isBindConflict(String err) {
    final e = err.toLowerCase();
    // engine_lan prefixes dependency failures; those are not sticky-port conflicts.
    if (e.contains('torrent engine') || e.contains('proxy not running')) {
      return false;
    }
    return e.contains('address already in use') ||
        e.contains('eaddrinuse') ||
        e.contains('os error 48') ||
        e.contains('os error 98') ||
        e.contains('only one usage of each socket address');
  }

  Future<void> stop() async {
    if (Engine.isReady) {
      RustLib.instance.lanServerStop();
    }
    await LanPrefs.instance.setLanServerEnabled(false);
  }

  String refreshPairingCode() =>
      Engine.isReady ? RustLib.instance.lanPairingCodeRefresh() : '';

  /// Active code if still valid; otherwise mint a new one.
  String currentPairingCode() =>
      Engine.isReady ? RustLib.instance.lanPairingCode() : '';

  List<Map<String, dynamic>> listDevices() {
    if (!Engine.isReady) return const [];
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
      Engine.isReady && RustLib.instance.lanRevokeDevice(deviceId);

  /// Recent LAN-opened torrents (persisted; newest first).
  List<Map<String, dynamic>> listTorrentHistory() {
    if (!Engine.isReady) return const [];
    final raw = RustLib.instance.lanTorrentHistoryJson();
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  /// Active torrent engine status while a LAN (or local) swarm is open.
  Map<String, dynamic>? activeTorrentStatus() {
    if (!Engine.isReady) return null;
    final raw = RustLib.instance.torrentStatusJson();
    if (raw.isEmpty || raw == 'null') return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  /// Remove one history row and delete its cached download file when present.
  bool removeTorrentHistory(String infoHash) =>
      Engine.isReady && RustLib.instance.lanRemoveTorrentHistory(infoHash);

  /// Stop the active torrent, wipe the torrent cache dir, clear history.
  bool clearTorrentHistory() =>
      Engine.isReady && RustLib.instance.lanClearTorrentHistory();

  /// Non-loopback IPv4 addresses on this machine (for manual TV pairing).
  Future<List<String>> localIpv4Addresses() async {
    if (kIsWeb) return const [];
    final out = <String>[];
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;
        if (!out.contains(ip)) out.add(ip);
      }
    }
    return out;
  }
}
