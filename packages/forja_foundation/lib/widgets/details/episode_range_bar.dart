import 'package:flutter/material.dart';
import 'package:forja_foundation/components/dialog.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

const int kEpisodeRangeChunkSize = 50;

/// Pack setting `episodeView` — still cards (default).
const String kEpisodeViewCards = 'cards';

/// Pack setting `episodeView` — numbered chips in a wrap grid.
const String kEpisodeViewChips = 'chips';

bool episodeViewIsChips(String? raw) =>
    (raw ?? '').trim().toLowerCase() == kEpisodeViewChips;

/// TV focus rows owned by the episode picker (view chrome → seasons → episodes).
///
/// View chrome (cards/chips toggle + optional range) is always one row when
/// [hasEpisodes] — range no longer adds a separate focus row.
int detailsEpisodeFocusRowCount({
  required bool hasEpisodes,
  required int seasonCount,
  @Deprecated('Ignored — view chrome is always present when hasEpisodes')
  bool showRange = false,
}) {
  if (!hasEpisodes) return 0;
  var n = 2; // view chrome + episodes
  if (seasonCount > 1) n++;
  return n;
}

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
    return EpisodeRange(index: i, labelStart: labelStart, labelEnd: labelEnd);
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
  return items.where((e) {
    final n = episodeNumberAt(e);
    return n >= start && n <= end;
  }).toList();
}

/// Dropdown range picker (1-50, 51-100, …) for long episode lists.
///
/// Desktop / phone: Material [MenuAnchor].
/// Leanback TV: focusable select dialog (MenuAnchor items are not D-pad safe).
class EpisodeRangeSelector extends StatelessWidget {
  const EpisodeRangeSelector({
    super.key,
    required this.ranges,
    required this.selectedIndex,
    required this.onSelected,
    this.useFocusableChips = false,
    this.listIndex = 0,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Host maps [ShellInputPolicy.useFocusableMoodChips].
  final bool useFocusableChips;

  /// TV focus index within the parent chrome row (after view-toggle slots).
  final int listIndex;

  EpisodeRange get _selected => ranges.firstWhere(
    (r) => r.index == selectedIndex,
    orElse: () => ranges.first,
  );

  Widget _triggerVisual(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    const radius = DetailsTokens.episodeRangeMenuRadius;
    return Ink(
      decoration: BoxDecoration(
        color: cinematic.menuSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cinematic.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selected.label,
              style: TextStyle(
                color: cinematic.textPrimary,
                fontSize: tv ? ShellTokens.tvBodyFontSize : 13,
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
    );
  }

  Future<void> _openTvPicker(BuildContext context) async {
    final picked = await showForjaDialog<int>(
      context: context,
      title: 'Episode range',
      body: _EpisodeRangePickerBody(
        ranges: ranges,
        selectedIndex: selectedIndex,
      ),
    );
    if (picked == null || !context.mounted) return;
    onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) return const SizedBox.shrink();

    const radius = DetailsTokens.episodeRangeMenuRadius;

    if (useFocusableChips) {
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: () => _openTvPicker(context),
        borderRadius: radius,
        listIndex: listIndex,
        tvItemIndex: listIndex,
        showFocusBorder: true,
        child: Material(
          color: Colors.transparent,
          child: _triggerVisual(context),
        ),
      );
    }

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
              minimumSize: WidgetStatePropertyAll(Size(120, menuItemHeight)),
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

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(radius),
            child: _triggerVisual(context),
          ),
        );
      },
    );
  }
}

class _EpisodeRangePickerBody extends StatelessWidget {
  const _EpisodeRangePickerBody({
    required this.ranges,
    required this.selectedIndex,
  });

  final List<EpisodeRange> ranges;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final size = MediaQuery.sizeOf(context);
    final maxH = SettingsTokens.dialogMaxHeightOf(context, size.height);
    final optionPadH = SettingsTokens.dialogOptionPadHOf(context);
    final optionPadV = SettingsTokens.dialogOptionPadVOf(context);
    final checkSize = SettingsTokens.dialogCheckSizeOf(context);
    final radius = SettingsTokens.categoryTileRadius;

    Widget optionRow(EpisodeRange range) {
      final selected = range.index == selectedIndex;
      final label = Text(
        range.label,
        style: TextStyle(
          color: selected ? cinematic.textPrimary : cinematic.textSecondary,
          fontSize: tv ? ShellTokens.tvBodyFontSize : 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      final row = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: optionPadH,
          vertical: optionPadV,
        ),
        child: Row(
          children: [
            Expanded(child: label),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: ForjaShellColors.brandGreen,
                size: checkSize,
              ),
          ],
        ),
      );

      void pick() {
        final nav = Navigator.of(context);
        if (!nav.canPop()) return;
        nav.pop(range.index);
      }

      if (!ShellPaintScope.useTvFocusOf(context)) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: pick,
            borderRadius: BorderRadius.circular(radius),
            child: row,
          ),
        );
      }

      // No listIndex — keep Left from yanking focus to the shell nav rail.
      return ShellPaintScope.focusableTap(
        context: context,
        onTap: pick,
        borderRadius: radius,
        autoFocus: range.index == selectedIndex,
        showFocusRail: true,
        scaleOnFocus: 1,
        ensureVisibleMode: ShellPaintEnsureVisible.item,
        child: row,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: ranges.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (_, i) => optionRow(ranges[i]),
      ),
    );
  }
}
