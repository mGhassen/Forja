import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';

/// Old Live Sports Catalog sheet — flat ListTile rows (not bordered cards).
Future<String?> showLiveCatalogSheet(
  BuildContext context, {
  required String current,
  required List<({String id, String label, String? subtitle})> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: ForjaShellColors.surfaceElevated,
    isScrollControlled: true,
    builder: (ctx) => _LiveCatalogSheet(
      current: current,
      options: options,
    ),
  );
}

class _LiveCatalogSheet extends StatefulWidget {
  const _LiveCatalogSheet({
    required this.current,
    required this.options,
  });

  final String current;
  final List<({String id, String label, String? subtitle})> options;

  @override
  State<_LiveCatalogSheet> createState() => _LiveCatalogSheetState();
}

class _LiveCatalogSheetState extends State<_LiveCatalogSheet> {
  static const _tvTabId = 'live_matches_catalog_sheet';
  static const _rowId = 'live-catalog-sheet';
  final _firstFocus = FocusNode(debugLabel: 'live-catalog-sheet-first');

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
                  LiveFilterSheetOption(
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

/// Flat list row for Live Sports filter sheets (Catalog / Schedule).
/// ListTile + ink hover — not bordered green cards.
class LiveFilterSheetOption extends StatefulWidget {
  const LiveFilterSheetOption({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
    required this.tvTabId,
    this.subtitle,
    this.tvItemIndex,
    this.tvRowId,
    this.focusNode,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final String tvTabId;
  final int? tvItemIndex;
  final String? tvRowId;
  final FocusNode? focusNode;

  @override
  State<LiveFilterSheetOption> createState() => _LiveFilterSheetOptionState();
}

class _LiveFilterSheetOptionState extends State<LiveFilterSheetOption> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final mouseHover = policy.scaleOnHover;
    final tvFocus = policy.useFocusableMoodChips;
    final highlight = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    const radius = 12.0;

    final tile = ListTile(
      leading: Icon(
        widget.icon,
        color: widget.selected
            ? ForjaShellColors.sectionAccent
            : Colors.white54,
      ),
      title: Text(
        widget.label,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              highlight || widget.selected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: (widget.subtitle ?? '').trim().isEmpty
          ? null
          : Text(
              widget.subtitle!.trim(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
      trailing: widget.selected
          ? Icon(Icons.check_rounded, color: ForjaShellColors.sectionAccent)
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );

    final row = Material(
      color: highlight ? ForjaShellColors.inkHover : Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        canRequestFocus: false,
        onTap: tvFocus ? null : widget.onSelected,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: Colors.transparent,
        splashColor: ForjaShellColors.inkSplash,
        child: tile,
      ),
    );

    if (!tvFocus) {
      return shellRoundedInkHost(
        radius: radius,
        onTap: widget.onSelected,
        child: tile,
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onSelected,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      navLeftAlways: true,
      focusNode: widget.focusNode,
      listIndex: widget.tvItemIndex,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvItemIndex: widget.tvItemIndex,
      tvZone: ShellTvZone.row,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: mouseHover
          ? (hovered) => setState(() => _hovered = hovered)
          : null,
      child: row,
    );
  }
}
