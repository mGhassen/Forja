import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/lan/lan_server_service.dart';

/// Same window as Settings device Active/Quiet and `crates/lan` idle-watch.
const int kLanDeviceIdleSecs = 120;

const Color _lanAmber = Color(0xFFFBBF24);
const Color _lanDown = Color(0xFFF87171);

/// Reachability of the LAN HTTP server. Never encodes pairing or playback.
enum LanServerMark { off, up, down }

/// Pairing / playback session. Never encodes whether the server is listening.
enum LanSessionMark { none, waiting, paired, idle, playing }

/// Per-device talk on the desktop paired-devices list (not the rail).
enum LanDeviceTalk { idle, active, playing }

/// Split LAN chrome: [server] is the dot, [session] is the bar under it.
class LanPresence {
  const LanPresence({
    this.server = LanServerMark.off,
    this.session = LanSessionMark.none,
  });

  static const hidden = LanPresence();

  final LanServerMark server;
  final LanSessionMark session;

  bool get visible =>
      server != LanServerMark.off || session != LanSessionMark.none;

  bool get paired =>
      session == LanSessionMark.paired ||
      session == LanSessionMark.idle ||
      session == LanSessionMark.playing;

  Color get serverColor => switch (server) {
        LanServerMark.off => Colors.transparent,
        LanServerMark.up => ForjaShellColors.brandGreen,
        LanServerMark.down => _lanDown,
      };

  Color get sessionColor => switch (session) {
        LanSessionMark.none => Colors.transparent,
        LanSessionMark.waiting => _lanAmber,
        LanSessionMark.idle =>
          ForjaShellColors.textSecondary.withValues(alpha: 0.7),
        LanSessionMark.paired || LanSessionMark.playing =>
          ForjaShellColors.brandGreen,
      };

  bool get sessionPulse =>
      session == LanSessionMark.waiting || session == LanSessionMark.playing;

  String get tooltip {
    final s = switch (server) {
      LanServerMark.off => '',
      LanServerMark.up => 'Server up',
      LanServerMark.down => 'Server unreachable',
    };
    final c = switch (session) {
      LanSessionMark.none => '',
      LanSessionMark.waiting => 'waiting for pair',
      LanSessionMark.paired => 'paired',
      LanSessionMark.idle => 'idle',
      LanSessionMark.playing => 'playing',
    };
    if (s.isEmpty) return c.isEmpty ? '' : c;
    if (c.isEmpty) return s;
    return '$s · $c';
  }

  factory LanPresence.desktop({
    required bool running,
    required List<Object?> lastSeen,
    required bool lanTorrentActive,
    DateTime? now,
  }) {
    if (!running) return hidden;
    if (lastSeen.isEmpty) {
      return const LanPresence(
        server: LanServerMark.up,
        session: LanSessionMark.waiting,
      );
    }
    if (lanTorrentActive) {
      return const LanPresence(
        server: LanServerMark.up,
        session: LanSessionMark.playing,
      );
    }
    if (lastSeen.any((s) => deviceOnline(s, now: now))) {
      return const LanPresence(
        server: LanServerMark.up,
        session: LanSessionMark.paired,
      );
    }
    return const LanPresence(
      server: LanServerMark.up,
      session: LanSessionMark.idle,
    );
  }

  factory LanPresence.client({
    required bool paired,
    required bool desktopOnline,
    required bool lanTorrentActive,
  }) {
    if (!paired) return hidden;
    if (!desktopOnline) {
      return const LanPresence(
        server: LanServerMark.down,
        session: LanSessionMark.idle,
      );
    }
    if (lanTorrentActive) {
      return const LanPresence(
        server: LanServerMark.up,
        session: LanSessionMark.playing,
      );
    }
    return const LanPresence(
      server: LanServerMark.up,
      session: LanSessionMark.paired,
    );
  }

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

  static LanDeviceTalk deviceTalk({
    required String deviceId,
    required Object? lastSeen,
    required Map<String, dynamic>? active,
    required List<Map<String, dynamic>> history,
    DateTime? now,
  }) {
    if (devicePlaying(
      deviceId: deviceId,
      active: active,
      history: history,
    )) {
      return LanDeviceTalk.playing;
    }
    return deviceOnline(lastSeen, now: now)
        ? LanDeviceTalk.active
        : LanDeviceTalk.idle;
  }

  @override
  bool operator ==(Object other) =>
      other is LanPresence &&
      other.server == server &&
      other.session == session;

  @override
  int get hashCode => Object.hash(server, session);
}

extension LanDeviceTalkX on LanDeviceTalk {
  Color get color => switch (this) {
        LanDeviceTalk.idle =>
          ForjaShellColors.textSecondary.withValues(alpha: 0.55),
        LanDeviceTalk.active || LanDeviceTalk.playing =>
          ForjaShellColors.brandGreen,
      };

  bool get pulse => this == LanDeviceTalk.playing;

  String get shortLabel => switch (this) {
        LanDeviceTalk.idle => 'Idle',
        LanDeviceTalk.active => 'Active',
        LanDeviceTalk.playing => 'Playing',
      };
}

/// Live LAN presence for the nav-rail profile mark.
class LanPairingPresence {
  LanPairingPresence._();
  static final LanPairingPresence instance = LanPairingPresence._();

  final ValueNotifier<LanPresence> status = ValueNotifier(LanPresence.hidden);

  bool get paired => status.value.paired;

  Future<void>? _inFlight;

  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  void notifyChanged() => unawaited(refresh());

  Future<void> _refresh() async {
    final next = await _compute();
    if (status.value != next) status.value = next;
  }

  Future<LanPresence> _compute() async {
    if (LanServerService.canRunServer) {
      final running = LanServerService.instance.isRunning;
      if (!running) return LanPresence.hidden;
      final devices = LanServerService.instance.listDevices();
      final history = LanServerService.instance.listTorrentHistory();
      final active = LanServerService.instance.activeTorrentStatus();
      return LanPresence.desktop(
        running: true,
        lastSeen: devices.map((d) => d['last_seen']).toList(),
        lanTorrentActive: LanPresence.lanTorrentActive(active, history),
      );
    }

    final paired = await LanPrefs.instance.isPaired;
    if (!paired) return LanPresence.hidden;
    final online = await LanClientService.instance.verifyPairedConnection();
    var serving = false;
    if (online) {
      final host = await LanPrefs.instance.serverHost;
      final port = await LanPrefs.instance.serverPort;
      if (host != null && port != null) {
        final payload =
            await LanClientService.instance.pingStatusJson(host, port);
        serving = payload != null &&
            (payload['info_hash']?.toString().isNotEmpty ?? false);
      }
    }
    return LanPresence.client(
      paired: true,
      desktopOnline: online,
      lanTorrentActive: serving,
    );
  }
}

/// Dot = server. Bar beside it = session (desktop server only).
class LanPresenceMark extends StatelessWidget {
  const LanPresenceMark({
    super.key,
    required this.presence,
    this.size = 5,
    this.bordered = false,
    this.showBar = true,
  });

  final LanPresence presence;
  final double size;
  final bool bordered;
  /// Session bar beside the dot. Desktop server only — clients are a single reachability dot.
  final bool showBar;

  static double sizeFor({required bool tv}) => tv ? 8 : 5;

  static double barWidth(double size) => size * 1.7;

  static double railSlotHeight({required bool tv}) => sizeFor(tv: tv);

  @override
  Widget build(BuildContext context) {
    if (!presence.visible) return const SizedBox.shrink();
    final drawBar = showBar && presence.session != LanSessionMark.none;
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (presence.server != LanServerMark.off)
          _circle(presence.serverColor, size, bordered),
        if (drawBar) ...[
          SizedBox(width: size * 0.35),
          _bar(
            color: presence.sessionColor,
            width: barWidth(size),
            height: size,
            pulse: presence.sessionPulse,
          ),
        ],
      ],
    );
    final tip = showBar ? presence.tooltip : switch (presence.server) {
      LanServerMark.off => '',
      LanServerMark.up => 'Desktop online',
      LanServerMark.down => 'Desktop offline',
    };
    if (tip.isEmpty) return mark;
    return Tooltip(message: tip, child: mark);
  }

  static Widget _circle(Color color, double size, bool bordered) {
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

  static Widget _bar({
    required Color color,
    required double width,
    required double height,
    required bool pulse,
  }) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    if (!pulse) return bar;
    return _Pulsing(child: bar);
  }
}

/// Single device talk dot (Settings paired-devices list).
class LanDeviceTalkDot extends StatelessWidget {
  const LanDeviceTalkDot({
    super.key,
    required this.talk,
    this.size = 9,
  });

  final LanDeviceTalk talk;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: talk.color,
        border: Border.all(color: ForjaShellColors.surfaceElevated, width: 1.5),
      ),
    );
    if (!talk.pulse) return dot;
    return _Pulsing(child: dot);
  }
}

class _Pulsing extends StatefulWidget {
  const _Pulsing({required this.child});

  final Widget child;

  @override
  State<_Pulsing> createState() => _PulsingState();
}

class _PulsingState extends State<_Pulsing>
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
      child: widget.child,
    );
  }
}
