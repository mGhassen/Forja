import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/details/list_status_pin.dart';

/// Glass hero status control — props only (RFC-106 Zone A).
///
/// Host wires list status + [HeroPillIconGroup] / TV via [triggerBuilder].
class ListStatusHero extends StatefulWidget {
  const ListStatusHero({
    super.key,
    required this.currentStatus,
    required this.onSetStatus,
    required this.triggerBuilder,
    this.enabled = true,
    this.onMenuOpenChanged,
    this.useFocusableChips = false,
    this.menuOffset = const Offset(0, 46),
  });

  final String? currentStatus;
  final Future<bool> Function(String status) onSetStatus;
  final bool enabled;
  final ValueChanged<bool>? onMenuOpenChanged;
  final bool useFocusableChips;
  final Offset menuOffset;

  /// Builds the hero trigger (host wraps Interactive / TV pills).
  final Widget Function(
    BuildContext context, {
    required String? status,
    required VoidCallback? onTap,
    required bool menuOpen,
  }) triggerBuilder;

  static int extraFocusSlots(bool menuOpen) => 0;

  @override
  State<ListStatusHero> createState() => _ListStatusHeroState();
}

class _ListStatusHeroState extends State<ListStatusHero> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _busy = false;

  bool get _open => _entry != null;

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
    widget.onMenuOpenChanged?.call(false);
    if (mounted) setState(() {});
  }

  void _openMenu() {
    if (_entry != null || _busy || !widget.enabled) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    // Drop trigger focus so desktop hover chrome doesn't stick on the pin
    // while picking a menu row (TV autofocus then lands on the panel).
    FocusManager.instance.primaryFocus?.unfocus();
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
                  busy: _busy,
                  tvFocus: widget.useFocusableChips,
                  autoFocusSelected: widget.useFocusableChips,
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
    widget.onMenuOpenChanged?.call(true);
    setState(() {});
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _busy = true);
    _entry?.markNeedsBuild();
    await widget.onSetStatus(to);
    if (!mounted) return;
    setState(() => _busy = false);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: widget.triggerBuilder(
        context,
        status: widget.currentStatus,
        onTap: (!widget.enabled || _busy) ? null : _toggle,
        menuOpen: _open,
      ),
    );
  }
}

/// Alias for poster / button adapters that share the same overlay paint.
typedef ListStatusControl = ListStatusHero;
