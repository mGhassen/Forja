import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

/// Per-domain provider scoring table with draggable baseline order.
class ProviderPriorityTable extends StatelessWidget {
  const ProviderPriorityTable({
    super.key,
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.catalog,
    required this.order,
    required this.onOrderChanged,
    required this.onReset,
    this.displayName,
  });

  final SourceDomain domain;
  final String title;
  final String subtitle;
  final Map<String, String> catalog;
  final List<String> order;
  final ValueChanged<List<String>> onOrderChanged;
  final VoidCallback onReset;
  final String Function(String id)? displayName;

  List<String> get _mergedOrder {
    final seen = <String>{};
    final out = <String>[];
    for (final id in order) {
      if (catalog.containsKey(id) && seen.add(id)) out.add(id);
    }
    for (final id in catalog.keys) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final merged = _mergedOrder;
    final preview = SourceEngine.orderProviders(
      domain: domain,
      candidateIds: merged,
      settingsOrder: merged,
    );
    final rowById = preview.rowById;
    final label = displayName ?? (String id) => catalog[id] ?? id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ForjaShellColors.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Runtime quality scores appear after a source is checked — not stored here.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ForjaShellColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: ForjaShellColors.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _HeaderRow(domain: domain),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: merged.length,
                onReorderItem: (oldIndex, newIndex) {
                  final next = List<String>.from(merged);
                  final item = next.removeAt(oldIndex);
                  next.insert(newIndex, item);
                  onOrderChanged(next);
                },
                itemBuilder: (context, index) {
                  final id = merged[index];
                  final row = rowById[id];
                  final supported = row?.supported ?? false;
                  return _ProviderScoreRow(
                    key: ValueKey('$domain-$id'),
                    index: index,
                    id: id,
                    name: label(id),
                    domainScore: row?.domainScore ?? 0,
                    effectiveRank: row?.effectiveRank,
                    maxDisplacement: row?.maxDisplacement ?? maxProviderDisplacement,
                    supported: supported,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onReset, child: const Text('Reset to default')),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.domain});

  final SourceDomain domain;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ForjaShellColors.textSecondary,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(flex: 3, child: Text('Provider', style: style)),
          SizedBox(width: 52, child: Text('Base', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 52, child: Text('Score', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 52, child: Text('±', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 52, child: Text('Eff.', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _ProviderScoreRow extends StatelessWidget {
  const _ProviderScoreRow({
    super.key,
    required this.index,
    required this.id,
    required this.name,
    required this.domainScore,
    required this.effectiveRank,
    required this.maxDisplacement,
    required this.supported,
  });

  final int index;
  final String id;
  final String name;
  final int domainScore;
  final int? effectiveRank;
  final int maxDisplacement;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ForjaShellColors.textSecondary,
        );
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ReorderableDragStartListener(
          index: index,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: ForjaShellColors.borderSubtle),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${index + 1}', style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
        title: Text(name),
        subtitle: Text(id, style: subtitleStyle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MetricCell('${index + 1}'),
            _MetricCell(supported ? '$domainScore' : '—'),
            _MetricCell('±$maxDisplacement'),
            _MetricCell(
              supported && effectiveRank != null ? '${effectiveRank! + 1}' : '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
