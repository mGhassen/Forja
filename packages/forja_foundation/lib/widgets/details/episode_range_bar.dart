import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

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
    this.useFocusableChips = false,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  /// Host maps [ShellInputPolicy.useFocusableMoodChips].
  final bool useFocusableChips;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) return const SizedBox.shrink();

    final selected = ranges.firstWhere(
      (r) => r.index == selectedIndex,
      orElse: () => ranges.first,
    );
    final cinematic = ForjaShellColors.cinematic;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final menuItemHeight = tv
        ? DetailsTokens.episodeRangeMenuHeightTv
        : DetailsTokens.episodeRangeMenuHeight;
    const maxVisibleRanges = DetailsTokens.episodeRangeMenuMaxRows;
    const menuVerticalPadding = 8.0;
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
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShellTokens.shellChipRadius),
          ),
        ),
      ),
      menuChildren: [
        for (final range in ranges)
          MenuItemButton(
            onPressed: () => onSelected(range.index),
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
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
            ),
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

        const radius = DetailsTokens.episodeRangeMenuRadius;
        final trigger = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: BoxDecoration(
                color: cinematic.menuSurface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: cinematic.borderSubtle),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected.label,
                      style: TextStyle(
                        color: cinematic.textPrimary,
                        fontSize: tv
                            ? ShellTokens.tvBodyFontSize
                            : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: ShellPaintScope.iconOf(context, 18),
                      color: cinematic.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (!useFocusableChips) return trigger;
        return FocusableTap(
          onTap: toggle,
          borderRadius: BorderRadius.circular(radius),
          child: trigger,
        );
      },
    );
  }
}
