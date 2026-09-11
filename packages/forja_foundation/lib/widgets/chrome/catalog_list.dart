import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/side_panel_overlay.dart';

/// Layout widget [`LayoutTypes.list`] chrome — body + optional side panel.
///
/// Host owns list data, Riverpod sources, and card builders.
class CatalogList extends StatelessWidget {
  const CatalogList({
    super.key,
    required this.body,
    this.header,
    this.sidePanel,
    this.sidePanelOpen = false,
    this.onDismissSidePanel,
    this.panelWidth = 380,
    this.useSideRail,
    this.padding,
  });

  final Widget body;
  final Widget? header;
  final Widget? sidePanel;
  final bool sidePanelOpen;
  final VoidCallback? onDismissSidePanel;
  final double panelWidth;
  final bool? useSideRail;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Expanded(child: body),
      ],
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (sidePanel == null) return content;

    return SidePanelOverlay(
      open: sidePanelOpen,
      panel: sidePanel!,
      onDismiss: onDismissSidePanel ?? () {},
      panelWidth: panelWidth,
      useSideRail: useSideRail,
      child: content,
    );
  }
}
