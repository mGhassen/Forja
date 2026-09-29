import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/event_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Display names from pack `props.catalogs` (`["PPV", "ESPN"]` or `{name}`).
List<String> eventCatalogLabels(Object? raw) {
  if (raw is! List || raw.isEmpty) return const [];
  final out = <String>[];
  final seen = <String>{};
  for (final item in raw) {
    final label = switch (item) {
      final String s => s.trim(),
      final Map m =>
        (m['name'] ?? m['label'] ?? m['id'] ?? '').toString().trim(),
      _ => '',
    };
    if (label.isEmpty) continue;
    if (!seen.add(label.toLowerCase())) continue;
    out.add(label);
  }
  return out;
}

/// After [EventCardTokens.catalogHoverDelay] of hover or focus, lists catalogs.
///
/// The panel ignores pointers so it does not steal the row's [MouseRegion].
class EventCatalogHover extends StatefulWidget {
  const EventCatalogHover({
    super.key,
    required this.catalogs,
    required this.armed,
    required this.child,
  });

  final List<String> catalogs;
  final bool armed;
  final Widget child;

  @override
  State<EventCatalogHover> createState() => _EventCatalogHoverState();
}

class _EventCatalogHoverState extends State<EventCatalogHover> {
  final LayerLink _link = LayerLink();
  Timer? _timer;
  OverlayEntry? _entry;

  bool get _hasCatalogs => widget.catalogs.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.armed && _hasCatalogs) _schedule();
  }

  @override
  void didUpdateWidget(covariant EventCatalogHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.armed || !_hasCatalogs) {
      _hide();
      return;
    }
    if (!oldWidget.armed || oldWidget.catalogs.isEmpty) {
      _schedule();
      return;
    }
    if (!_same(oldWidget.catalogs, widget.catalogs)) {
      _markOverlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(EventCardTokens.catalogHoverDelay, () {
      if (!mounted || !widget.armed || !_hasCatalogs) return;
      _show();
    });
  }

  void _show() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final existing = _entry;
    if (existing != null) {
      if (existing.mounted) {
        _markOverlay();
        return;
      }
      _entry = null;
    }
    final entry = OverlayEntry(
      builder: (context) {
        return CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, EventCardTokens.catalogHoverGap),
          child: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: IgnorePointer(
              child: _EventCatalogHoverCard(catalogs: widget.catalogs),
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _markOverlay() {
    final entry = _entry;
    if (entry == null || !entry.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _entry;
      if (current == null || !current.mounted) return;
      current.markNeedsBuild();
    });
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _link, child: widget.child);
  }
}

class _EventCatalogHoverCard extends StatelessWidget {
  const _EventCatalogHoverCard({required this.catalogs});

  final List<String> catalogs;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final pad = ShellTokens.chromeScale(EventCardTokens.catalogHoverPad, tv: tv);
    final titleSize = ShellTokens.chromeScale(
      EventCardTokens.catalogHoverTitleSize,
      tv: tv,
    );
    final labelSize = ShellTokens.chromeScale(
      EventCardTokens.catalogHoverLabelSize,
      tv: tv,
    );
    final labelGap = ShellTokens.chromeScale(
      EventCardTokens.catalogHoverLabelGap,
      tv: tv,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForjaShellColors.surfaceElevated,
        borderRadius: BorderRadius.circular(EventCardTokens.catalogHoverRadius),
        border: Border.all(color: ForjaShellColors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: EventCardTokens.catalogHoverMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Catalogs',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              SizedBox(height: labelGap),
              for (final name in catalogs)
                Padding(
                  padding: EdgeInsets.only(top: labelGap),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
