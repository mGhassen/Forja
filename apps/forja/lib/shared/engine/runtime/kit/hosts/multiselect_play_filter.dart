import 'package:flutter/material.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';
import 'package:google_fonts/google_fonts.dart';

/// SUB | DUB glass group — each segment opens a multiselect language dropdown.
///
/// Selection is exclusive across kinds: picking a SUB language clears DUB
/// (and the reverse). Empty selection = all providers.
///
/// TV: floating [Overlay] + [TvOverlayScope] (same pattern as My List) — not
/// [MenuAnchor], which never joins the leanback focus graph.
///
/// Menu position uses [RenderBox.localToGlobal] (not [CompositedTransformFollower])
/// so the hero action-row [FittedBox] cannot leave a full-size ghost pill.
class KitMultiselectPlayFilter extends StatelessWidget {
  const KitMultiselectPlayFilter({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.tvTabId,
    this.tvItemIndexStart,
    this.onUpEdge,
  });

  final List<PluginLanguage> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String? tvTabId;
  final int? tvItemIndexStart;
  final VoidCallback? onUpEdge;

  /// Hero-row focus slots: one per kind that has languages (SUB and/or DUB).
  static int focusSlotCount(List<PluginLanguage> options) {
    var n = 0;
    if (options.any((o) => o.kind == 'sub')) n++;
    if (options.any((o) => o.kind == 'dub')) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final subs = [
      for (final o in options)
        if (o.kind == 'sub') o,
    ];
    final dubs = [
      for (final o in options)
        if (o.kind == 'dub') o,
    ];
    if (subs.isEmpty && dubs.isEmpty) return const SizedBox.shrink();

    final useTvCompact = ShellScope.inputPolicyOf(
      context,
    ).useFocusableMoodChips;
    final segments =
        <
          ({
            String kind,
            String label,
            IconData icon,
            List<PluginLanguage> langs,
          })
        >[
          if (subs.isNotEmpty)
            (
              kind: 'sub',
              label: 'SUB',
              icon: Icons.subtitles_rounded,
              langs: subs,
            ),
          if (dubs.isNotEmpty)
            (kind: 'dub', label: 'DUB', icon: Icons.mic_rounded, langs: dubs),
        ];

    return HeroPillGlassShell(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const HeroPillSlotDivider(),
          _KindDropdownSegment(
            kind: segments[i].kind,
            label: segments[i].label,
            icon: segments[i].icon,
            langs: segments[i].langs,
            selected: selected,
            onChanged: onChanged,
            isFirst: i == 0,
            isLast: i == segments.length - 1,
            useTvCompact: useTvCompact,
            tvTabId: tvTabId,
            tvItemIndex: tvItemIndexStart != null
                ? tvItemIndexStart! + i
                : null,
            onUpEdge: onUpEdge,
          ),
        ],
      ],
    );
  }
}

class _KindDropdownSegment extends StatefulWidget {
  const _KindDropdownSegment({
    required this.kind,
    required this.label,
    required this.icon,
    required this.langs,
    required this.selected,
    required this.onChanged,
    required this.isFirst,
    required this.isLast,
    required this.useTvCompact,
    this.tvTabId,
    this.tvItemIndex,
    this.onUpEdge,
  });

  final String kind;
  final String label;
  final IconData icon;
  final List<PluginLanguage> langs;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool isFirst;
  final bool isLast;
  final bool useTvCompact;
  final String? tvTabId;
  final int? tvItemIndex;
  final VoidCallback? onUpEdge;

  @override
  State<_KindDropdownSegment> createState() => _KindDropdownSegmentState();
}

class _KindDropdownSegmentState extends State<_KindDropdownSegment> {
  OverlayEntry? _entry;
  FocusNode? _returnFocus;
  bool _restoreFocusOnClose = false;

  bool get _open => _entry != null;

  bool get _kindActive {
    if (widget.selected.isEmpty) return false;
    return widget.langs.any((l) => widget.selected.contains(l.key));
  }

  int get _kindCount =>
      widget.langs.where((l) => widget.selected.contains(l.key)).length;

  /// Refresh open menu after parent applies selection — never from
  /// [didUpdateWidget] (that runs mid-build and asserts on OverlayEntry).
  void _scheduleOverlayRefresh() {
    final entry = _entry;
    if (entry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_entry, entry)) return;
      entry.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _clearTvDismiss();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  void _registerTvDismiss() {
    ShellTvFocusCoordinator.setTransientOverlayDismiss(() {
      if (_entry == null) return false;
      _close();
      return true;
    });
  }

  void _clearTvDismiss() {
    ShellTvFocusCoordinator.setTransientOverlayDismiss(null);
  }

  void _close() {
    if (_entry == null) return;
    _clearTvDismiss();
    _removeOverlay();
    final back = _restoreFocusOnClose ? _returnFocus : null;
    _returnFocus = null;
    _restoreFocusOnClose = false;
    if (mounted) setState(() {});
    if (back == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (back.canRequestFocus) back.requestFocus();
    });
  }

  void _toggleKey(String key, bool checked) {
    final isEs = key.endsWith(':es');
    final next = <String>{};
    if (checked) {
      for (final k in widget.selected) {
        // ES spans SUB+DUB — keep sibling es keys; still exclusive vs other langs.
        if (k.startsWith('${widget.kind}:') || (isEs && k.endsWith(':es'))) {
          next.add(k);
        }
      }
      next.add(key);
      if (isEs) {
        next.add('sub:es');
        next.add('dub:es');
      }
    } else if (isEs) {
      for (final k in widget.selected) {
        if (!k.endsWith(':es')) next.add(k);
      }
    } else {
      for (final k in widget.selected) {
        if (k != key) next.add(k);
      }
    }
    widget.onChanged(next);
    _scheduleOverlayRefresh();
  }

  void _clearKind() {
    final next = {
      for (final k in widget.selected)
        if (!k.startsWith('${widget.kind}:') &&
            // Clearing SUB or DUB also drops the shared ES bucket keys.
            !k.endsWith(':es'))
          k,
    };
    widget.onChanged(next);
    _scheduleOverlayRefresh();
  }

  Rect? _anchorRectInOverlay(BuildContext overlayContext) {
    if (!mounted) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return null;
    final offset = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    return offset & renderObject.size;
  }

  Widget _rehostPaint(BuildContext hostContext, Widget child) {
    final paint = ShellPaintScope.maybeOf(hostContext);
    if (paint == null) return child;
    return ShellPaintScope(
      useTvFocus: paint.useTvFocus,
      scaleOnHover: paint.scaleOnHover,
      focusStyled: paint.focusStyled,
      usesTvDensity: paint.usesTvDensity,
      focusableTapBuilder: paint.focusableTapBuilder,
      wrapTvRow: paint.wrapTvRow,
      wrapTvGrid: paint.wrapTvGrid,
      wrapHorizontalScroller: paint.wrapHorizontalScroller,
      absorbHorizontalScroll: paint.absorbHorizontalScroll,
      isActivateKey: paint.isActivateKey,
      child: child,
    );
  }

  void _openMenu() {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final policy = ShellScope.inputPolicyOf(context);
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    _returnFocus = FocusManager.instance.primaryFocus;
    _restoreFocusOnClose = !policy.scaleOnHover;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayCtx) {
        final anchor = _anchorRectInOverlay(overlayCtx);
        final gap = DetailsTokens.listStatusMenuGapOf(tvDensity);
        final screen = MediaQuery.sizeOf(overlayCtx);
        final menuMaxW = ShellTokens.chromeScale(280, tv: tvDensity);
        final menuCap = ShellTokens.chromeScale(420, tv: tvDensity);
        double left = anchor?.left ?? 16;
        double top = (anchor?.bottom ?? 80) + gap;
        if (left + menuMaxW > screen.width - 8) {
          left = (screen.width - menuMaxW - 8).clamp(8.0, screen.width);
        }
        final spaceBelow = screen.height - top - 8;
        double menuMaxH = menuCap;
        if (spaceBelow < menuCap) {
          final spaceAbove = (anchor?.top ?? top) - gap - 8;
          if (spaceAbove > spaceBelow) {
            menuMaxH = spaceAbove.clamp(120.0, menuCap);
            top = ((anchor?.top ?? top) - gap - menuMaxH).clamp(
              8.0,
              screen.height,
            );
          } else {
            menuMaxH = spaceBelow.clamp(120.0, menuCap);
          }
        }
        return ShellScope.rehost(
          context,
          _rehostPaint(
            context,
            TvOverlayScope(
              enabled: policy.useFocusableMoodChips,
              linear: true,
              onDismiss: _close,
              debugLabel: 'stream-lang-${widget.kind}',
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  if (anchor != null)
                    Positioned(
                      left: left,
                      top: top,
                      child: Material(
                        color: Colors.transparent,
                        child: _LanguageMenuPanel(
                          kindLabel: widget.label,
                          langs: widget.langs,
                          selected: widget.selected,
                          kindActive: _kindActive,
                          tvFocus: policy.leanbackOnly,
                          tvDensity: tvDensity,
                          maxHeight: menuMaxH,
                          onClear: _clearKind,
                          onToggle: _toggleKey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    if (policy.useFocusableMoodChips) _registerTvDismiss();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null) return;
      if (!policy.scaleOnHover) return;
      focus.unfocus();
    });
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _kindActive;
    final count = _kindCount;
    final chipLabel = !active
        ? '${widget.label} ▾'
        : (count == widget.langs.length
              ? '${widget.label} ▾'
              : '${widget.label} · $count ▾');

    final tvMeta = widget.tvTabId != null && widget.useTvCompact
        ? ShellTvFocusMeta(
            tabId: widget.tvTabId!,
            zone: widget.tvItemIndex != null
                ? ShellTvZone.row
                : ShellTvZone.hero,
            rowId: widget.tvItemIndex != null ? MediaDetailsTv.heroRowId : null,
            itemIndex: widget.tvItemIndex,
          )
        : null;
    final onKey = widget.onUpEdge != null
        ? (FocusNode node, KeyEvent event) => shellTvHandleRowArrows(
            event: event,
            tvMeta: tvMeta,
            onUpEdge: widget.onUpEdge,
          )
        : null;

    return ForjaInteractive(
      onTap: _toggle,
      hoverScale: 1.03,
      pressScale: 0.97,
      tvMeta: tvMeta,
      onKeyEvent: onKey,
      suppressActive: _open,
      builder: (hover, pressed) {
        return HeroPillSegmentSurface(
          label: chipLabel,
          icon: widget.icon,
          selected: active,
          lit: hover || pressed || _open,
          pressed: pressed,
          isFirst: widget.isFirst,
          isLast: widget.isLast,
        );
      },
    );
  }
}

class _LanguageMenuPanel extends StatelessWidget {
  const _LanguageMenuPanel({
    required this.kindLabel,
    required this.langs,
    required this.selected,
    required this.kindActive,
    required this.tvFocus,
    required this.tvDensity,
    required this.maxHeight,
    required this.onClear,
    required this.onToggle,
  });

  final String kindLabel;
  final List<PluginLanguage> langs;
  final Set<String> selected;
  final bool kindActive;
  final bool tvFocus;
  final bool tvDensity;
  final double maxHeight;
  final VoidCallback onClear;
  final void Function(String key, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final minW = ShellTokens.chromeScale(168, tv: tvDensity);
    final maxW = ShellTokens.chromeScale(280, tv: tvDensity);
    final maxH = maxHeight;
    final radius = ShellTokens.chromeScale(
      ShellTokens.shellChipRadius,
      tv: tvDensity,
    );
    final padV = ShellTokens.chromeScale(4, tv: tvDensity);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cinematic.menuSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: padV),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LanguageMenuRow(
                      label: kindActive ? 'Clear $kindLabel' : 'All $kindLabel',
                      checked: null,
                      tvFocus: tvFocus,
                      tvDensity: tvDensity,
                      autoFocus: tvFocus,
                      muted: true,
                      onTap: onClear,
                    ),
                    Divider(height: ShellTokens.chromeScale(12, tv: tvDensity)),
                    for (final lang in langs)
                      _LanguageMenuRow(
                        label: lang.label,
                        // ES is one bucket — checked if either sub:es or dub:es is on.
                        checked: lang.code == 'es'
                            ? selected.contains('sub:es') ||
                                  selected.contains('dub:es')
                            : selected.contains(lang.key),
                        tvFocus: tvFocus,
                        tvDensity: tvDensity,
                        onTap: () {
                          final on = lang.code == 'es'
                              ? selected.contains('sub:es') ||
                                    selected.contains('dub:es')
                              : selected.contains(lang.key);
                          onToggle(lang.key, !on);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageMenuRow extends StatefulWidget {
  const _LanguageMenuRow({
    required this.label,
    required this.tvFocus,
    required this.tvDensity,
    required this.onTap,
    this.checked,
    this.autoFocus = false,
    this.muted = false,
  });

  final String label;

  /// `null` = plain action row (Clear / All); otherwise checkbox.
  final bool? checked;
  final bool tvFocus;
  final bool tvDensity;
  final bool autoFocus;
  final bool muted;
  final VoidCallback onTap;

  @override
  State<_LanguageMenuRow> createState() => _LanguageMenuRowState();
}

class _LanguageMenuRowState extends State<_LanguageMenuRow> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _hovered || (widget.tvFocus && _focused);

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    final checked = widget.checked;
    final tv = widget.tvDensity;
    final labelFontSize = tv ? ShellTokens.tvBodyFontSize : 12.0;
    final padH = ShellTokens.chromeScale(14, tv: tv);
    final padV = ShellTokens.chromeScale(8, tv: tv);
    final iconSize = ShellTokens.chromeScale(16, tv: tv);
    final gap = ShellTokens.chromeScale(8, tv: tv);
    final radius = ShellTokens.chromeScale(6, tv: tv);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: _active
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          if (checked != null) ...[
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: iconSize,
              color: checked
                  ? ForjaShellColors.brandGreen
                  : cinematic.textSecondary,
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: widget.muted
                    ? cinematic.textSecondary
                    : cinematic.textPrimary,
                fontSize: labelFontSize,
                fontWeight: _active || (checked == true)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.tvFocus) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      autoFocus: widget.autoFocus,
      borderRadius: radius,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      showFocusBorder: false,
      suppressInkHover: true,
      onFocusChange: (f) {
        if (_focused == f) return;
        setState(() => _focused = f);
      },
      onHoverChange: (h) {
        if (_hovered == h) return;
        setState(() => _hovered = h);
      },
      child: content,
    );
  }
}
