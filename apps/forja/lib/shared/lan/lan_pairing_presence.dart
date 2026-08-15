import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/lan/lan_server_service.dart';

/// Same window as Settings Online/Idle and `crates/lan` idle-watch.
const int kLanDeviceIdleSecs = 120;

/// Rail + Settings LAN status. [off] hides the dot.
enum LanPresenceKind {
  off,
  waiting,
  offline,
  idle,
  ready,
  playing,
}

extension LanPresenceKindX on LanPresenceKind {
  bool get showDot => this != LanPresenceKind.off;

  bool get pulse =>
      this == LanPresenceKind.waiting || this == LanPresenceKind.playing;

  Color get color => switch (this) {
        LanPresenceKind.off => Colors.transparent,
        LanPresenceKind.waiting => const Color(0xFFFBBF24),
        LanPresenceKind.offline => const Color(0xFFF87171),
        LanPresenceKind.idle =>
          ForjaShellColors.textSecondary.withValues(alpha: 0.55),
        LanPresenceKind.ready || LanPresenceKind.playing =>
          ForjaShellColors.brandGreen,
      };

  String get tooltip => switch (this) {
        LanPresenceKind.off => '',
        LanPresenceKind.waiting => 'LAN waiting for pair',
        LanPresenceKind.offline => 'Desktop offline',
        LanPresenceKind.idle => 'LAN idle',
        LanPresenceKind.ready => 'LAN paired',
        LanPresenceKind.playing => 'LAN playing',
      };

  String get shortLabel => switch (this) {
        LanPresenceKind.off => '',
        LanPresenceKind.waiting => 'Waiting',
        LanPresenceKind.offline => 'Offline',
        LanPresenceKind.idle => 'Idle',
        LanPresenceKind.ready => 'Online',
        LanPresenceKind.playing => 'Playing',
      };
}

/// Pure resolver — unit-tested. Host wires live engine/prefs in
/// [LanPairingPresence].
abstract final class LanPresence {
  static bool deviceOnline(Object? lastSeenRaw, {DateTime? now}) {
    final secs = (lastSeenRaw as num?)?.toInt() ?? 0;
    if (secs <= 0) return false;
    final nowSecs = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final age = nowSecs - secs;
    return age >= 0 && age <= kLanDeviceIdleSecs;
  }

  static bool lanTorrentActive(
    Map<String, dynamic>? active,
    List<Map<String, dynamic>> history,
  ) {
    final hash = active?['info_hash']?.toString().toLowerCase();
    if (hash == null || hash.isEmpty) return false;
    return history.any(
      (e) => (e['info_hash']?.toString() ?? '').toLowerCase() == hash,
    );
  }

  static bool devicePlaying({
    required String deviceId,
    required Map<String, dynamic>? active,
    required List<Map<String, dynamic>> history,
  }) {
    if (deviceId.isEmpty) return false;
    if (!lanTorrentActive(active, history)) return false;
    final hash = active!['info_hash']!.toString().toLowerCase();
    return history.any((e) {
      final h = (e['info_hash']?.toString() ?? '').toLowerCase();
      return h == hash && (e['device_id']?.toString() ?? '') == deviceId;
    });
  }

  static LanPresenceKind resolveServer({
    required bool running,
    required List<Object?> lastSeen,
    required bool lanTorrentActive,
    DateTime? now,
  }) {
    if (!running) return LanPresenceKind.off;
    if (lastSeen.isEmpty) return LanPresenceKind.waiting;
    if (lanTorrentActive) return LanPresenceKind.playing;
    if (lastSeen.any((s) => deviceOnline(s, now: now))) {
      return LanPresenceKind.ready;
    }
    return LanPresenceKind.idle;
  }

  static LanPresenceKind resolveClient({
    required bool paired,
    required bool desktopOnline,
    required bool lanTorrentActive,
  }) {
    if (!paired) return LanPresenceKind.off;
    if (!desktopOnline) return LanPresenceKind.offline;
    if (lanTorrentActive) return LanPresenceKind.playing;
    return LanPresenceKind.ready;
  }
}

/// Live LAN presence for the nav-rail profile dot.
class LanPairingPresence {
  LanPairingPresence._();
  static final LanPairingPresence instance = LanPairingPresence._();

  final ValueNotifier<LanPresenceKind> status =
      ValueNotifier(LanPresenceKind.off);

  /// Desktop: ≥1 paired device. Client: saved token + address.
  bool get paired {
    final k = status.value;
    return k != LanPresenceKind.off && k != LanPresenceKind.waiting;
  }

  Future<void>? _inFlight;

  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  void notifyChanged() => unawaited(refresh());

  Future<void> _refresh() async {
    final next = await _compute();
    if (status.value != next) status.value = next;
  }

  Future<LanPresenceKind> _compute() async {
    if (LanServerService.canRunServer) {
      final running = LanServerService.instance.isRunning;
      final devices = running
          ? LanServerService.instance.listDevices()
          : const <Map<String, dynamic>>[];
      final history = running
          ? LanServerService.instance.listTorrentHistory()
          : const <Map<String, dynamic>>[];
      final active =
          running ? LanServerService.instance.activeTorrentStatus() : null;
      return LanPresence.resolveServer(
        running: running,
        lastSeen: devices.map((d) => d['last_seen']).toList(),
        lanTorrentActive: LanPresence.lanTorrentActive(active, history),
      );
    }

    final paired = await LanPrefs.instance.isPaired;
    if (!paired) return LanPresenceKind.off;
    final online = await LanClientService.instance.verifyPairedConnection();
    if (!online) return LanPresenceKind.offline;
    final host = await LanPrefs.instance.serverHost;
    final port = await LanPrefs.instance.serverPort;
    var serving = false;
    if (host != null && port != null) {
      final payload = await LanClientService.instance.pingStatusJson(host, port);
      serving = payload != null &&
          (payload['info_hash']?.toString().isNotEmpty ?? false);
    }
    return LanPresence.resolveClient(
      paired: true,
      desktopOnline: true,
      lanTorrentActive: serving,
    );
  }
}

class LanPresenceDot extends StatelessWidget {
  const LanPresenceDot({
    super.key,
    required this.kind,
    this.size = 5,
    this.bordered = false,
  });

  final LanPresenceKind kind;
  final double size;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    if (!kind.showDot) return const SizedBox.shrink();
    final dot = kind.pulse
        ? _PulsingPresenceDot(
            color: kind.color,
            size: size,
            bordered: bordered,
          )
        : _staticDot(kind.color, size, bordered);
    final tip = kind.tooltip;
    if (tip.isEmpty) return dot;
    return Tooltip(message: tip, child: dot);
  }

  static Widget _staticDot(Color color, double size, bool bordered) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: bordered
            ? Border.all(color: ForjaShellColors.surfaceElevated, width: 1.5)
            : null,
      ),
    );
  }
}

class _PulsingPresenceDot extends StatefulWidget {
  const _PulsingPresenceDot({
    required this.color,
    required this.size,
    required this.bordered,
  });

  final Color color;
  final double size;
  final bool bordered;

  @override
  State<_PulsingPresenceDot> createState() => _PulsingPresenceDotState();
}

class _PulsingPresenceDotState extends State<_PulsingPresenceDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_ctrl),
      child: LanPresenceDot._staticDot(
        widget.color,
        widget.size,
        widget.bordered,
      ),
    );
  }
}
