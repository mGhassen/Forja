import 'package:flutter/material.dart';

/// Right-column metadata panel for hub details heroes (anime, Asian drama).
class HubDetailsFactsPanel extends StatelessWidget {
  const HubDetailsFactsPanel({super.key, required this.entries});

  final List<MapEntry<String, String>> entries;

  bool get hasContent =>
      entries.any((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final visible = entries
        .where((e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _FactRow(label: visible[i].key, value: visible[i].value),
        ],
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
