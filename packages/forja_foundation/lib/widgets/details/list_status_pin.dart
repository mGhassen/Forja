import 'package:flutter/material.dart';
import 'package:forja_foundation/components/focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

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
  if (status == null) return ForjaShellColors.iconMuted;
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.color;
  }
  return ForjaShellColors.iconActive;
}

IconData listStatusPinIcon(String? status) {
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.selectedIcon;
  }
  return Icons.bookmark_rounded;
}

String listStatusLabel(String? status, {String fallback = 'My List'}) {
  for (final s in kListStatusOptions) {
    if (s.id == status) return s.label;
  }
  return fallback;
}

/// Always shows icon + label. Hover = background; selected = status color.
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
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || (widget.tvFocus && _focused);

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final accent = active
        ? widget.statusColor
        : (widget.selected ? widget.statusColor : Colors.white);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: active
          ? widget.statusColor.withValues(alpha: 0.12)
          : Colors.transparent,
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: widget.selected || active
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: accent,
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
          child: row,
        ),
      );
    }

    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableTap(
          onTap: widget.onTap,
          borderRadius: BorderRadius.zero,
          child: row,
        ),
      ),
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
    this.menuOffset = const Offset(0, 28),
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
  final Offset menuOffset;
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
              offset: widget.menuOffset,
              child: Material(
                color: Colors.transparent,
                child: ListStatusPopupPanel(
                  currentStatus: widget.currentStatus,
                  options: widget.options,
                  busy: _busy,
                  tvFocus: widget.useFocusableChips,
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
    return Transform.scale(
      scale: ShellTokens.focusActiveScale,
      child: FocusableTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
  }
}
