import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

const int kEpisodeRangeChunkSize = 50;

class EpisodeRange {
  const EpisodeRange({
    required this.index,
    required this.labelStart,
    required this.labelEnd,
  });

  final int index;
  final int labelStart;
  final int labelEnd;

  String get label => '$labelStart - $labelEnd';
}

int maxEpisodeNumber(Iterable<int> episodeNumbers) {
  var max = 0;
  for (final n in episodeNumbers) {
    if (n > max) max = n;
  }
  return max;
}

/// Ranges like 1-50, 51-100 from the highest episode number in the list.
List<EpisodeRange> buildEpisodeRangesForNumbers(
  Iterable<int> episodeNumbers, {
  int chunkSize = kEpisodeRangeChunkSize,
}) {
  final max = maxEpisodeNumber(episodeNumbers);
  if (max <= chunkSize) return const [];
  final chunks = (max / chunkSize).ceil();
  return List.generate(chunks, (i) {
    final labelStart = i * chunkSize + 1;
    final labelEnd = ((i + 1) * chunkSize).clamp(0, max);
    return EpisodeRange(
      index: i,
      labelStart: labelStart,
      labelEnd: labelEnd,
    );
  });
}

bool showEpisodeRangeBar(
  Iterable<int> episodeNumbers, {
  int chunkSize = kEpisodeRangeChunkSize,
}) {
  return maxEpisodeNumber(episodeNumbers) > chunkSize;
}

int episodeChunkIndexForNumber(
  num episodeNumber, {
  int chunkSize = kEpisodeRangeChunkSize,
}) {
  final n = episodeNumber is int ? episodeNumber : episodeNumber.floor();
  if (n <= 0) return 0;
  return (n - 1) ~/ chunkSize;
}

List<T> filterEpisodeChunkByNumber<T>(
  List<T> items,
  int Function(T item) episodeNumberAt,
  int chunkIndex, {
  int chunkSize = kEpisodeRangeChunkSize,
}) {
  final start = chunkIndex * chunkSize + 1;
  final end = (chunkIndex + 1) * chunkSize;
  return items
      .where((e) {
        final n = episodeNumberAt(e);
        return n >= start && n <= end;
      })
      .toList();
}

/// Dropdown range picker (1-50, 51-100, …) for long episode lists.
class EpisodeRangeSelector extends StatelessWidget {
  const EpisodeRangeSelector({
    super.key,
    required this.ranges,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) return const SizedBox.shrink();

    final selected = ranges.firstWhere(
      (r) => r.index == selectedIndex,
      orElse: () => ranges.first,
    );
    final cinematic = ForjaShellColors.cinematic;

    // Cap the dropdown at 8 rows; taller lists scroll inside the panel.
    const double menuItemHeight = 44;
    const int maxVisibleRanges = 8;
    const double menuVerticalPadding = 8;
    final maxMenuHeight =
        menuItemHeight * maxVisibleRanges + menuVerticalPadding;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cinematic.menuSurface),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(double.infinity, maxMenuHeight),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      menuChildren: [
        for (final range in ranges)
          MenuItemButton(
            onPressed: () => onSelected(range.index),
            style: shellMenuItemStyle().merge(ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(
                Size(120, menuItemHeight),
              ),
              foregroundColor: WidgetStatePropertyAll(
                range.index == selectedIndex
                    ? cinematic.textPrimary
                    : cinematic.textSecondary,
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontWeight: range.index == selectedIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            )),
            child: Text(range.label),
          ),
      ],
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        const radius = 20.0;
        final trigger = shellRoundedInkHost(
          radius: radius,
          onTap: toggle,
          decoration: BoxDecoration(
            color: cinematic.menuSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: cinematic.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected.label,
                style: TextStyle(
                  color: cinematic.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: cinematic.textPrimary,
              ),
            ],
          ),
        );

        if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
          return trigger;
        }
        return shellFocusableTap(
          context: context,
          onTap: toggle,
          borderRadius: radius,
          showFocusBorder: true,
          child: trigger,
        );
      },
    );
  }
}
