import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

/// Tabbed webstreaming server preference + live reliability.
class ProviderScoringPanel extends StatefulWidget {
  const ProviderScoringPanel({
    super.key,
    required this.streamCatalog,
    required this.streamOrder,
    required this.onStreamOrderChanged,
    required this.onStreamOrderReset,
    required this.animeCatalog,
    required this.animeOrder,
    required this.onAnimeOrderChanged,
    required this.onAnimeOrderReset,
  });

  final Map<String, String> streamCatalog;
  final List<String> streamOrder;
  final ValueChanged<List<String>> onStreamOrderChanged;
  final VoidCallback onStreamOrderReset;

  final Map<String, String> animeCatalog;
  final List<String> animeOrder;
  final ValueChanged<List<String>> onAnimeOrderChanged;
  final VoidCallback onAnimeOrderReset;

  @override
  State<ProviderScoringPanel> createState() => _ProviderScoringPanelState();
}

enum _ScoringTab { movies, series, anime }

class _ProviderScoringPanelState extends State<ProviderScoringPanel> {
  _ScoringTab _tab = _ScoringTab.movies;

  @override
  void initState() {
    super.initState();
    ProviderScoreMemory.revision.addListener(_onScoreRevision);
    ProviderScoreMemory.ensureLoaded();
  }

  @override
  void dispose() {
    ProviderScoreMemory.revision.removeListener(_onScoreRevision);
    super.dispose();
  }

  void _onScoreRevision() {
    if (mounted) setState(() {});
  }

  SourceDomain get _domain => switch (_tab) {
        _ScoringTab.movies => SourceDomain.movies,
        _ScoringTab.series => SourceDomain.series,
        _ScoringTab.anime => SourceDomain.anime,
      };

  bool get _isAnime => _tab == _ScoringTab.anime;

  Map<String, String> get _catalog =>
      _isAnime ? widget.animeCatalog : widget.streamCatalog;

  List<String> get _order {
    final saved = _isAnime ? widget.animeOrder : widget.streamOrder;
    final catalog = _catalog;
    final seen = <String>{};
    final out = <String>[];
    for (final id in saved) {
      if (catalog.containsKey(id) && seen.add(id)) out.add(id);
    }
    for (final id in catalog.keys) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final preview = SourceEngine.orderProviders(
      domain: _domain,
      candidateIds: order,
      settingsOrder: order,
    );
    final rowById = preview.rowById;
    final tryPositionById = {
      for (var i = 0; i < preview.orderedIds.length; i++)
        preview.orderedIds[i]: i + 1,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server reliability',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Score rises when a server works across the titles you play. '
            'Auto tries servers in the Tries order — drag to prefer one.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ForjaShellColors.textSecondary,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          _TabStrip(
            tab: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          _ColumnLegend(),
          const SizedBox(height: 4),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: order.length,
            onReorderItem: (oldIndex, newIndex) {
              final next = List<String>.from(order);
              final item = next.removeAt(oldIndex);
              next.insert(newIndex, item);
              if (_isAnime) {
                widget.onAnimeOrderChanged(next);
              } else {
                widget.onStreamOrderChanged(next);
              }
            },
            itemBuilder: (context, index) {
              final id = order[index];
              final row = rowById[id];
              final score = row?.reliabilityScore ??
                  ProviderScoreMemory.globalScoreFor(id);
              final tries = row?.supported == true
                  ? tryPositionById[id]
                  : null;
              return _ServerRow(
                key: ValueKey('${_tab.name}-$id'),
                index: index,
                name: _catalog[id] ?? id,
                score: score,
                tries: tries,
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isAnime
                  ? widget.onAnimeOrderReset
                  : widget.onStreamOrderReset,
              child: const Text('Reset order'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tab, required this.onChanged});

  final _ScoringTab tab;
  final ValueChanged<_ScoringTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_ScoringTab value, String label) {
      final selected = tab == value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(value),
          child: Ink(
            decoration: shellChipDecoration(selected: selected),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? ForjaShellColors.textPrimary
                      : ForjaShellColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(_ScoringTab.movies, 'Movies'),
        chip(_ScoringTab.series, 'Series'),
        chip(_ScoringTab.anime, 'Anime'),
      ],
    );
  }
}

class _ColumnLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ForjaShellColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(child: Text('Server', style: style)),
          SizedBox(
            width: 72,
            child: Text('Score', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 64,
            child: Text('Tries', style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    super.key,
    required this.index,
    required this.name,
    required this.score,
    required this.tries,
  });

  final int index;
  final String name;
  final int score;
  final int? tries;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: 28,
                height: 36,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: ForjaShellColors.iconMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            SizedBox(
              width: 72,
              child: Center(child: _ScorePill(score: score)),
            ),
            SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.centerRight,
                child: _TriesBadge(tries: tries),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strong = score >= 4;
    final mid = score >= 2;
    final fg = strong
        ? const Color(0xFF7DDEA0)
        : mid
            ? Colors.white.withValues(alpha: 0.9)
            : ForjaShellColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: strong ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: strong ? 0.18 : 0.10),
        ),
      ),
      child: Text(
        '$score',
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _TriesBadge extends StatelessWidget {
  const _TriesBadge({required this.tries});

  final int? tries;

  @override
  Widget build(BuildContext context) {
    if (tries == null) {
      return Text(
        '—',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ForjaShellColors.textSecondary,
            ),
      );
    }
    final label = tries == 1 ? '1st' : tries == 2 ? '2nd' : tries == 3 ? '3rd' : '#$tries';
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: tries == 1
                ? const Color(0xFF7DDEA0)
                : ForjaShellColors.textPrimary,
          ),
    );
  }
}
