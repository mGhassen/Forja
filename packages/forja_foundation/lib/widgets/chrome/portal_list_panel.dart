import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// One portal row for [PortalListPanel] — opaque display fields only.
class PortalListItem {
  const PortalListItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.selected = false,
    this.healthy,
    this.checking = false,
    this.platformLabel,
  });

  final String id;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool? healthy;
  final bool checking;
  final String? platformLabel;
}

/// Presentational portals list panel shell — props / slots only (RFC-095).
///
/// Features own search state, list filtering, and row actions. Pass [header],
/// optional [search], [statusText], and [body] (or [items] + [itemBuilder]).
class PortalListPanel extends StatelessWidget {
  const PortalListPanel({
    super.key,
    required this.width,
    required this.header,
    required this.body,
    this.surfaceColor,
    this.search,
    this.searchOpen = false,
    this.statusText = '',
    this.focusNode,
    this.onEscape,
  });

  final double width;
  final Color? surfaceColor;
  final Widget header;
  /// Collapsible search field; height animated via [searchOpen].
  final Widget? search;
  final bool searchOpen;
  final String statusText;
  final Widget body;
  final FocusNode? focusNode;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    final surface = surfaceColor ?? const Color(0xFF12141A);

    Widget column = Material(
      color: surface,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (search != null)
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: searchOpen ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: search!,
                ),
              ),
            if (statusText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );

    if (focusNode == null && onEscape == null) return column;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          onEscape?.call();
          return onEscape != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: column,
    );
  }
}
