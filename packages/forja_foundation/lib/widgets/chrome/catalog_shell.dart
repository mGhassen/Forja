import 'package:flutter/material.dart';
import 'package:forja_foundation/blocks/shell/shell_block.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Catalog hub page paint — loading / error / body slots (RFC-106 Zone A).
///
/// Host wires MetaRuntime, layout walk, TV graph, and section builders into
/// these slots.
class CatalogShell extends StatelessWidget {
  const CatalogShell({
    super.key,
    required this.backgroundColor,
    this.textDirection,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.loadingChild,
    this.errorChild,
    this.body,
    this.topBar,
    this.sideRail,
    this.sideRailWidth = 220,
    this.railOnLeading = true,
    this.layout,
    this.sectionBuilder,
    this.wrapBody,
  });

  final Color backgroundColor;
  final TextDirection? textDirection;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? loadingChild;
  final Widget? errorChild;
  final Widget? body;
  final Widget? topBar;
  final Widget? sideRail;
  final double sideRailWidth;
  final bool railOnLeading;

  /// Pack layout widgets — when set with [sectionBuilder], builds a list.
  final List<Map<String, dynamic>>? layout;
  final Widget? Function(Map<String, dynamic> spec, int index)? sectionBuilder;

  /// Host TV / focus graph wrap around the resolved body.
  final Widget Function(Widget body)? wrapBody;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    Widget content;
    if (loading) {
      content = loadingChild ??
          Center(
            child: CircularProgressIndicator(color: theme.brandGreen),
          );
    } else if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      content = errorChild ??
          Center(
            child: Padding(
              padding: EdgeInsets.all(theme.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  if (onRetry != null) ...[
                    SizedBox(height: theme.spaceMd),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          );
    } else if (body != null) {
      content = body!;
    } else if (layout != null && sectionBuilder != null) {
      final sections = <Widget>[];
      for (var i = 0; i < layout!.length; i++) {
        final w = sectionBuilder!(layout![i], i);
        if (w != null) sections.add(w);
      }
      content = sections.isEmpty
          ? const SizedBox.shrink()
          : ListView(children: sections);
    } else {
      content = const SizedBox.shrink();
    }

    final wrapped = wrapBody?.call(content) ?? content;
    final page = topBar != null || sideRail != null
        ? ShellBlock(
            topBar: topBar,
            body: wrapped,
            sideRail: sideRail,
            sideRailWidth: sideRailWidth,
            railOnLeading: railOnLeading,
          )
        : wrapped;

    Widget root = ColoredBox(color: backgroundColor, child: page);
    if (textDirection != null) {
      root = Directionality(textDirection: textDirection!, child: root);
    }
    return root;
  }
}
