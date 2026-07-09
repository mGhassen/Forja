import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

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

List<EpisodeRange> buildEpisodeRanges(
  int episodeCount, {
  int chunkSize = kEpisodeRangeChunkSize,
  List<int>? episodeNumbers,
}) {
  if (episodeCount <= 0) return const [];
  final chunks = (episodeCount / chunkSize).ceil();
  return List.generate(chunks, (i) {
    final startIdx = i * chunkSize;
    final endIdx = ((i + 1) * chunkSize).clamp(0, episodeCount);
    final labelStart = episodeNumbers != null && episodeNumbers.isNotEmpty
        ? episodeNumbers[startIdx]
        : startIdx + 1;
    final labelEnd = episodeNumbers != null && episodeNumbers.isNotEmpty
        ? episodeNumbers[endIdx - 1]
        : endIdx;
    return EpisodeRange(
      index: i,
      labelStart: labelStart,
      labelEnd: labelEnd,
    );
  });
}

int episodeChunkIndex(int listIndex, {int chunkSize = kEpisodeRangeChunkSize}) {
  if (listIndex < 0) return 0;
  return listIndex ~/ chunkSize;
}

List<T> sliceEpisodeChunk<T>(
  List<T> items,
  int chunkIndex, {
  int chunkSize = kEpisodeRangeChunkSize,
}) {
  final start = chunkIndex * chunkSize;
  if (start >= items.length) return const [];
  final end = (start + chunkSize).clamp(0, items.length);
  return items.sublist(start, end);
}

/// Horizontal numbered range chips (1-50, 51-100, …) for long episode lists.
class EpisodeRangeBar extends StatelessWidget {
  const EpisodeRangeBar({
    super.key,
    required this.ranges,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 36,
    this.compact = false,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (ranges.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: ranges.length,
        separatorBuilder: (_, _) => SizedBox(width: compact ? 6 : 8),
        itemBuilder: (_, i) {
          final range = ranges[i];
          final selected = i == selectedIndex;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(range.index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                decoration: shellChipDecoration(selected: selected, radius: 18),
                child: Text(
                  range.label,
                  style: TextStyle(
                    color: selected
                        ? ForjaShellColors.cinematic.textPrimary
                        : ForjaShellColors.cinematic.textSecondary,
                    fontSize: compact ? 11 : 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
