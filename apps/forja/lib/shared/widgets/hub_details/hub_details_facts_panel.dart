import 'package:flutter/material.dart';

/// Right-column production metadata panel for hub details heroes (anime, Asian drama).
/// Visual match for [HeroFactsPanel] on movie/TV details.
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

    const radius = 12.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Production Info',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.92),
                letterSpacing: 0.2,
              ),
            ),
          ),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                i == visible.length - 1 ? 16 : 10,
              ),
              child: _HubFactRow(label: visible[i].key, value: visible[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _HubFactRow extends StatelessWidget {
  const _HubFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
