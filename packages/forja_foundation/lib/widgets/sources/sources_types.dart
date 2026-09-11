import 'package:flutter/foundation.dart';

/// Opaque tab for [SourcesPanelChrome].
@immutable
class SourcesTab {
  const SourcesTab({
    required this.id,
    required this.label,
    this.icon = '',
  });

  final String id;
  final String label;
  final String icon;
}

/// Opaque row for [SourcesPanelChrome].
@immutable
class SourcesRow {
  const SourcesRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.footer,
    this.badges = const [],
    this.viewerCount,
    this.payload,
    this.onHoverProbe,
    this.probeHealthCache,
  });

  final String id;
  final String title;
  final String? subtitle;
  /// Right-side muted text (e.g. embed host).
  final String? footer;
  final List<String> badges;
  final int? viewerCount;

  /// Opaque play/resolve payload (feature/service owned).
  final Object? payload;

  final Future<bool> Function()? onHoverProbe;
  final bool? probeHealthCache;
}
