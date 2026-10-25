import 'package:flutter/foundation.dart';

/// Pack-emitted Open with… chrome. Host mounts only — no product defaults
/// that name My List / Simkl.
@immutable
class ListOpenBindChrome {
  const ListOpenBindChrome({
    this.pin = false,
    this.trackerLabel = 'Match',
    this.trackerTitle = 'Match…',
    this.openLabel = 'Open with',
    this.trackerIcon,
  });

  /// Show list-status pin in the bind sheet (TV cards omit overlay pin).
  final bool pin;

  /// Hero-pill label for tracker mode.
  final String trackerLabel;

  /// Dialog title while tracker mode is active.
  final String trackerTitle;

  /// Hero-pill label for hub open mode (hub name may be appended by host).
  final String openLabel;

  /// Optional icon key for tracker mark (`simkl` → host asset map).
  final String? trackerIcon;

  static const empty = ListOpenBindChrome();

  factory ListOpenBindChrome.fromRow(Map<String, dynamic> row) {
    Object? raw = row['openBind'];
    if (raw is! Map) {
      final paint = row['paint'];
      if (paint is Map) {
        final props = paint['props'];
        if (props is Map) raw = props['openBind'];
      }
    }
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    String str(String key, String fallback) {
      final v = (m[key] ?? '').toString().trim();
      return v.isEmpty ? fallback : v;
    }

    final icon = (m['trackerIcon'] ?? m['icon'] ?? '').toString().trim();
    return ListOpenBindChrome(
      pin: m['pin'] == true,
      trackerLabel: str('trackerLabel', 'Match'),
      trackerTitle: str('trackerTitle', 'Match…'),
      openLabel: str('openLabel', 'Open with'),
      trackerIcon: icon.isEmpty ? null : icon,
    );
  }
}
