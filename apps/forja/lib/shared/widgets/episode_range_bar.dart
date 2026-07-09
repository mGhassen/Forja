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

/// Horizontal numbered range chips (1-50, 51-100, …) for long episode lists.
class EpisodeRangeBar extends StatelessWidget {
  const EpisodeRangeBar({
    super.key,
    required this.ranges,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 30,
    this.compact = false,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) return const SizedBox.shrink();

    final radius = height / 2;
    final fontSize = compact ? 11.0 : 12.0;

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
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: shellChipDecoration(selected: selected, radius: radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: () => onSelected(range.index),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                    child: Center(
                      child: Text(
                        range.label,
                        style: TextStyle(
                          color: selected
                              ? ForjaShellColors.cinematic.textPrimary
                              : ForjaShellColors.cinematic.textSecondary,
                          fontSize: fontSize,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
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
