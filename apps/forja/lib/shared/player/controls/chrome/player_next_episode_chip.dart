import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Focus label of the chip subtree — the TV key scope treats it like chrome.
const String kPlayerUpNextFocusLabel = 'player-up-next';

/// Floating Next Episode chip.
///
/// With [countdown], a 3-2-1 ring runs, then [onCountdownComplete] fires.
/// The X inside the chip calls [onCancel]. The ring holds while
/// [countdownPaused]. D-pad → from the chip lands on the X; ← goes back.
class PlayerNextEpisodeChip extends StatefulWidget {
  const PlayerNextEpisodeChip({
    super.key,
    required this.onPressed,
    this.countdown = false,
    this.countdownPaused = false,
    this.onCountdownComplete,
    this.onCancel,
    this.focusNode,
    this.tvFocusable = false,
    this.onArrowUp,
    this.onArrowDown,
  });

  static const Duration countdownDuration = Duration(seconds: 3);

  final VoidCallback onPressed;
  final bool countdown;
  final bool countdownPaused;
  final VoidCallback? onCountdownComplete;
  final VoidCallback? onCancel;
  final FocusNode? focusNode;
  final bool tvFocusable;
  /// D-pad ↑ / ↓ from the chip. Return true when focus moved.
  final bool Function()? onArrowUp;
  final bool Function()? onArrowDown;

  @override
  State<PlayerNextEpisodeChip> createState() => _PlayerNextEpisodeChipState();
}

class _PlayerNextEpisodeChipState extends State<PlayerNextEpisodeChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: PlayerNextEpisodeChip.countdownDuration,
  )..addStatusListener(_onRingStatus);
  final FocusNode _cancelNode = FocusNode(debugLabel: 'player-up-next-cancel');
  FocusNode? _ownedMainNode;
  final ValueNotifier<bool> _mainHovered = ValueNotifier(false);
  final ValueNotifier<bool> _cancelHovered = ValueNotifier(false);
  bool _mainFocused = false;
  bool _cancelFocused = false;

  FocusNode get _mainNode =>
      widget.focusNode ??
      (_ownedMainNode ??= FocusNode(debugLabel: 'player-up-next-main'));

  bool get _showCancel => widget.countdown && widget.onCancel != null;

  @override
  void initState() {
    super.initState();
    _syncRing(restart: widget.countdown);
  }

  @override
  void didUpdateWidget(covariant PlayerNextEpisodeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdown != widget.countdown ||
        oldWidget.countdownPaused != widget.countdownPaused) {
      _syncRing(restart: widget.countdown && !oldWidget.countdown);
    }
    if (!_showCancel && _cancelNode.hasFocus && _mainNode.canRequestFocus) {
      _mainNode.requestFocus();
    }
  }

  void _syncRing({required bool restart}) {
    if (!widget.countdown) {
      _ring
        ..stop()
        ..value = 0;
      return;
    }
    if (restart) _ring.value = 0;
    if (widget.countdownPaused) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.forward();
    }
  }

  void _onRingStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !widget.countdown) return;
    widget.onCountdownComplete?.call();
  }

  void _cancel() {
    if (_cancelNode.hasFocus && _mainNode.canRequestFocus) {
      _mainNode.requestFocus();
    }
    widget.onCancel?.call();
  }

  KeyEventResult _onVertical(KeyEvent event) {
    final key = event.logicalKey;
    final move = key == LogicalKeyboardKey.arrowUp
        ? widget.onArrowUp
        : key == LogicalKeyboardKey.arrowDown
            ? widget.onArrowDown
            : null;
    if (move != null && move()) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  KeyEventResult _onMainKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_onVertical(event) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && _showCancel) {
      _cancelNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCancelKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_onVertical(event) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _mainNode.requestFocus();
      return KeyEventResult.handled;
    }
    // Last stop on the right — never wander into hidden chrome.
    if (key == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _ring.dispose();
    _cancelNode.dispose();
    _ownedMainNode?.dispose();
    _mainHovered.dispose();
    _cancelHovered.dispose();
    super.dispose();
  }

  bool _tvFocused(bool focused) => playerChromeTvFocused(
    context,
    tvFocusable: widget.tvFocusable,
    focused: focused,
  );

  Color _fill({required bool hovered, required bool focused}) {
    if (_tvFocused(focused)) {
      return ForjaShellColors.brandGreen.withValues(alpha: 0.14);
    }
    final highlight = playerChromeFocusActive(
      context,
      tvFocusable: widget.tvFocusable,
      hovered: hovered,
      focused: focused,
    );
    return highlight ? ForjaShellColors.inkHover : Colors.transparent;
  }

  Color _fg(bool focused) =>
      _tvFocused(focused) ? ForjaShellColors.brandGreen : Colors.white;

  Widget _countdownRing(Color fg) {
    final total = PlayerNextEpisodeChip.countdownDuration.inSeconds;
    return AnimatedBuilder(
      animation: _ring,
      builder: (context, _) {
        final left = (total * (1 - _ring.value)).ceil().clamp(1, total);
        return SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1 - _ring.value,
                strokeWidth: 2,
                color: fg,
                backgroundColor: ForjaShellColors.borderSubtle,
              ),
              Text(
                '$left',
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mainBody(bool hovered) {
    final fg = _fg(_mainFocused);
    return ColoredBox(
      color: _fill(hovered: hovered, focused: _mainFocused),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.countdown) ...[
              _countdownRing(fg),
              const SizedBox(width: 10),
            ],
            Text(
              'Next Episode',
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              color: fg,
              size: ShellPaintScope.iconOf(context, 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelBody(bool hovered) {
    final fg = _fg(_cancelFocused);
    return ColoredBox(
      color: _fill(hovered: hovered, focused: _cancelFocused),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(
          Icons.close_rounded,
          color: fg,
          size: ShellPaintScope.iconOf(context, 18),
        ),
      ),
    );
  }

  Widget _part({
    required ValueNotifier<bool> hovered,
    required Widget Function(bool hovered) body,
    required VoidCallback onTap,
    required FocusNode focusNode,
    required FocusOnKeyEventCallback onKey,
    required ValueChanged<bool> onFocusChange,
  }) {
    final painted = ListenableBuilder(
      listenable: hovered,
      builder: (context, _) => body(hovered.value),
    );
    if (widget.tvFocusable) {
      return FocusableControl(
        focusNode: focusNode,
        onTap: onTap,
        onKeyEvent: onKey,
        borderRadius: 0,
        scaleOnFocus: 1.0,
        onFocusChange: onFocusChange,
        child: painted,
      );
    }
    return MouseRegion(
      onEnter: (_) => hovered.value = true,
      onExit: (_) => hovered.value = false,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: painted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anyTvFocus = _tvFocused(_mainFocused) || _tvFocused(_cancelFocused);
    return Focus(
      debugLabel: kPlayerUpNextFocusLabel,
      canRequestFocus: false,
      skipTraversal: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: anyTvFocus
                ? ForjaShellColors.brandGreen
                : ForjaShellColors.borderSubtle,
            width: anyTvFocus ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _part(
                hovered: _mainHovered,
                body: _mainBody,
                onTap: widget.onPressed,
                focusNode: _mainNode,
                onKey: _onMainKey,
                onFocusChange: (f) => setState(() => _mainFocused = f),
              ),
              if (_showCancel) ...[
                Container(
                  width: 1,
                  height: 20,
                  color: ForjaShellColors.borderSubtle,
                ),
                _part(
                  hovered: _cancelHovered,
                  body: _cancelBody,
                  onTap: _cancel,
                  focusNode: _cancelNode,
                  onKey: _onCancelKey,
                  onFocusChange: (f) => setState(() => _cancelFocused = f),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
