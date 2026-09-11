import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/kit/kit_filter_sheet_option.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Generic catalog picker — flat ListTile rows.
Future<String?> showKitCatalogFilterSheet(
  BuildContext context, {
  required String current,
  required List<({String id, String label, String? subtitle})> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: ForjaShellColors.surfaceElevated,
    isScrollControlled: true,
    builder: (ctx) => _KitCatalogSheet(
      current: current,
      options: options,
    ),
  );
}

class _KitCatalogSheet extends StatefulWidget {
  const _KitCatalogSheet({
    required this.current,
    required this.options,
  });

  final String current;
  final List<({String id, String label, String? subtitle})> options;

  @override
  State<_KitCatalogSheet> createState() => _KitCatalogSheetState();
}

class _KitCatalogSheetState extends State<_KitCatalogSheet> {
  static const _tvTabId = 'kit_catalog_sheet';
  static const _rowId = 'kit-catalog-sheet';
  final _firstFocus = FocusNode(debugLabel: 'kit-catalog-sheet-first');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId =
        widget.current.isEmpty || widget.current == 'all' ? 'all' : widget.current;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    final body = SafeArea(
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
                  'Catalog',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Filter the schedule by catalog:',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < widget.options.length; i++)
                  KitFilterSheetOption(
                    label: widget.options[i].label,
                    subtitle: widget.options[i].subtitle,
                    selected: widget.options[i].id == selectedId,
                    icon: widget.options[i].id == 'all'
                        ? Icons.grid_view_rounded
                        : Icons.video_library_rounded,
                    onSelected: () =>
                        Navigator.pop(context, widget.options[i].id),
                    tvTabId: _tvTabId,
                    tvRowId: _rowId,
                    tvItemIndex: i,
                    focusNode: i == 0 ? _firstFocus : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!tv) return body;
    return TvKitRow(
      tabId: _tvTabId,
      rowId: _rowId,
      sortOrder: 0,
      itemCount: widget.options.length,
      orientation: ShellTvRowOrientation.vertical,
      child: body,
    );
  }
}
