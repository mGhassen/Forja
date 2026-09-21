import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:google_fonts/google_fonts.dart';

/// Follower offset under a [CompositedTransformTarget] pin (gap only).
///
/// Pair with [listStatusMenuTargetAnchor] / [listStatusMenuFollowerAnchor] so
/// TV density does not leave a desktop-sized hole under a short pill.
Offset listStatusMenuGapOffset(BuildContext context) {
  final tv = ShellPaintScope.usesTvDensityOf(context);
  return Offset(0, DetailsTokens.listStatusMenuGapOf(tv));
}

const Alignment listStatusMenuTargetAnchor = Alignment.bottomLeft;
const Alignment listStatusMenuFollowerAnchor = Alignment.topLeft;

/// One My List status option — presentational only (RFC-095).
class ListStatusOption {
  const ListStatusOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
}

/// Default status menu options (Plan to Watch → Dropped).
const kListStatusOptions = <ListStatusOption>[
  ListStatusOption(
    id: 'plantowatch',
    label: 'Plan to Watch',
    icon: Icons.bookmark_add_outlined,
    selectedIcon: Icons.bookmark_rounded,
    color: Color(0xFFFBBF24), // amber
  ),
  ListStatusOption(
    id: 'watching',
    label: 'Watching',
    icon: Icons.play_circle_outline_rounded,
    selectedIcon: Icons.play_circle_rounded,
    color: ForjaShellColors.brandGreen,
  ),
  ListStatusOption(
    id: 'hold',
    label: 'On Hold',
    icon: Icons.pause_circle_outline_rounded,
    selectedIcon: Icons.pause_circle_rounded,
    color: Color(0xFFFB923C), // orange
  ),
  ListStatusOption(
    id: 'completed',
    label: 'Completed',
    icon: Icons.check_circle_outline_rounded,
    selectedIcon: Icons.check_circle_rounded,
    color: Color(0xFF38BDF8), // sky
  ),
  ListStatusOption(
    id: 'dropped',
    label: 'Dropped',
    icon: Icons.cancel_outlined,
    selectedIcon: Icons.cancel_rounded,
    color: Color(0xFFF87171), // rose
  ),
];

Color listStatusPinColor(String? status) {
  if (status == null) return Colors.white;
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.color;
  }
  return ForjaShellColors.iconActive;
}

IconData listStatusPinIcon(String? status) {
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.selectedIcon;
  }
  // Idle / not on a list — glass "+" (not a filled bookmark).
  return Icons.add_rounded;
}

String listStatusLabel(String? status, {String fallback = 'My List'}) {
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.label;
  }
  return fallback;
}

/// Always shows icon + label. Selected uses status color so the current list
/// status is obvious at open. Hover / D-pad focus gets a stronger tint.
class ListStatusMenuRow extends StatefulWidget {
  const ListStatusMenuRow({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.statusColor,
    required this.tvFocus,
    this.autoFocus = false,
    this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color statusColor;
  final bool tvFocus;
  final bool autoFocus;
  final VoidCallback? onTap;

  @override
  State<ListStatusMenuRow> createState() => _ListStatusMenuRowState();
}

class _ListStatusMenuRowState extends State<ListStatusMenuRow> {
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  bool _focused = false;

  @override
  void dispose() {
    _hoveredN.dispose();
    super.dispose();
  }

  void _setHovered(bool h) {
    if (_hoveredN.value == h) return;
    _hoveredN.value = h;
  }

  bool _active(bool hovered) => hovered || (widget.tvFocus && _focused);

  Widget _row(bool active) {
    final selected = widget.selected;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final labelFontSize = tv ? ShellTokens.tvBodyFontSize : 12.0;
    final padH = ShellTokens.chromeScale(14, tv: tv);
    final padV = ShellTokens.chromeScale(8, tv: tv);
    final iconSize = ShellTokens.chromeScale(16, tv: tv);
    final gap = ShellTokens.chromeScale(8, tv: tv);
    // Hover / D-pad wins the strong tint. Selected (idle) still uses status
    // color — desktop has no autofocus, so weight-only was invisible.
    final lit = active || selected;
    final accent = lit ? widget.statusColor : Colors.white;
    return AnimatedContainer(
      duration: ForjaMotionTheme.of(context).fillOnly.duration,
      curve: ForjaMotionTheme.of(context).fillOnly.resolvedCurve,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      color: active
          ? widget.statusColor.withValues(alpha: 0.12)
          : selected
              ? widget.statusColor.withValues(alpha: 0.08)
              : Colors.transparent,
      child: Row(
        children: [
          Icon(widget.icon, size: iconSize, color: accent),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: labelFontSize,
                fontWeight: selected || active
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _hoveredN,
      builder: (context, _) => _row(_active(_hoveredN.value)),
    );

    if (!widget.tvFocus) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    // Host FocusableControl (via ShellPaintScope) owns Select → onTap.
    // A bare Focus + nested InkWell stole autofocus and left OK dead on TV.
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onTap,
      autoFocus: widget.autoFocus,
      borderRadius: 0,
      motion: ForjaMotionPreset.fillOnly,
      showFocusFill: false,
      showFocusBorder: false,
      suppressInkHover: true,
      onFocusChange: (f) {
        if (_focused == f) return;
        setState(() => _focused = f);
      },
      onHoverChange: _setHovered,
      child: content,
    );
  }
}

/// Decorated status option column (no overlay chrome).
class ListStatusPopupPanel extends StatelessWidget {
  const ListStatusPopupPanel({
    super.key,
    required this.currentStatus,
    required this.onSelect,
    this.options = kListStatusOptions,
    this.busy = false,
    this.tvFocus = false,
    this.autoFocusSelected = false,
  });

  final String? currentStatus;
  final List<ListStatusOption> options;
  final ValueChanged<String> onSelect;
  final bool busy;
  final bool tvFocus;
  final bool autoFocusSelected;

  @override
  Widget build(BuildContext context) {
    final focusId = currentStatus ?? options.first.id;
    // FocusableControl (TV) breaks IntrinsicWidth through Transform; pin a
    // min width that fits "Plan to Watch" + icon + padding.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 168),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
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
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in options)
                  ListStatusMenuRow(
                    selected: s.id == currentStatus,
                    icon: s.id == currentStatus ? s.selectedIcon : s.icon,
                    label: s.label,
                    statusColor: s.color,
                    onTap: busy
                        ? null
                        : () => onSelect(
                            s.id == currentStatus ? '' : s.id,
                          ),
                    tvFocus: tvFocus,
                    autoFocus:
                        autoFocusSelected && tvFocus && s.id == focusId,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact bookmark pin + floating status menu — props only (RFC-095).
///
/// Pass [currentStatus] from the data adapter; [onSelect] receives status id
/// (empty string = remove). No Riverpod / Simkl / ListFollow here.
class ListStatusPin extends StatefulWidget {
  const ListStatusPin({
    super.key,
    required this.currentStatus,
    required this.onSelect,
    this.options = kListStatusOptions,
    this.busy = false,
    this.iconSize,
    this.iconColor,
    this.excludeFromTvTraversal = false,
    this.menuOffset,
    this.useFocusableChips = false,
    this.scaleOnHover = true,
  });

  final String? currentStatus;
  final List<ListStatusOption> options;
  /// Status id to set, or `''` to remove.
  final Future<void> Function(String statusId) onSelect;
  final bool busy;
  final double? iconSize;
  final Color? iconColor;
  final bool excludeFromTvTraversal;
  /// Extra follower offset after [listStatusMenuGapOffset]. Null = gap only.
  final Offset? menuOffset;
  /// Host maps [ShellInputPolicy.useFocusableMoodChips].
  final bool useFocusableChips;
  /// Host maps [ShellInputPolicy.scaleOnHover] (false on leanback TV).
  final bool scaleOnHover;

  @override
  State<ListStatusPin> createState() => _ListStatusPinState();
}

class _ListStatusPinState extends State<ListStatusPin> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _pending = false;

  bool get _busy => widget.busy || _pending;
  bool get _open => _entry != null;

  @override
  void didUpdateWidget(ListStatusPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus ||
        oldWidget.busy != widget.busy) {
      _entry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  void _close() {
    if (_entry == null) return;
    _removeOverlay();
    if (mounted) setState(() {});
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _pending = true);
    _entry?.markNeedsBuild();
    await widget.onSelect(to);
    if (!mounted) return;
    setState(() => _pending = false);
    _close();
  }

  void _openMenu() {
    if (_entry != null || _busy) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    // Desktop: drop focus on the pin so InkWell / focus chrome doesn't stick
    // while hovering menu rows.
    if (widget.scaleOnHover) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
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
              offset: listStatusMenuGapOffset(context) +
                  (widget.menuOffset ?? Offset.zero),
              child: Material(
                color: Colors.transparent,
                child: ListStatusPopupPanel(
                  currentStatus: widget.currentStatus,
                  options: widget.options,
                  busy: _busy,
                  // Desktop hybrid: hover-only rows. D-pad autofocus = leanback.
                  tvFocus: widget.useFocusableChips && !widget.scaleOnHover,
                  onSelect: _setStatus,
                ),
              ),
            ),
          ],
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    setState(() {});
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
    // Poster cards: D-pad targets the tile only — hide the pin on leanback TV.
    if (widget.excludeFromTvTraversal &&
        widget.useFocusableChips &&
        !widget.scaleOnHover) {
      return const SizedBox.shrink();
    }
    final size = widget.iconSize ?? 18.0;
    final status = widget.currentStatus;

    return CompositedTransformTarget(
      link: _link,
      child: _pinHit(
        onTap: _busy ? null : _toggle,
        child: Icon(
          listStatusPinIcon(status),
          size: size,
          color: status != null
              ? listStatusPinColor(status)
              : (widget.iconColor ?? ForjaShellColors.iconMuted),
        ),
      ),
    );
  }

  Widget _pinHit({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    // Card overlays: keep the icon flush with the rating badge (no 40×40
    // focus pad that vertically centers the pin below the score).
    if (!widget.useFocusableChips || widget.excludeFromTvTraversal) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return ShellPaintScope.focusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 20,
      motion: ForjaMotionPreset.chipLift,
      showFocusFill: false,
      showFocusBorder: false,
      suppressInkHover: true,
      child: SizedBox(
        width: ShellTokens.controlHeightTv,
        height: ShellTokens.controlHeightTv,
        child: Center(child: child),
      ),
    );
  }
}
