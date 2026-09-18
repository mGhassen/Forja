import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Probe fields for the desktop hover detail card — opaque strings only.
class PortalProbeDetail {
  const PortalProbeDetail({
    this.statusLabel,
    this.alive,
    this.message,
    this.protocol,
    this.ports,
    this.timezone,
  });

  /// Account / probe status line (`Active`, `Banned`, `Unreachable`, …).
  final String? statusLabel;
  final bool? alive;
  final String? message;
  final String? protocol;

  /// Pre-joined ports line (`8080 · https 443 · rtmp 1935`).
  final String? ports;
  final String? timezone;
}

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
    this.expiry,
    this.activeConnections,
    this.maxConnections,
    this.favorite = false,
    this.isNew = false,
    this.deleting = false,
    this.probeDetail,
  });

  final String id;
  final String label;
  final String? subtitle;
  final bool selected;

  /// `true` ok · `false` failed · `null` unchecked.
  final bool? healthy;
  final bool checking;
  final String? platformLabel;
  final String? expiry;
  final String? activeConnections;
  final String? maxConnections;
  final bool favorite;
  final bool isNew;
  final bool deleting;

  /// Desktop 1s-hover card; null until a probe has run.
  final PortalProbeDetail? probeDetail;
}

/// Presentational portals list panel shell — props / slots only (RFC-095).
///
/// Features own search state, list filtering, and row actions. Pass [header],
/// optional [headerActions], [search], [status] / [statusText], and [body]
/// (or [items] + [itemBuilder]).
class PortalListPanel extends StatelessWidget {
  const PortalListPanel({
    super.key,
    required this.width,
    required this.header,
    this.body,
    this.surfaceColor,
    this.headerActions,
    this.search,
    this.searchOpen = false,
    this.status,
    this.statusText = '',
    this.items,
    this.itemBuilder,
    this.focusNode,
    this.onEscape,
    this.pad,
    this.statusFontSize = PortalListTokens.metaFontSize,
  }) : assert(
          body != null || (items != null && itemBuilder != null),
          'PortalListPanel requires body, or items + itemBuilder',
        );

  final double width;
  final Color? surfaceColor;
  final Widget header;

  /// Optional trailing / secondary chrome under [header].
  final Widget? headerActions;

  /// Collapsible search field; height animated via [searchOpen].
  final Widget? search;
  final bool searchOpen;

  /// Optional status chrome. When null, [statusText] is used if non-empty.
  final Widget? status;
  final String statusText;

  /// Full body slot. Prefer this when the host builds its own list.
  final Widget? body;

  /// Alternative to [body]: opaque rows + host [itemBuilder].
  final List<PortalListItem>? items;
  final Widget Function(BuildContext context, PortalListItem item, int index)?
      itemBuilder;

  final FocusNode? focusNode;
  final VoidCallback? onEscape;

  /// Status line padding. Null → h[PortalListTokens.panelPad] v4.
  final EdgeInsetsGeometry? pad;
  final double statusFontSize;

  Widget _resolvedBody(BuildContext context) {
    if (body != null) return body!;
    final list = items!;
    final build = itemBuilder!;
    final emptyFontSize = ShellPaintScope.usesTvDensityOf(context)
        ? PortalListTokens.titleFontSizeTv
        : PortalListTokens.titleFontSize;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No portals yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: emptyFontSize,
              height: 1.4,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) => build(context, list[i], i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        surfaceColor ?? ForjaShellColors.cinematic.menuSurface;
    final resolvedStatusFontSize = ShellPaintScope.usesTvDensityOf(context)
        ? PortalListTokens.metaFontSizeTv
        : statusFontSize;

    Widget? statusChild = status;
    if (statusChild == null && statusText.isNotEmpty) {
      statusChild = Padding(
        padding: pad ??
            const EdgeInsets.symmetric(
              horizontal: PortalListTokens.panelPad,
              vertical: 4,
            ),
        child: Text(
          statusText,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: resolvedStatusFontSize,
          ),
        ),
      );
    }

    Widget column = Material(
      color: surface,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            ?headerActions,
            if (search != null)
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  heightFactor: searchOpen ? 1 : 0,
                  duration: ForjaMotionTheme.of(context).scrollSnap.duration,
                  curve: Curves.easeOutCubic,
                  child: search!,
                ),
              ),
            ?statusChild,
            Expanded(child: _resolvedBody(context)),
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
