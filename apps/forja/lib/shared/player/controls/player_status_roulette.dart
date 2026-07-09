import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';

enum StatusRouletteKind { loading, success, failed, info }

class StatusRouletteEntry {
  const StatusRouletteEntry({
    required this.id,
    required this.label,
    required this.kind,
    this.highlight = false,
  });

  final String id;
  final String label;
  final StatusRouletteKind kind;
  final bool highlight;
}

class PlayerStatusController extends ChangeNotifier {
  final List<StatusRouletteEntry> _entries = [];
  final Map<String, Timer> _timers = {};

  List<StatusRouletteEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  void upsert(
    String id,
    String label, {
    StatusRouletteKind kind = StatusRouletteKind.loading,
    bool highlight = false,
    Duration? dismissAfter,
  }) {
    final idx = _entries.indexWhere((e) => e.id == id);
    final entry = StatusRouletteEntry(
      id: id,
      label: label,
      kind: kind,
      highlight: highlight,
    );
    if (idx >= 0) {
      _entries[idx] = entry;
    } else {
      _entries.add(entry);
    }
    notifyListeners();
    _timers[id]?.cancel();
    if (dismissAfter != null) {
      _timers[id] = Timer(dismissAfter, () => remove(id));
    }
  }

  void remove(String id) {
    _timers.remove(id)?.cancel();
    final removed = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length != removed) notifyListeners();
  }

  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (_entries.isNotEmpty) {
      _entries.clear();
      notifyListeners();
    }
  }

  /// Flash success on active loading rows, then hide after [hold].
  void complete({Duration hold = const Duration(milliseconds: 900)}) {
    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].kind == StatusRouletteKind.loading) {
        _entries[i] = StatusRouletteEntry(
          id: _entries[i].id,
          label: _entries[i].label,
          kind: StatusRouletteKind.success,
          highlight: _entries[i].highlight,
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _timers['_complete'] = Timer(hold, clear);
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

List<StatusRouletteEntry> statusEntriesFromProbes(List<StreamProviderProbe> probes) {
  return probes
      .map(
        (probe) => StatusRouletteEntry(
          id: probe.id,
          label: probe.label,
          kind: switch (probe.status) {
            StreamProviderProbeStatus.trying => StatusRouletteKind.loading,
            StreamProviderProbeStatus.failed => StatusRouletteKind.failed,
            StreamProviderProbeStatus.success => StatusRouletteKind.success,
          },
          highlight: probe.isPreferred,
        ),
      )
      .toList();
}

class PlayerStatusOverlay extends StatelessWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.controller,
    this.bufferingListenable,
    this.header = 'CHECKING SOURCES',
  });

  final PlayerStatusController controller;
  final ValueListenable<bool>? bufferingListenable;
  final String header;

  List<StatusRouletteEntry> _entries(bool buffering) {
    if (controller.entries.isNotEmpty) return controller.entries;
    if (buffering) {
      return const [
        StatusRouletteEntry(
          id: 'buffering',
          label: 'Buffering…',
          kind: StatusRouletteKind.loading,
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    Widget buildOverlay(bool buffering) {
      final entries = _entries(buffering);
      if (entries.isEmpty) return const SizedBox.shrink();
      return Positioned(
        right: 16,
        top: 0,
        bottom: 0,
        child: IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusRoulettePanel(
                child: StatusRouletteView(
                  entries: entries,
                  header: header,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (bufferingListenable == null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => buildOverlay(false),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([controller, bufferingListenable!]),
      builder: (context, _) => buildOverlay(bufferingListenable!.value),
    );
  }
}

class StatusRoulettePanel extends StatelessWidget {
  const StatusRoulettePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: child,
      ),
    );
  }
}

class StatusRouletteView extends StatelessWidget {
  const StatusRouletteView({
    super.key,
    required this.entries,
    required this.header,
  });

  final List<StatusRouletteEntry> entries;
  final String header;

  StatusRouletteEntry? get _activeEntry {
    for (final entry in entries) {
      if (entry.kind == StatusRouletteKind.loading) return entry;
    }
    return entries.isNotEmpty ? entries.last : null;
  }

  StatusRouletteEntry? get _previousEntry {
    final active = _activeEntry;
    if (active == null) return null;
    final idx = entries.indexWhere((e) => e.id == active.id);
    if (idx <= 0) return null;
    return entries[idx - 1];
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeEntry;
    if (active == null) return const SizedBox.shrink();

    final previous = _previousEntry;
    final checkedCount =
        entries.where((e) => e.kind != StatusRouletteKind.loading).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          header,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          width: 220,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerRight,
              clipBehavior: Clip.hardEdge,
              children: [
                if (previous != null &&
                    previous.kind != StatusRouletteKind.loading)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _StatusRouletteRow(
                        entry: previous,
                        dimmed: true,
                        compact: true,
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previousChildren) => Stack(
                    alignment: Alignment.centerRight,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...previousChildren,
                      if (current != null) current,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.55),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return ClipRect(
                      child: SlideTransition(
                        position: slide,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _StatusRouletteRow(
                    key: ValueKey('${active.id}-${active.kind.name}'),
                    entry: active,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          checkedCount > 0 ? '$checkedCount checked' : 'Starting…',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _StatusRouletteRow extends StatelessWidget {
  const _StatusRouletteRow({
    super.key,
    required this.entry,
    this.dimmed = false,
    this.compact = false,
  });

  final StatusRouletteEntry entry;
  final bool dimmed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLoading = entry.kind == StatusRouletteKind.loading;
    final isFailed = entry.kind == StatusRouletteKind.failed;
    final alpha = dimmed ? 0.45 : (isFailed ? 0.65 : 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact && !isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: _StatusIcon(kind: entry.kind, dimmed: dimmed),
          ),
          const SizedBox(width: 10),
        ],
        if (entry.highlight && !dimmed) ...[
          Icon(
            Icons.star_rounded,
            size: compact ? 11 : 13,
            color: Colors.amber.withValues(alpha: isFailed ? 0.4 : 0.85),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: alpha),
              fontSize: compact ? 12 : 15,
              fontWeight: isLoading && !dimmed ? FontWeight.w600 : FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        if (isLoading && !dimmed) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.kind, this.dimmed = false});

  final StatusRouletteKind kind;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final alpha = dimmed ? 0.35 : 1.0;
    switch (kind) {
      case StatusRouletteKind.loading:
        return CircularProgressIndicator(
          strokeWidth: 1.8,
          color: Colors.white.withValues(alpha: 0.9 * alpha),
        );
      case StatusRouletteKind.failed:
        return Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.red.shade400.withValues(alpha: alpha),
        );
      case StatusRouletteKind.success:
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: Color(0xFF22C55E).withValues(alpha: alpha),
        );
      case StatusRouletteKind.info:
        return Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7 * alpha),
        );
    }
  }
}
