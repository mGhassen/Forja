import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/filter_sheet_option.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Generic catalog picker — flat [FilterSheetOption] rows (Zone A).
Future<String?> showCatalogFilterSheet(
  BuildContext context, {
  required String current,
  required List<({String id, String label, String? subtitle})> options,
  bool tvFocus = false,
  bool autofocusFirst = false,
  Widget Function(Widget body)? wrapBody,
  Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FocusNode? focusNode,
  })? optionInteractiveBuilder,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: ForjaShellColors.surfaceElevated,
    isScrollControlled: true,
    constraints: ShellPaintScope.usesTvDensityOf(context)
        ? const BoxConstraints(maxWidth: ShellTokens.filterSheetMaxWidthTv)
        : null,
    builder: (ctx) => CatalogFilterSheet(
      current: current,
      options: options,
      tvFocus: tvFocus,
      autofocusFirst: autofocusFirst,
      wrapBody: wrapBody,
      optionInteractiveBuilder: optionInteractiveBuilder,
    ),
  );
}

class CatalogFilterSheet extends StatefulWidget {
  const CatalogFilterSheet({
    super.key,
    required this.current,
    required this.options,
    this.tvFocus = false,
    this.autofocusFirst = false,
    this.wrapBody,
    this.optionInteractiveBuilder,
    this.radius,
    this.fontSize,
    this.padding,
  });

  final String current;
  final List<({String id, String label, String? subtitle})> options;
  final bool tvFocus;
  final bool autofocusFirst;
  final Widget Function(Widget body)? wrapBody;
  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FocusNode? focusNode,
  })? optionInteractiveBuilder;
  final double? radius;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  @override
  State<CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<CatalogFilterSheet> {
  final _firstFocus = FocusNode(debugLabel: 'catalog-filter-sheet-first');

  @override
  void initState() {
    super.initState();
    if (widget.autofocusFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_firstFocus.canRequestFocus) _firstFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.current.isEmpty || widget.current == 'all'
        ? 'all'
        : widget.current;

    Widget sheet(BuildContext densityContext) {
      final tv = ShellPaintScope.usesTvDensityOf(densityContext);
      final size = MediaQuery.sizeOf(densityContext);
      final maxHeight = size.height *
          (tv
              ? ShellTokens.filterSheetMaxHeightFractionTv
              : ShellTokens.filterSheetMaxHeightFraction);
      final titleSize = tv
          ? ShellTokens.filterSheetTitleFontSizeTv
          : (widget.fontSize ?? ShellTokens.filterSheetTitleFontSize);
      final subtitleSize = tv
          ? ShellTokens.filterSheetSubtitleFontSizeTv
          : (widget.fontSize != null
              ? widget.fontSize! - 3
              : ShellTokens.filterSheetSubtitleFontSize);
      final optionSize = tv
          ? ShellTokens.filterSheetOptionFontSizeTv
          : (widget.fontSize ?? ShellTokens.filterSheetOptionFontSize);
      final radius = widget.radius ??
          (tv ? ShellTokens.filterSheetRadiusTv : ShellTokens.filterSheetRadius);
      final padding = widget.padding ??
          EdgeInsets.fromLTRB(
            tv ? ShellTokens.filterSheetPadHTv : ShellTokens.filterSheetPadH,
            tv ? ShellTokens.filterSheetPadTopTv : ShellTokens.filterSheetPadTop,
            tv ? ShellTokens.filterSheetPadHTv : ShellTokens.filterSheetPadH,
            tv
                ? ShellTokens.filterSheetPadBottomTv
                : ShellTokens.filterSheetPadBottom,
          );

      return SafeArea(
        child: Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: tv ? ShellTokens.filterSheetMaxWidthTv : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: tv
                          ? ShellTokens.filterSheetHandleWidthTv
                          : ShellTokens.filterSheetHandleWidth,
                      height: tv
                          ? ShellTokens.filterSheetHandleHeightTv
                          : ShellTokens.filterSheetHandleHeight,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: tv
                        ? ShellTokens.filterSheetTitleGapTv
                        : ShellTokens.filterSheetTitleGap,
                  ),
                  Text(
                    'Catalog',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: tv
                        ? ShellTokens.filterSheetSubtitleGapTv
                        : ShellTokens.filterSheetSubtitleGap,
                  ),
                  Text(
                    'Filter the schedule by catalog:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: subtitleSize,
                    ),
                  ),
                  SizedBox(
                    height: tv
                        ? ShellTokens.filterSheetListGapTv
                        : ShellTokens.filterSheetListGap,
                  ),
                  for (var i = 0; i < widget.options.length; i++)
                    FilterSheetOption(
                      label: widget.options[i].label,
                      subtitle: widget.options[i].subtitle,
                      selected: widget.options[i].id == selectedId,
                      icon: widget.options[i].id == 'all'
                          ? Icons.grid_view_rounded
                          : Icons.video_library_rounded,
                      onSelected: () =>
                          Navigator.pop(context, widget.options[i].id),
                      tvFocus: widget.tvFocus,
                      focusNode: i == 0 ? _firstFocus : null,
                      interactiveBuilder: widget.optionInteractiveBuilder,
                      radius: radius,
                      fontSize: optionSize,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final core = Builder(builder: sheet);
    final wrap = widget.wrapBody;
    if (wrap == null || !widget.tvFocus) return core;
    return wrap(core);
  }
}
