import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/actions/schedule/kit_schedule_window.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';

/// Live schedule sheet — Status × Horizon (not a flat time list).
///
/// Picks apply live via [onChanged]; the sheet stays open until dismissed.
Future<void> showKitScheduleWindowSheet(
  BuildContext context, {
  required KitScheduleStatus status,
  required KitScheduleHorizon horizon,
  required void Function({
    KitScheduleStatus? status,
    KitScheduleHorizon? horizon,
  }) onChanged,
}) {
  final tv = ShellScope.metricsOf(context).usesTvDensity;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ForjaShellColors.surfaceElevated,
    isScrollControlled: true,
    constraints: tv
        ? const BoxConstraints(maxWidth: ShellTokens.filterSheetMaxWidthTv)
        : null,
    builder: (ctx) => ShellScope.rehost(
      context,
      _LiveScheduleSheet(
        status: status,
        horizon: horizon,
        onChanged: onChanged,
      ),
    ),
  );
}

class _LiveScheduleSheet extends StatefulWidget {
  const _LiveScheduleSheet({
    required this.status,
    required this.horizon,
    required this.onChanged,
  });

  final KitScheduleStatus status;
  final KitScheduleHorizon horizon;
  final void Function({
    KitScheduleStatus? status,
    KitScheduleHorizon? horizon,
  }) onChanged;

  @override
  State<_LiveScheduleSheet> createState() => _LiveScheduleSheetState();
}

class _LiveScheduleSheetState extends State<_LiveScheduleSheet> {
  static const _tvTabId = 'live_sports_schedule_sheet';
  static const _statusRowId = 'live-schedule-status';
  static const _horizonRowId = 'live-schedule-horizon';
  final _firstFocus = FocusNode(debugLabel: 'live-schedule-sheet-first');

  late KitScheduleStatus _status;
  late KitScheduleHorizon _horizon;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _horizon = widget.horizon;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _LiveScheduleSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _status = widget.status;
    if (oldWidget.horizon != widget.horizon) _horizon = widget.horizon;
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  bool get _showHorizon => _status != KitScheduleStatus.airing;

  void _pickStatus(KitScheduleStatus status) {
    setState(() => _status = status);
    widget.onChanged(status: status);
  }

  void _pickHorizon(KitScheduleHorizon horizon) {
    setState(() => _horizon = horizon);
    widget.onChanged(horizon: horizon);
  }

  Widget _option({
    required String label,
    required String subtitle,
    required bool selected,
    required IconData icon,
    required VoidCallback onSelected,
    required String rowId,
    required int index,
    FocusNode? focusNode,
  }) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    return FilterSheetOption(
      label: label,
      subtitle: subtitle,
      selected: selected,
      icon: icon,
      onSelected: onSelected,
      tvFocus: tv,
      focusNode: focusNode,
      interactiveBuilder: tv
          ? ({
              required child,
              required onTap,
              onFocusChange,
              onHoverChange,
              focusNode,
            }) =>
              shellFocusableTap(
                context: context,
                onTap: onTap,
                borderRadius: 12,
                scaleOnFocus: 1.0,
                tvZone: ShellTvZone.topBar,
                tvTabId: _tvTabId,
                tvRowId: rowId,
                tvItemIndex: index,
                focusNode: focusNode,
                onFocusChange: onFocusChange,
                onHoverChange: onHoverChange,
                child: child,
              )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tvDensity = ShellScope.metricsOf(context).usesTvDensity;
    final maxHeight = MediaQuery.sizeOf(context).height *
        (tvDensity
            ? ShellTokens.filterSheetMaxHeightFractionTv
            : ShellTokens.filterSheetMaxHeightFraction);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final titleSize = tvDensity
        ? ShellTokens.filterSheetTitleFontSizeTv
        : ShellTokens.filterSheetTitleFontSize;
    final subtitleSize = tvDensity
        ? ShellTokens.filterSheetSubtitleFontSizeTv
        : ShellTokens.filterSheetSubtitleFontSize;
    final sectionSize = tvDensity
        ? ShellTokens.filterSheetOptionFontSizeTv
        : ShellTokens.filterSheetSubtitleFontSize;
    final padH = tvDensity
        ? ShellTokens.filterSheetPadHTv
        : ShellTokens.filterSheetPadH;
    final padTop = tvDensity
        ? ShellTokens.filterSheetPadTopTv
        : ShellTokens.filterSheetPadTop;
    final padBottom = tvDensity
        ? ShellTokens.filterSheetPadBottomTv
        : ShellTokens.filterSheetPadBottom;
    final statuses = KitScheduleStatus.values;
    final horizons = KitScheduleHorizon.values;

    Widget statusSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < statuses.length; i++)
          _option(
            label: statuses[i].label,
            subtitle: statuses[i].subtitle,
            selected: statuses[i] == _status,
            icon: Icons.sensors_rounded,
            onSelected: () => _pickStatus(statuses[i]),
            rowId: _statusRowId,
            index: i,
            focusNode: i == 0 ? _firstFocus : null,
          ),
      ],
    );
    if (tv) {
      statusSection = TvKitRow(
        tabId: _tvTabId,
        rowId: _statusRowId,
        sortOrder: 0,
        itemCount: statuses.length,
        orientation: ShellTvRowOrientation.vertical,
        child: statusSection,
      );
    }

    Widget? horizonSection;
    if (_showHorizon) {
      horizonSection = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < horizons.length; i++)
            _option(
              label: horizons[i].label,
              subtitle: horizons[i].subtitle,
              selected: horizons[i] == _horizon,
              icon: Icons.schedule_rounded,
              onSelected: () => _pickHorizon(horizons[i]),
              rowId: _horizonRowId,
              index: i,
            ),
        ],
      );
      if (tv) {
        horizonSection = TvKitRow(
          tabId: _tvTabId,
          rowId: _horizonRowId,
          sortOrder: 1,
          itemCount: horizons.length,
          orientation: ShellTvRowOrientation.vertical,
          child: horizonSection,
        );
      }
    }

    // ListView(shrinkWrap) sizes to children up to [maxHeight]. A plain
    // SingleChildScrollView expands to the max and leaves a tall empty panel
    // on TV when Status-only content is short.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: tvDensity
                ? ShellTokens.filterSheetMaxWidthTv
                : double.infinity,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  width: tvDensity
                      ? ShellTokens.filterSheetHandleWidthTv
                      : ShellTokens.filterSheetHandleWidth,
                  height: tvDensity
                      ? ShellTokens.filterSheetHandleHeightTv
                      : ShellTokens.filterSheetHandleHeight,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(
                height: tvDensity
                    ? ShellTokens.filterSheetTitleGapTv
                    : ShellTokens.filterSheetTitleGap,
              ),
              Text(
                'Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                height: tvDensity
                    ? ShellTokens.filterSheetSubtitleGapTv
                    : ShellTokens.filterSheetSubtitleGap,
              ),
              Text(
                'What to show, and how far ahead to load upcoming:',
                style: TextStyle(color: Colors.white54, fontSize: subtitleSize),
              ),
              SizedBox(
                height: tvDensity
                    ? ShellTokens.filterSheetListGapTv
                    : 18,
              ),
              Text(
                'Status',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: sectionSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tvDensity ? 6 : 8),
              statusSection,
              if (horizonSection != null) ...[
                SizedBox(height: tvDensity ? 10 : 16),
                Text(
                  'Horizon',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: sectionSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tvDensity ? 6 : 8),
                horizonSection,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
