import 'package:flutter/material.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/focus/forja_interactive.dart';
import 'package:forja/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/hero_pill_surfaces.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';

/// SUB | DUB glass group — each segment opens a multiselect language dropdown.
///
/// Selection is exclusive across kinds: picking a SUB language clears DUB
/// (and the reverse). Empty selection = all providers.
///
/// TV: floating [Overlay] + [TvOverlayScope] (same pattern as My List) — not
/// [MenuAnchor], which never joins the leanback focus graph.
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
  final LayerLink _link = LayerLink();
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

  @override
  void didUpdateWidget(covariant _KindDropdownSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_open &&
        (oldWidget.selected != widget.selected ||
            oldWidget.langs != widget.langs)) {
      _entry?.markNeedsBuild();
    }
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
    final next = <String>{};
    if (checked) {
      for (final k in widget.selected) {
        if (k.startsWith('${widget.kind}:')) next.add(k);
      }
      next.add(key);
    } else {
      for (final k in widget.selected) {
        if (k != key) next.add(k);
      }
    }
    widget.onChanged(next);
  }

  void _clearKind() {
    final next = {
      for (final k in widget.selected)
        if (!k.startsWith('${widget.kind}:')) k,
    };
    widget.onChanged(next);
  }

  void _openMenu() {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final policy = ShellScope.inputPolicyOf(context);
    _returnFocus = FocusManager.instance.primaryFocus;
    _restoreFocusOnClose = !policy.scaleOnHover;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return ShellScope.rehost(
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
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: listStatusMenuTargetAnchor,
                  followerAnchor: listStatusMenuFollowerAnchor,
                  offset: listStatusMenuGapOffset(context),
                  child: Material(
                    color: Colors.transparent,
                    child: _LanguageMenuPanel(
                      kindLabel: widget.label,
                      langs: widget.langs,
                      selected: widget.selected,
                      kindActive: _kindActive,
                      tvFocus: policy.leanbackOnly,
                      onClear: _clearKind,
                      onToggle: _toggleKey,
                    ),
                  ),
                ),
              ],
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

    return CompositedTransformTarget(
      link: _link,
      child: ForjaInteractive(
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
      ),
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
    required this.onClear,
    required this.onToggle,
  });

  final String kindLabel;
  final List<PluginLanguage> langs;
  final Set<String> selected;
  final bool kindActive;
  final bool tvFocus;
  final VoidCallback onClear;
  final void Function(String key, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    final cinematic = ForjaShellColors.cinematic;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cinematic.menuSurface,
          borderRadius: BorderRadius.circular(ShellTokens.shellChipRadius),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LanguageMenuRow(
                    label: kindActive ? 'Clear $kindLabel' : 'All $kindLabel',
                    checked: null,
                    tvFocus: tvFocus,
                    autoFocus: tvFocus,
                    muted: true,
                    onTap: onClear,
                  ),
                  const Divider(height: 12),
                  for (final lang in langs)
                    _LanguageMenuRow(
                      label: lang.label,
                      checked: selected.contains(lang.key),
                      tvFocus: tvFocus,
                      onTap: () =>
                          onToggle(lang.key, !selected.contains(lang.key)),
                    ),
                ],
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
    required this.onTap,
    this.checked,
    this.autoFocus = false,
    this.muted = false,
  });

  final String label;

  /// `null` = plain action row (Clear / All); otherwise checkbox.
  final bool? checked;
  final bool tvFocus;
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
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _active
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (checked != null) ...[
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: checked
                  ? ForjaShellColors.brandGreen
                  : cinematic.textSecondary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.muted
                    ? cinematic.textSecondary
                    : cinematic.textPrimary,
                fontSize: checked == null ? 13 : 14,
                fontWeight: _active ? FontWeight.w600 : FontWeight.w500,
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
      borderRadius: 6,
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
