import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/host/live_sports/live_catalog_sheet.dart';
import 'package:forja/shared/host/live_sports/live_schedule_window.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';

/// Old Live Sports Schedule sheet — Status × Horizon (not a flat time list).
///
/// Picks apply live via [onChanged]; the sheet stays open until dismissed.
Future<void> showLiveScheduleSheet(
  BuildContext context, {
  required LiveScheduleStatus status,
  required LiveScheduleHorizon horizon,
  required void Function({
    LiveScheduleStatus? status,
    LiveScheduleHorizon? horizon,
  }) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ForjaShellColors.surfaceElevated,
    isScrollControlled: true,
    builder: (ctx) => _LiveScheduleSheet(
      status: status,
      horizon: horizon,
      onChanged: onChanged,
    ),
  );
}

class _LiveScheduleSheet extends StatefulWidget {
  const _LiveScheduleSheet({
    required this.status,
    required this.horizon,
    required this.onChanged,
  });

  final LiveScheduleStatus status;
  final LiveScheduleHorizon horizon;
  final void Function({
    LiveScheduleStatus? status,
    LiveScheduleHorizon? horizon,
  }) onChanged;

  @override
  State<_LiveScheduleSheet> createState() => _LiveScheduleSheetState();
}

class _LiveScheduleSheetState extends State<_LiveScheduleSheet> {
  static const _tvTabId = 'live_sports_schedule_sheet';
  static const _statusRowId = 'live-schedule-status';
  static const _horizonRowId = 'live-schedule-horizon';
  final _firstFocus = FocusNode(debugLabel: 'live-schedule-sheet-first');

  late LiveScheduleStatus _status;
  late LiveScheduleHorizon _horizon;

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

  bool get _showHorizon => _status != LiveScheduleStatus.airing;

  void _pickStatus(LiveScheduleStatus status) {
    setState(() => _status = status);
    widget.onChanged(status: status);
  }

  void _pickHorizon(LiveScheduleHorizon horizon) {
    setState(() => _horizon = horizon);
    widget.onChanged(horizon: horizon);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final statuses = LiveScheduleStatus.values;
    final horizons = LiveScheduleHorizon.values;

    Widget statusSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < statuses.length; i++)
          LiveFilterSheetOption(
            label: statuses[i].label,
            subtitle: statuses[i].subtitle,
            selected: statuses[i] == _status,
            icon: Icons.sensors_rounded,
            onSelected: () => _pickStatus(statuses[i]),
            tvTabId: _tvTabId,
            tvRowId: _statusRowId,
            tvItemIndex: i,
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
            LiveFilterSheetOption(
              label: horizons[i].label,
              subtitle: horizons[i].subtitle,
              selected: horizons[i] == _horizon,
              icon: Icons.schedule_rounded,
              onSelected: () => _pickHorizon(horizons[i]),
              tvTabId: _tvTabId,
              tvRowId: _horizonRowId,
              tvItemIndex: i,
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'What to show, and how far ahead to load upcoming:',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Status',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                statusSection,
                if (horizonSection != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Horizon',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  horizonSection,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
